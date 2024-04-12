Param(
    [Parameter(HelpMessage = "The event id of the initiating workflow", Mandatory = $true)]
    [string] $eventId
)

$telemetryScope = $null

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

import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper2.psm1" -Resolve)

try {
    Trace-WorkflowStart

    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-TestRepoHelper.ps1" -Resolve)
    

    # Log the version of AL-Go that is being used in the workflow 
    LogAlGoVersion

    # Test the AL-Go repository is set up correctly
    TestALGoRepository

    # Test the prerequisites for the test runner
    TestRunnerPrerequisites


    $scopeJson = '7b7d'
    $correlationId = [guid]::Empty.ToString()

    Add-Content -Encoding UTF8 -Path $env:GITHUB_OUTPUT -Value "telemetryScopeJson=$scopeJson"
    Write-Host "telemetryScopeJson=$scopeJson"

    Add-Content -Encoding UTF8 -Path $env:GITHUB_OUTPUT -Value "correlationId=$correlationId"
    Write-Host "correlationId=$correlationId"
}
catch {
    Trace-Exception -ErrorRecord $_
    throw
}
