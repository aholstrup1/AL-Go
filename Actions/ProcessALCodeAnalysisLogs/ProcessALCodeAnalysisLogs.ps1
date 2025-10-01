Param(
    [Parameter(HelpMessage = "Folder containing error logs and SARIF output", Mandatory = $false)]
    [string] $errorLogsFolder = "ErrorLogs"
)

$errorLogsFolderPath = Join-Path $ENV:GITHUB_WORKSPACE $errorLogsFolder

$sarifPath = Join-Path -Path $PSScriptRoot -ChildPath ".\baseSarif.json" -Resolve
$sarif = $null
if (Test-Path $sarifPath) {
    $sarif = Get-Content -Path $sarifPath -Raw | ConvertFrom-Json
} else {
    OutputError -message "Base SARIF file not found at $sarifPath"
}

<#
    .SYNOPSIS
    Generates SARIF JSON.
    .DESCRIPTION
    Generates SARIF JSON from a error log file and adds both rules and results to the base sarif object.
    Rules and results are de-duplicated.
    .PARAMETER errorLogContent
    The contents of the error log file to process.
#>
function GenerateSARIFJson {
    param(
        [Parameter(HelpMessage = "The contents of the error log file to process.", Mandatory = $true)]
        [PSCustomObject] $errorLogContent
    )

    foreach ($issue in $errorLogContent.issues) {
        if (($issue.PSObject.Properties.Name -notcontains "locations" ) -or ($issue.locations.Count -eq 0)) {
            OutputDebug -message "Skipping issue without analysisTarget: $($issue | ConvertTo-Json -Depth 10 -Compress)"
            continue
        }

        # Add rule if not already added
        if (-not ($sarif.runs[0].tool.driver.rules | Where-Object { $_.id -eq $issue.ruleId })) {
            $sarif.runs[0].tool.driver.rules += @{
                id = $issue.ruleId
                shortDescription = @{ text = $issue.fullMessage }
                fullDescription = @{ text = $issue.fullMessage }
                helpUri = $issue.properties.helpLink
                properties = @{
                    category = $issue.properties.category
                    severity = $issue.properties.severity
                }
            }
        }

        # if issue has a shortmessage, use it, otherwise use fullMessage
        if ($issue.PSObject.Properties.Name -notcontains "shortMessage") {
            $message = $issue.fullMessage
        } else {
            $message = $issue.shortMessage
        }

        # Convert absolute path to relative path from repository root and normalize to POSIX style
        $absolutePath = $issue.locations[0].analysisTarget[0].uri
        $workspacePath = $ENV:GITHUB_WORKSPACE

        # Normalize path to POSIX style: remove drive letter and convert backslashes to forward slashes
        $normalizedAbsolutePath = $absolutePath -replace '^[A-Za-z]:', '' -replace '\\', '/'
        $normalizedWorkspacePath = $workspacePath -replace '^[A-Za-z]:', '' -replace '\\', '/'

        $relativePath = $normalizedAbsolutePath.Replace($normalizedWorkspacePath, '').TrimStart('/')

        # Add result
        if (-not ($sarif.runs[0].results | Where-Object {
            $_.ruleId -eq $issue.ruleId -and
            $_.message.text -eq $message -and
            $_.locations[0].physicalLocation.artifactLocation.uri -eq $relativePath -and
            ($_.locations[0].physicalLocation.region | ConvertTo-Json) -eq ($issue.locations[0].analysisTarget[0].region | ConvertTo-Json) -and
            $_.level -eq ($issue.properties.severity).ToLower()
        })) {
            $sarif.runs[0].results += @{
                ruleId = $issue.ruleId
                message = @{ text = $message }
                locations = @(@{
                    physicalLocation = @{
                        artifactLocation = @{ uri = $relativePath }
                        region = $issue.locations[0].analysisTarget[0].region
                    }
                })
                level = ($issue.properties.severity).ToLower()
            }
        }
    }
}

try {
    if ((Test-Path $errorLogsFolderPath -PathType Container) -and ($null -ne $sarif)){
        $errorLogFiles = @(Get-ChildItem -Path $errorLogsFolderPath -Filter "*.errorLog.json" -File -Recurse)
        Write-Host "Found $($errorLogFiles.Count) error log files in $errorLogsFolderPath"
        $errorLogFiles | ForEach-Object {
            OutputDebug -message "Found error log file: $($_.FullName)"
            $fileName = $_.Name
            try {
                $errorLogContent = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                GenerateSARIFJson -errorLogContent $errorLogContent
            }
            catch {
                throw $_
                #OutputWarning "Failed to process $fileName. AL code alerts might not appear in GitHub. You can manually inspect your artifacts for AL code alerts"
                #OutputDebug -message "Error: $_"
            }
        }

        $sarifJson = $sarif | ConvertTo-Json -Depth 10 -Compress
        OutputDebug -message $sarifJson
        Set-Content -Path "$errorLogsFolderPath/output.sarif.json" -Value $sarifJson
    }
    else {
        OutputWarning -message "ErrorLogs $errorLogsFolder folder not found. You can manually inspect your artifacts for AL code alerts."
    }
}
catch {
    throw $_
    #OutputWarning -message "Unexpected error processing AL code analysis results. You can manually inspect your artifacts for AL code alerts."
    #OutputDebug -message "Error: $_"
    #Trace-Exception -ActionName "ProcessALCodeAnalysisLogs" -ErrorRecord $_
}
