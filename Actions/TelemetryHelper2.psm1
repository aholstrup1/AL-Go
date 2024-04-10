function Get-ApplicationInsightsTelemetryClient
{
    
    if ($null -eq $Global:TelemetryClient)
    {
        $AIPath = "$PSScriptRoot/Microsoft.ApplicationInsights.dll"
        [Reflection.Assembly]::LoadFile($AIPath) | Out-Null
        $TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
        $TelemetryClient.TelemetryConfiguration.ConnectionString = "InstrumentationKey=403ba4d3-ad2b-4ca1-8602-b7746de4c048;IngestionEndpoint=https://swedencentral-0.in.applicationinsights.azure.com/"
        $Global:TelemetryClient = $TelemetryClient
    }
    return $Global:TelemetryClient
}

function Trace-WorkflowStart() {
    # Calculate the AL-Go Version
    $alGoVersion = "main"
    
    # Calculate the repo type
    $repoType = "PTE"

    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{
        'AL-GoVersion' = $alGoVersion
        'RepoType' = $repoType
    }
    
    Trace-Information -Message "Workflow Started: $ENV:GITHUB_WORKFLOW" -AdditionalData $Data
}

function Trace-WorkflowEnd() {
    # Calculate the workflow conclusion
    $workflowConclusion = "Success"

    # Calculate the workflow duration
    $workflowDuration = 0

    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{
        'WorkflowConclusion' = $workflowConclusion
        'WorkflowDuration' = $workflowDuration
    }

    Trace-Information -Message "Workflow Ended: $ENV:GITHUB_WORKFLOW" -AdditionalData $Data
}

function Trace-Exception() {
    param(
        [String] $StackTrace
    )

    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{}
    $Data.Add('StackTrace', $StackTrace)

    Add-TelemetryEvent -Severity 'Error' -Data $Data
}

function Trace-Information() {
    param(
        [String] $Message,
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    )

    Add-TelemetryEvent -Message $Message -Severity 'Information'
}

function Add-TelemetryEvent()
{
    param(
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{},
        [String] $Message = 'aholstrupTest',
        [String] $Severity = 'Information'
    )

    Write-Host "Add-TelemetryEvent: $Message"

    # Check if the repository has opted out of telemetry before continuing

    $TelemetryClient = Get-ApplicationInsightsTelemetryClient
    
    # Add powershell version
    if (-not $Data.ContainsKey('PowerShellVersion'))
    {
        $Data.Add('PowerShellVersion', $PSVersionTable.PSVersion.ToString())
    }

    if ((-not $Data.ContainsKey('ContainerHelperVersion')) -and (Get-Module BcContainerHelper)) {
        $Data.Add('ContainerHelperVersion', (Get-Module BcContainerHelper).Version.ToString())
    }

    ### Add GitHub Actions information
    if ((-not $Data.ContainsKey('ActionName')) -and ($ENV:GITHUB_ACTION -ne $null))
    {
        $Data.Add('ActionName', $ENV:GITHUB_ACTION)
    }

    if ((-not $Data.ContainsKey('ActionPath')) -and ($ENV:GITHUB_ACTION_PATH -ne $null))
    {
        $actionPath = $ENV:GITHUB_ACTION_PATH.Substring($ENV:GITHUB_ACTION_PATH.IndexOf('AL-Go')) -replace '\\', '/'
        $Data.Add('ActionPath', $actionPath)
    }

    ### Add GitHub Workflow information
    if ((-not $Data.ContainsKey('WorkflowName')) -and ($ENV:GITHUB_WORKFLOW -ne $null))
    {
        $Data.Add('WorkflowName', $ENV:GITHUB_WORKFLOW)
    }

    ### Add GitHub Run information
    if ((-not $Data.ContainsKey('RefName')) -and ($ENV:GITHUB_REF_NAME -ne $null))
    {
        $Data.Add('RefName', $ENV:GITHUB_REF_NAME)
    }

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

    Write-Host "Tracking trace with severity $Severity and message $Message"

    $TelemetryClient.TrackTrace($Message, [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::$Severity, $Data)
    $TelemetryClient.Flush()
}

Export-ModuleMember -Function Trace-Exception, Trace-Information, Trace-WorkflowStart, Trace-WorkflowEnd