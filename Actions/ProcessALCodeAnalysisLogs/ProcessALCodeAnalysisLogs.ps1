Param(
    [Parameter(HelpMessage = "Folder containing error logs and SARIF output", Mandatory = $false)]
    [string] $errorLogsFolder = "ErrorLogs"
)
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "ProcessALCodeAnalysisLogs.psm1" -Resolve) -Force -DisableNameChecking

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

    De-duplication and accumulation use hash-based lookups (a HashSet of composite result keys, a HashSet
    of rule ids) and a List for results/rules, so processing scales linearly with the number of diagnostics.
    A naive implementation that scans all previously-added results for every issue, and appends to a plain
    array, scales quadratically and can time out on large multi-project/multi-country builds.
    .PARAMETER errorLogContent
    The contents of the error log file to process.
    .PARAMETER Results
    The accumulating list of SARIF result objects (mutated in place).
    .PARAMETER Rules
    The accumulating list of SARIF rule objects (mutated in place).
    .PARAMETER ResultKeys
    A HashSet of composite result keys used to de-duplicate results in O(1).
    .PARAMETER RuleIds
    A HashSet of rule ids already added to Rules.
    .PARAMETER FileCache
    A hashtable memoizing absolute-uri -> relative-path resolution across issues.
#>
function GenerateSARIFJson {
    param(
        [Parameter(HelpMessage = "The contents of the error log file to process.", Mandatory = $true)]
        [PSCustomObject] $errorLogContent,
        [Parameter()]
        [System.Collections.Generic.List[object]] $Results,
        [Parameter()]
        [System.Collections.Generic.List[object]] $Rules,
        [Parameter()]
        [System.Collections.Generic.HashSet[string]] $ResultKeys,
        [Parameter()]
        [System.Collections.Generic.HashSet[string]] $RuleIds,
        [Parameter()]
        [hashtable] $FileCache
    )

    # Unit Separator: an unambiguous delimiter for the composite de-duplication key.
    $keySeparator = [char]0x1F

    foreach ($issue in $errorLogContent.issues) {
        # Skip issues without locations as GitHub expects at least one location
        if (($issue.PSObject.Properties.Name -notcontains "locations" ) -or ($issue.locations.Count -eq 0) -or $issue.PSObject.Properties.Name -notcontains "ruleId") {
            continue
        }

        $newResult = $null
        $absoluteUri = $issue.locations[0].analysisTarget[0].uri

        # Resolve (and memoize) the workspace-relative path for this issue's file. Many issues share the
        # same file, so caching avoids repeated filesystem work per issue.
        if ($FileCache.ContainsKey($absoluteUri)) {
            $relativePath = $FileCache[$absoluteUri]
        }
        else {
            $relativePath = Get-FileFromAbsolutePath -AbsolutePath $absoluteUri
            $FileCache[$absoluteUri] = $relativePath
        }

        $message = Get-IssueMessage -issue $issue
        $issueSeverity = Get-IssueSeverity -issue $issue

        # Skip issues if we cannot find a message
        if ($null -eq $message) {
            OutputDebug -message "Could not extract message from issue: $($issue | ConvertTo-Json -Depth 10 -Compress)"
            continue
        }

        # Skip issues if we cannot find the file in the workspace
        if ($null -eq $relativePath) {
            OutputDebug -message "Could not find file for issue: $($issue | ConvertTo-Json -Depth 10 -Compress)"
            continue
        }

        $level = ($issueSeverity).ToLower()
        $region = $issue.locations[0].analysisTarget[0].region
        $regionJson = $region | ConvertTo-Json -Depth 5 -Compress

        # Check if result already exists using an O(1) composite-key lookup. The key mirrors the fields the
        # original implementation compared: ruleId, message text, level, relative uri and region.
        $resultKey = "$($issue.ruleId)$keySeparator$message$keySeparator$level$keySeparator$relativePath$keySeparator$regionJson"
        if (-not $ResultKeys.Add($resultKey)) {
            # Add returns $false when the key already existed -> duplicate, skip.
            continue
        }

        # Add rule to the sarif object if not already added
        if ($RuleIds.Add($issue.ruleId)) {
            $fullMessage = $message
            if ($issue.PSObject.Properties.Name -contains "fullMessage") {
                $fullMessage = $issue.fullMessage
            }
            $fullMessage = "$($issue.ruleId): $fullMessage"

            # Use only full message for rules if possible. The messages from the AL compiler look like this:
            # "shortMessage": "Variable 'InvalidDate' is unused in 'CustomerListExtTwo'.",
            # "fullMessage": "Do not declare variables that are unused."
            # So if shortMessage is used, the rule description will not be generic, but specific to a certain alert result.
            $Rules.Add(@{
                id = $issue.ruleId
                shortDescription = @{ text = $fullMessage }
                fullDescription = @{ text = $fullMessage }
                helpUri = $issue.properties.helpLink
                properties = @{
                    category = $issue.properties.category
                    severity = $issueSeverity
                }
            })
        }

        # Create new result
        $newResult = @{
            ruleId = $issue.ruleId
            message = @{ text = $message }
            locations = @(@{
                physicalLocation = @{
                    artifactLocation = @{ uri = (ConvertTo-SarifArtifactUri -RelativePath $relativePath) }
                    region = $region
                }
            })
            level = $level
        }

        # Add the new result if it was created
        if ($null -ne $newResult) {
            $Results.Add($newResult)
        }
    }
}

try {
    if ((Test-Path $errorLogsFolderPath -PathType Container) -and ($null -ne $sarif)){
        $errorLogFiles = @(Get-ChildItem -Path $errorLogsFolderPath -Filter "*.errorLog.json" -File -Recurse)
        Write-Host "Found $($errorLogFiles.Count) error log files in $errorLogsFolderPath"

        # Shared accumulators / lookups used across all error log files. Seed them from any content already
        # present in the base SARIF object so behavior is preserved if the base is ever non-empty.
        $results = [System.Collections.Generic.List[object]]::new()
        $rules = [System.Collections.Generic.List[object]]::new()
        $resultKeys = [System.Collections.Generic.HashSet[string]]::new()
        $ruleIds = [System.Collections.Generic.HashSet[string]]::new()
        $fileCache = @{}
        if ($sarif.runs[0].tool.driver.rules) {
            foreach ($existingRule in $sarif.runs[0].tool.driver.rules) {
                $rules.Add($existingRule) | Out-Null
                [void]$ruleIds.Add($existingRule.id)
            }
        }

        $errorLogFiles | ForEach-Object {
            OutputDebug -message "Found error log file: $($_.FullName)"
            $fileName = $_.Name
            try {
                $errorLogContent = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                GenerateSARIFJson -errorLogContent $errorLogContent -Results $results -Rules $rules -ResultKeys $resultKeys -RuleIds $ruleIds -FileCache $fileCache
            }
            catch {
                OutputWarning "Failed to process $fileName. AL code alerts might not appear in GitHub. You can manually inspect your artifacts for AL code alerts"
                OutputDebug -message "Error: $_"
            }
        }

        $sarif.runs[0].results = $results.ToArray()
        $sarif.runs[0].tool.driver.rules = $rules.ToArray()

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
