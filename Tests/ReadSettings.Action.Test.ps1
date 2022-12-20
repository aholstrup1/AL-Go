﻿Get-Module TestActionsHelper | Remove-Module -Force
Import-Module (Join-Path $PSScriptRoot 'TestActionsHelper.psm1')

Describe "ReadSettings Action Tests" {
    BeforeAll {
        $actionName = "ReadSettings"
        $scriptRoot = Join-Path $PSScriptRoot "..\Actions\$actionName" -Resolve
        $scriptName = "$actionName.ps1"
        $scriptPath = Join-Path $scriptRoot $scriptName
        $actionScript = GetActionScript -scriptRoot $scriptRoot -scriptName $scriptName
    }

    It 'Compile Action' {
        Invoke-Expression $actionScript
    }

    It 'Test action.yaml matches script' {
        $permissions = [ordered]@{
        }
        $outputs = [ordered]@{
            "SettingsJson" = "Settings in compressed Json format"
            "GitHubRunnerJson" = "GitHubRunner in compressed Json format"
            "ProjectsJson" = "Projects in compressed Json format"
            "ProjectCount" = "Number of projects in array"
            "EnvironmentsJson" = "Environments in compressed Json format"
            "EnvironmentCount" = "Number of environments in array"
            "ProjectDependenciesJson" = "Project Dependencies Json"
            "BuildOrderJson" = "Build order Json"
            "BuildOrderDepth" = "Depth in build order"
            "BuildModes" = "Array of build modes"
        }
        YamlTest -scriptRoot $scriptRoot -actionName $actionName -actionScript $actionScript -permissions $permissions -outputs $outputs
    }

    # Call action

}
