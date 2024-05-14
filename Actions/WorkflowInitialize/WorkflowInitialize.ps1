﻿function LogAlGoVersion() {
    Import-Module (Join-Path $PSScriptRoot '..\Github-Helper.psm1' -Resolve)

    $branch = Get-ActionBranch
    if ((Get-ActionOwner) -ne "microsoft") {
        $verstr = "d"
    }
    elseif ($branch -eq "preview") {
        $verstr = "p"
    }
    elseif ($branch -match "^[0-9a-f]{40}$") {
        # If the branch is a commit hash, use the first 7 characters of the hash
        $verstr = $branch.Substring(0, 7)
    }
    else {
        $verstr = $branch
    }
    Write-Big -str "a$verstr"
}

Write-Host "Action path: $($ENV:GITHUB_ACTION_PATH)"

. (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
. (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-TestRepoHelper.ps1" -Resolve)

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
