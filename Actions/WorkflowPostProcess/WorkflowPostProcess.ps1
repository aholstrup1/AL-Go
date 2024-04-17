Param(
    [Parameter(HelpMessage = "The event Id of the initiating workflow", Mandatory = $true)]
    [string] $eventId,
    [Parameter(HelpMessage = "Telemetry scope generated during the workflow initialization", Mandatory = $false)]
    [string] $telemetryScopeJson = ''
)

import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper2.psm1" -Resolve)
Trace-WorkflowEnd