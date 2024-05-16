﻿Param(
    [Parameter(HelpMessage = "Telemetry scope generated during the workflow initialization", Mandatory = $false)]
    [string] $telemetryScopeJson = '',
    [Parameter(HelpMessage = "The current job context", Mandatory = $false)]
    [string] $currentJobContext = '',
    [Parameter(HelpMessage = "The ref of the action", Mandatory = $false)]
    [string] $actionsRef
)

function GetWorkflowConclusion($JobContext) {
    # Check the conclusion for the current job
    if ($JobContext -ne '') {
        $jobContext = $JobContext | ConvertFrom-Json
        if ($jobContext.status -eq 'failure') {
            return "Failure"
        }
    }

    # Check the conclusion for the past jobs in the workflow
    $workflowJobs = gh api /repos/$ENV:GITHUB_REPOSITORY/actions/runs/$ENV:GITHUB_RUN_ID/jobs --paginate -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" | ConvertFrom-Json
    if ($null -ne $workflowJobs) {
        $failedJobs = $workflowJobs.jobs | Where-Object { $_.conclusion -eq "failure" }
        if ($null -ne $failedJobs) {
            return "Failure"
        }
    }

    return "Success"
}

function GetAlGoVersion($ActionRef) {
    if ($ENV:GITHUB_REPOSITORY -eq "microsoft/AL-Go") {
        return "Preview"
    } elseif($ENV:GITHUB_REPOSITORY -notlike "microsoft/*") {
        return "Developer/Private"
    } else {
        return $ActionRef
    }
}

function LogWorkflowEnd($TelemetryScopeJson, $JobContext, $AlGoVersion) {
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    $telemetryScope = $null
    if ($TelemetryScopeJson -ne '') {
        $telemetryScope = $TelemetryScopeJson | ConvertFrom-Json
    }

    # Get the workflow conclusion
    $workflowConclusion = GetWorkflowConclusion -JobContext $JobContext
    Add-TelemetryProperty -Hashtable $AdditionalData -Key 'WorkflowConclusion' -Value $workflowConclusion

    # Calculate the workflow duration using the github api
    if ($telemetryScope -and ($null -ne $telemetryScope.workflowStartTime)) {
        Write-Host "Calculating workflow duration..."
        $workflowTiming= [DateTime]::UtcNow.Subtract([DateTime]::Parse($telemetryScope.workflowStartTime)).TotalSeconds
        Add-TelemetryProperty -Hashtable $AdditionalData -Key 'WorkflowDuration' -Value $workflowTiming
    }

    $alGoSettingsPath = "$ENV:GITHUB_WORKSPACE/.github/AL-Go-Settings.json"
    if (Test-Path -Path $alGoSettingsPath) {
        $repoSettings = Get-Content -Path $alGoSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Log the repository type
        if ($repoSettings.PSObject.Properties.Name -contains 'type') {
            Add-TelemetryProperty -Hashtable $AdditionalData -Key 'RepoType' -Value $repoSettings.type
        }
    }

    if ($AlGoVersion -ne '') {
        Add-TelemetryProperty -Hashtable $AdditionalData -Key 'ALGoVersion' -Value $AlGoVersion
    }

    Trace-Information -Message "AL-Go workflow ran: $($ENV:GITHUB_WORKFLOW.Trim())" -AdditionalData $AdditionalData
}

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
LogWorkflowEnd -TelemetryScopeJson $telemetryScopeJson -JobContext $currentJobContext -AlGoVersion (GetAlGoVersion -ActionRef $actionsRef)