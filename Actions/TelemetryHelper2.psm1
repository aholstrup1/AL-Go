$Script:MicrosoftTelemetryClient = $null
$Script:PartnerTelemetryClient = $null

. (Join-Path -Path $PSScriptRoot -ChildPath ".\AL-Go-Helper.ps1" -Resolve)

function LoadApplicationInsightsDll() {
    $AIPath = "$PSScriptRoot/Microsoft.ApplicationInsights.dll"
    [Reflection.Assembly]::LoadFile($AIPath) | Out-Null
}

function Get-ApplicationInsightsTelemetryClient
{
    # Check if the telemetry clients have already been created
    if ($Env:TelemetryClientsInitialized) {
        return
    }

    $repoSettings = ReadSettings

    # Load the Application Insights DLL
    LoadApplicationInsightsDll

    # Check if the repository has opted out of microsoft telemetry before continuing
    if ($repoSettings.sendExtendedTelemetryToMicrosoft -eq $true) {
        Write-Host "Enabling Microsoft telemetry..."
        Write-Host "Connection String: $($repoSettings.microsoftTelemetryConnectionString)"
        # Create a new TelemetryClient for Microsoft telemetry
        $Script:MicrosoftTelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
        $Script:MicrosoftTelemetryClient.TelemetryConfiguration.ConnectionString = $repoSettings.microsoftTelemetryConnectionString
    }

    # Set up a custom telemetry client if a connection string is provided
    if ($repoSettings.partnerTelemetryConnectionString -ne '') {
        Write-Host "Enabling partner telemetry..."
        Write-Host "Connection String: $($repoSettings.partnerTelemetryConnectionString)"
        $Script:PartnerTelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
        $Script:PartnerTelemetryClient.TelemetryConfiguration.ConnectionString = $repoSettings.partnerTelemetryConnectionString
    }
}

function Trace-WorkflowStart() {
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{}

    $alGoSettingsPath = "$ENV:GITHUB_WORKSPACE/.github/AL-Go-Settings.json"
    if (Test-Path -Path $alGoSettingsPath) {
        $repoSettings = Get-Content -Path $alGoSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Log the repository type
        if ($repoSettings.PSObject.Properties.Name -contains 'type') {
            $Data.Add('RepoType', $repoSettings.type)
        } else {
            $Data.Add('RepoType', '')
        }

        # Log the template URL
        if ($repoSettings.PSObject.Properties.Name -contains 'templateUrl') {
            $Data.Add('templateUrl', $repoSettings.templateUrl)
        } else {
            $Data.Add('templateUrl', '')
        }

        # Log the Al-Go version
        $alGoVersion = "main"
        $Data.Add('AlGoVersion', $alGoVersion)
    }

    Add-TelemetryEvent -Message "Workflow Started: $ENV:GITHUB_WORKFLOW" -Severity 'Information' -Data $Data
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

    Add-TelemetryEvent -Message "Workflow Ended: $ENV:GITHUB_WORKFLOW" -Severity 'Information' -Data $Data
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
        [String] $Message = "",
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    )

    if ($Message -eq "") {
        $actionPath = $ENV:GITHUB_ACTION_PATH.Substring($ENV:GITHUB_ACTION_PATH.IndexOf('AL-Go')) -replace '\\', '/'
        $Message = "AL-Go Action Ran: $actionPath"
    }

    Add-TelemetryEvent -Message $Message -Severity 'Information' -Data $AdditionalData
}

function Add-TelemetryEvent()
{
    param(
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{},
        [String] $Message = '',
        [String] $Severity = 'Information'
    )

    Write-Host "Add-TelemetryEvent: $Message"

    Get-ApplicationInsightsTelemetryClient

    if (($Script:MicrosoftTelemetryClient -eq $null) -and ($Script:PartnerTelemetryClient -eq $null)) {
        Write-Host "No telemetry clients found. Skipping telemetry."
        return
    }
    
    # Add powershell version
    if (-not $Data.ContainsKey('PowerShellVersion'))
    {
        $Data.Add('PowerShellVersion', $PSVersionTable.PSVersion.ToString())
    }

    if ((-not $Data.ContainsKey('ContainerHelperVersion')) -and (Get-Module BcContainerHelper)) {
        $Data.Add('ContainerHelperVersion', (Get-Module BcContainerHelper).Version.ToString())
    }

    ### Add GitHub Actions information
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

    $Script:PartnerTelemetryClient.TrackTrace($Message, [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::$Severity, $Data)

    <#foreach ($TelemetryClient in $TelemetryClients) {
        Write-Host "Telemetry Configuration Connection String: $($TelemetryClient.TelemetryConfiguration.ConnectionString)"
        $TelemetryClient.TrackTrace($Message, [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::$Severity, $Data)
    }#>
}

Export-ModuleMember -Function Trace-Exception, Trace-Information, Trace-WorkflowStart, Trace-WorkflowEnd, Get-ApplicationInsightsTelemetryClient