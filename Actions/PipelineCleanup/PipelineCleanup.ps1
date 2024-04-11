﻿Param(
    [Parameter(HelpMessage = "Project folder", Mandatory = $false)]
    [string] $project = ".",
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d'
)

Import-Module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper2.psm1" -Resolve)

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    DownloadAndImportBcContainerHelper

    if ($project  -eq ".") { $project = "" }

    $containerName = GetContainerName($project)
    Remove-Bccontainer $containerName

    Trace-Information
}
catch {
    Trace-Exception -StackTrace $_.Exception.StackTrace
    throw
}
