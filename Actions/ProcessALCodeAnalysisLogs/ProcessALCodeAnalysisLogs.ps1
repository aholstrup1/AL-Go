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

function Get-FileFromAbsolutePath {
    param(
        [Parameter(HelpMessage = "The absolute path of the file to find.", Mandatory = $true)]
        [string] $AbsolutePath,
        [Parameter(HelpMessage = "The workspace path to search in.", Mandatory = $false)]
        [string] $WorkspacePath = $ENV:GITHUB_WORKSPACE
    )

    # Convert absolute path to POSIX style and remove the drive letter if present
    $normalizedPath = ($AbsolutePath -replace '\\', '/') -replace '^[A-Za-z]:', ''
    $fileName = [System.IO.Path]::GetFileName($normalizedPath)

    # Search the workspace path for a file with that name
    $matchingFiles = @(Get-ChildItem -Path $WorkspacePath -Filter $fileName -File -Recurse -ErrorAction SilentlyContinue)
    if ($null -eq $matchingFiles) {
        return $null
    } elseif($matchingFiles.Count -eq 1) {
        $foundFile = $matchingFiles[0]
    } else {
        # Pick the file with the longest matching suffix to the absolute path
        $foundFile = $matchingFiles | Sort-Object { ($normalizedPath -split [regex]::Escape($_.FullName)).Length } -Descending | Select-Object -First 1
    }
    $relativePath = [System.IO.Path]::GetRelativePath($workspacePath, $foundFile.FullName) -replace '\\', '/'
    return $relativePath
}

function Get-IssueMessage {
    param(
        [Parameter(HelpMessage = "The issue object to extract the message from.", Mandatory = $true)]
        [PSCustomObject] $issue
    )

    if ($issue.PSObject.Properties.Name -contains "shortMessage") {
        return $issue.shortMessage
    } elseif ($issue.PSObject.Properties.Name -notcontains "fullMessage") {
        return $issue.fullMessage
    } else {
        return $null
    }
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
        $newResult = $null
        $relativePath = $null
        $message = Get-IssueMessage

        # If we could not extract a message, skip this issue
        if ($null -eq $message) {
            OutputDebug -message "Could not extract message from issue: $($issue | ConvertTo-Json -Depth 10 -Compress)"
            continue
        }

        # Check if result already exists in the sarif object
        $existingResults = $sarif.runs[0].results | Where-Object {
            $_.ruleId -eq $issue.ruleId -and
            $_.message.text -eq $message -and
            $_.level -eq ($issue.properties.severity).ToLower()
        }

        # Additionally, filter on location if it exists
        if (($issue.PSObject.Properties.Name -contains "locations" ) -and ($issue.locations.Count -gt 0)) {
            $relativePath = Get-FileFromAbsolutePath -AbsolutePath $issue.locations[0].analysisTarget[0].uri
            $existingResults = $existingResults | Where-Object {
                ($_.locations[0].physicalLocation.artifactLocation.uri -eq $relativePath) -and
                ($_.locations[0].physicalLocation.region | ConvertTo-Json) -eq ($issue.locations[0].analysisTarget[0].region | ConvertTo-Json)
            }
        }

        # Add result if it does not already exist
        if (-not $existingResults)
        {
            # Add rule to the sarif object if not already added
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

            # Create new result
            $newResult = @{
                ruleId = $issue.ruleId
                message = @{ text = $message }
                level = ($issue.properties.severity).ToLower()
            }

            if ($null -ne $relativePath) {
                $newResult["locations"] = @(@{
                    physicalLocation = @{
                        artifactLocation = @{ uri = $relativePath }
                        region = $issue.locations[0].analysisTarget[0].region
                    }
                })
            }
        }

        # Add the new result if it was created
        if ($null -ne $newResult) {
            $sarif.runs[0].results += $newResult
        }
    }
}

try {
    if ((Test-Path $errorLogsFolderPath -PathType Container) -and ($null -ne $sarif)){
        $errorLogFiles = @(Get-ChildItem -Path $errorLogsFolderPath -Filter "*.errorLog.json" -File -Recurse)
        Write-Host "Found $($errorLogFiles.Count) error log files in $errorLogsFolderPath"
        $errorLogFiles | ForEach-Object {
            OutputDebug -message "Found error log file: $($_.FullName)"
            try {
                $errorLogContent = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                GenerateSARIFJson -errorLogContent $errorLogContent
            }
            catch {
                OutputWarning "Failed to process $fileName. AL code alerts might not appear in GitHub. You can manually inspect your artifacts for AL code alerts"
                OutputDebug -message "Error: $_"
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
    OutputWarning -message "Unexpected error processing AL code analysis results. You can manually inspect your artifacts for AL code alerts."
    OutputDebug -message "Error: $_"
    Trace-Exception -ActionName "ProcessALCodeAnalysisLogs" -ErrorRecord $_
}
