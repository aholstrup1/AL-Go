Param(
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d'
)

$telemetryScope = $null

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    DownloadAndImportBcContainerHelper

    import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    $telemetryScope = CreateScope -eventId 'DO0082' -parentTelemetryScopeJson $parentTelemetryScopeJson

    . (Join-Path -Path $PSScriptRoot 'TestResultAnalyzer.ps1')

    $testResultFiles = Get-ChildItem -Path $ENV:GITHUB_WORKSPACE -Filter "TestResults.xml" -File -Recurse
    # Get PR Number from github context
    $prNumber = $ENV:GITHUB_REF -replace 'refs/pull/(\d+)/merge', '$1'
    $title = "# Test Results Summary"
    $summary = $title + "`n"

    foreach ($testResultFile in $testResultFiles) {
        $testResults = [xml](Get-Content $testResultFile.FullName)
        $testResultSummary = GetTestResultSummary -testResults $testResults -includeFailures 50

        try {
            Write-Host "Directory Name: $($testResultFile.Directory.Name)"
            $artifactNamematches = [regex]::Matches($testResultFile.Directory.Name, 'build_projects_(?<project>.+)-(?<branch>.+)-(?<testType>.+)-PR(?<prNumber>\d+)-(?<date>\d+)')
            if ($artifactNamematches.Success) {
                $buildMode = $artifactNamematches.Groups['testType'].Value -replace 'TestResults', ''
                if ($testType -eq '') {
                    $buildMode = 'Default'
                }
            }
        } catch {
            $buildMode = 'Unkown'
            Write-Host $_
        }

        $summary += "### Project / $buildMode (TODO) `n"
        $summary += "$($testResultSummary.Replace("\n","`n"))`n`n"
    }

    $lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $linkToWorkflowRun = gh api --method GET -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$ENV:GITHUB_REPOSITORY/actions/runs/$ENV:GITHUB_RUN_ID | ConvertFrom-Json | Select-Object -ExpandProperty html_url

    $summary += "Workflow run: $linkToWorkflowRun`n"
    $summary += "Last updated: $lastUpdated`n"
    Add-Content -path $ENV:GITHUB_STEP_SUMMARY -value $summary
    gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$ENV:GITHUB_REPOSITORY/issues/$prNumber/comments -f body=$summary

    <#$bcptTestResultsFile = Join-Path $ENV:GITHUB_WORKSPACE "$project\BCPTTestResults.json"
    if (Test-Path $bcptTestResultsFile) {
        # TODO Display BCPT Test Results
    }
    else {
        #Add-Content -path $ENV:GITHUB_STEP_SUMMARY -value "*BCPT test results not found*`n`n"
    }#>

    TrackTrace -telemetryScope $telemetryScope
}
catch {
    if (Get-Module BcContainerHelper) {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
    }

    throw
}
