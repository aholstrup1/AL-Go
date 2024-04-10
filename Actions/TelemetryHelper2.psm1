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
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{}

    $alGoSettingsPath = "$ENV:GITHUB_WORKSPACE/.github/AL-Go-Settings.json"
    if (Test-Path -Path $alGoSettingsPath) {
        $repoSettings = Get-Content -Path $alGoSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json | ConvertTo-HashTable
        
        # Log the repository type
        if ($repoSettings.Keys -contains 'type') {
            $Data.Add('RepoType', $repoType)
        } else {
            $Data.Add('RepoType', '')
        }

        # Log the template URL
        if ($repoSettings.Keys -contains 'templateUrl') {
            $Data.Add('templateUrl', $repoSettings['templateUrl'])
        } else {
            $Data.Add('templateUrl', '')
        }

        # Log the Al-Go version
        $alGoVersion = "main"
        $Data.Add('AlGoVersion', $alGoVersion)
    }

    
    Trace-Information -Message "Workflow Started: $ENV:GITHUB_WORKFLOW" -AdditionalData $Data
}

function Trace-WorkflowEnd() {
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{}

    # Calculate the workflow conclusion using the github api
    $workflowJobs = gh api /repos/$ENV:GITHUB_REPOSITORY/actions/runs/$ENV:GITHUB_RUN_ID/jobs -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" | ConvertFrom-Json
    $workflowConclusion = $workflowJobs.jobs | Where-Object { $_.conclusion -eq "failure" }
    $Data.Add('WorkflowConclusion', $workflowConclusion)

    # Calculate the workflow duration using the github api
    $workflowDuration = 0

    $Data.Add('WorkflowDuration', $workflowDuration)

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

    Add-TelemetryEvent -Message $Message -Severity 'Information' -Data $AdditionalData
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