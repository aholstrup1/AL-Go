function Get-ApplicationInsightsTelemetryClient
{
    
    if ($null -eq $Global:TelemetryClient)
    {
        $AIPath = "$PSScriptRoot/Microsoft.ApplicationInsights.dll"
        [Reflection.Assembly]::LoadFile($AIPath) | Out-Null
        $InstrumentationKey = '403ba4d3-ad2b-4ca1-8602-b7746de4c048'
        $TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
        $TelemetryClient.InstrumentationKey = $InstrumentationKey
        $Global:TelemetryClient = $TelemetryClient
    }
    return $Global:TelemetryClient
}


function Add-TelemetryEvent()
{
    param(
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{},
        [String] $Message = 'aholstrupTest',
        [String] $Severity = 'Information'
    )

    $TelemetryClient = Get-ApplicationInsightsTelemetryClient
    
    # Add powershell version
    if (-not $Data.ContainsKey('PowerShellVersion'))
    {
        $Data.Add('PowerShellVersion', $PSVersionTable.PSVersion.ToString())
    }

    ### Add GitHub Actions information
    if ((-not $Data.ContainsKey('ActionName')) -and ($ENV:GITHUB_ACTION_REPOSITORY -ne $null))
    {
        $Data.Add('ActionName', $ENV:GITHUB_ACTION_REPOSITORY)
    }

    if ((-not $Data.ContainsKey('ActionVersion')) -and ($ENV:GITHUB_ACTION_PATH -ne $null))
    {
        # Get action version from action path
        $Data.Add('ActionVersion', $ENV:GITHUB_ACTION_PATH.Split('/')[-1])
    }

    ### Add GitHub Workflow information
    if ((-not $Data.ContainsKey('WorkflowName')) -and ($ENV:GITHUB_WORKFLOW -ne $null))
    {
        $Data.Add('WorkflowName', $ENV:GITHUB_WORKFLOW)
    }

    ### Add GitHub Run information
    if ((-not $Data.ContainsKey('RunnerOs')) -and ($ENV:RUNNER_OS -ne $null))
    {
        $Data.Add('RunnerOs', $ENV:RUNNER_OS)
    }

    if ((-not $Data.ContainsKey('RunId')) -and ($ENV:GITHUB_RUN_ID -ne $null))
    {
        $Data.Add('RunId', $ENV:GITHUB_RUN_ID)
    }

    if ((-not $Data.ContainsKey('RunNumber')) -and ($ENV:GITHUB_RUN_NUMBER -ne $null))
    {
        $Data.Add('RunNumber', $ENV:GITHUB_RUN_NUMBER)
    }

    if ((-not $Data.ContainsKey('RunAttempt')) -and ($ENV:GITHUB_RUN_ATTEMPT -ne $null))
    {
        $Data.Add('RunAttempt', $ENV:GITHUB_RUN_ATTEMPT)
    }

    ### Add GitHub Repository information
    if ((-not $Data.ContainsKey('Repository')) -and ($ENV:GITHUB_REPOSITORY -ne $null))
    {
        $Data.Add('Repository', $ENV:GITHUB_REPOSITORY)
    }

    $TelemetryClient.TrackTrace($Message, [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::$Severity, $Data)
}