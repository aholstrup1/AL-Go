Param(
    [Parameter(HelpMessage = "Telemetry scope generated during the workflow initialization", Mandatory = $false)]
    [string] $telemetryScopeJson = ''
)

function LogWorkflowEnd($TelemetryScopeJson) {
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    $telemetryScope = $null
    if ($TelemetryScopeJson -ne '') {
        $telemetryScope = $TelemetryScopeJson | ConvertFrom-Json
    }

    # Calculate the workflow conclusion using the github api
    $workflowJobs = gh api /repos/$ENV:GITHUB_REPOSITORY/actions/runs/$ENV:GITHUB_RUN_ID/jobs -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" | ConvertFrom-Json
    if ($null -ne $workflowJobs) {
        $failedJobs = $workflowJobs.jobs | Where-Object { $_.conclusion -eq "failure" }
        if ($null -eq $failedJobs) {
            $workflowConclusion = "Success"
        } else {
            $workflowConclusion = "Failure"
        }
        Add-TelemetryData -Hashtable $AdditionalData -Key 'WorkflowConclusion' -Value $workflowConclusion
    }

    # Calculate the workflow duration using the github api
    if ($telemetryScope -and ($null -ne $telemetryScope.workflowStartTime)) {
        Write-Host "Calculating workflow duration..."
        $workflowTiming= [DateTime]::UtcNow.Subtract([DateTime]::Parse($telemetryScope.workflowStartTime)).TotalSeconds
        Add-TelemetryData -Hashtable $AdditionalData -Key 'WorkflowDuration' -Value $workflowTiming
    }

    Trace-Information -Message "AL-Go workflow ran: $($ENV:GITHUB_WORKFLOW.Trim())" -AdditionalData $AdditionalData
}

import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
LogWorkflowEnd -TelemetryScopeJson $telemetryScopeJson