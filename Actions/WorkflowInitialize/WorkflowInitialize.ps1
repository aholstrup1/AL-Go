function LogAlGoVersion() {
    $ap = "$ENV:GITHUB_ACTION_PATH".Split('\')
    $branch = $ap[$ap.Count-2]
    $owner = $ap[$ap.Count-4]

    if ($owner -ne "microsoft") {
        $verstr = "d"
    }
    elseif ($branch -eq "preview") {
        $verstr = "p"
    }
    else {
        $verstr = $branch
    }
    Write-Big -str "a$verstr"
}

function LogWorkflowStart() {
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}

    $alGoSettingsPath = "$ENV:GITHUB_WORKSPACE/.github/AL-Go-Settings.json"
    if (Test-Path -Path $alGoSettingsPath) {
        $repoSettings = Get-Content -Path $alGoSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Log the repository type
        if ($repoSettings.PSObject.Properties.Name -contains 'type') {
            Add-TelemetryData -Hashtable $AdditionalData -Key 'RepoType' -Value $repoSettings.type
        }

        # Log the template URL
        if ($repoSettings.PSObject.Properties.Name -contains 'templateUrl') {
            Add-TelemetryData -Hashtable $AdditionalData -Key 'TemplateUrl' -Value $repoSettings.templateUrl
        }

        # Log the Al-Go version
        $alGoVersion = "main"
        Add-TelemetryData -Hashtable $AdditionalData -Key 'AlGoVersion' -Value $alGoVersion
    }

    Trace-Information -Message "AL-Go workflow started: $($ENV:GITHUB_WORKFLOW.Trim())" -AdditionalData $AdditionalData
}

import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)

try {

    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-TestRepoHelper.ps1" -Resolve)

    # Log the start of the workflow to telemetry
    LogWorkflowStart

    # Log the version of AL-Go that is being used in the workflow
    LogAlGoVersion

    # Test the AL-Go repository is set up correctly
    TestALGoRepository

    # Test the prerequisites for the test runner
    TestRunnerPrerequisites

    # Create a json object that contains an entry for the workflowstarttime
    $scopeJson = @{
        "workflowStartTime" = [DateTime]::UtcNow
    } | ConvertTo-Json -Compress

    Add-Content -Encoding UTF8 -Path $env:GITHUB_OUTPUT -Value "telemetryScopeJson=$scopeJson"
}
catch {
    Trace-Exception -ErrorRecord $_
    throw
}
