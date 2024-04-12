. (Join-Path -Path $PSScriptRoot -ChildPath ".\AL-Go-Helper.ps1" -Resolve)

function DownloadNugetPackage($PackageName, $PackageVersion) {
    $nugetPackagePath = Join-Path "$ENV:GITHUB_WORKSPACE" "/.nuget/packages/$PackageName/$PackageVersion/"

    if (-not (Test-Path -Path $nugetPackagePath)) {
        $url = "https://www.nuget.org/api/v2/package/$PackageName/$PackageVersion"

        Write-Host "Downloading Nuget package $PackageName $PackageVersion..."
        New-Item -ItemType Directory -Path $nugetPackagePath | Out-Null
        Invoke-WebRequest -Uri $Url -OutFile "$nugetPackagePath/$PackageName.$PackageVersion.zip"

        # Unzip the package
        Expand-Archive -Path "$nugetPackagePath/$PackageName.$PackageVersion.zip" -DestinationPath "$nugetPackagePath"

        # Remove the zip file
        Remove-Item -Path "$nugetPackagePath/$PackageName.$PackageVersion.zip"
    }

    return $nugetPackagePath
}

function LoadApplicationInsightsDll() {
    $packagePath = DownloadNugetPackage -PackageName "Microsoft.ApplicationInsights" -PackageVersion (Get-PackageVersion -PackageName "Microsoft.ApplicationInsights")
    $AppInsightsDllPath = "$packagePath/lib/net46/Microsoft.ApplicationInsights.dll"

    if (-not (Test-Path -Path $AppInsightsDllPath)) {
        throw "Failed to download Application Insights DLL"
    }

    [Reflection.Assembly]::LoadFile($AppInsightsDllPath) | Out-Null
}

function Get-ApplicationInsightsTelemetryClient($TelemetryConnectionString)
{
    # Load the Application Insights DLL
    LoadApplicationInsightsDll

    $TelemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
    $TelemetryClient.TelemetryConfiguration.ConnectionString = $TelemetryConnectionString

    return $TelemetryClient
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
    $workflowTiming = 0

    $Data.Add('WorkflowDuration', $workflowDuration)

    Add-TelemetryEvent -Message "Workflow Ended: $ENV:GITHUB_WORKFLOW" -Severity 'Information' -Data $Data
}

function Trace-Exception() {
    param(
        [String] $Message = "",
        [System.Management.Automation.ErrorRecord] $ErrorRecord = $null
    )

    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{}
    $Data.Add('ErrorMessage', $ErrorRecord.Exception.Message)
    $Data.Add('ErrorStackTrace', $ErrorRecord.ScriptStackTrace)

    if ($Message -eq "") {
        $actionPath = $ENV:GITHUB_ACTION_PATH.Substring($ENV:GITHUB_ACTION_PATH.IndexOf('AL-Go')) -replace '\\', '/'
        $Message = "AL-Go Action Failed: $actionPath"
    }

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

    if ((-not $Data.ContainsKey('JobId')) -and ($ENV:GITHUB_JOB -ne $null))
    {
        $Data.Add('JobId', $ENV:GITHUB_JOB)
    }

    ### Add GitHub Repository information
    if ((-not $Data.ContainsKey('Repository')) -and ($ENV:GITHUB_REPOSITORY -ne $null))
    {
        $Data.Add('Repository', $ENV:GITHUB_REPOSITORY)
    }

    Write-Host "Tracking trace with severity $Severity and message $Message"

    $repoSettings = ReadSettings

    if ($repoSettings.sendExtendedTelemetryToMicrosoft -eq $true) {
        Write-Host "Enabling Microsoft telemetry..."
        $MicrosoftTelemetryClient = Get-ApplicationInsightsTelemetryClient -TelemetryConnectionString $repoSettings.microsoftTelemetryConnectionString
        $MicrosoftTelemetryClient.TrackTrace($Message, [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::$Severity, $Data)
        $MicrosoftTelemetryClient.Flush()
    }

    if ($repoSettings.partnerTelemetryConnectionString -ne '') {
        Write-Host "Enabling partner telemetry..."
        $PartnerTelemetryClient = Get-ApplicationInsightsTelemetryClient -TelemetryConnectionString $repoSettings.partnerTelemetryConnectionString
        $PartnerTelemetryClient.TrackTrace($Message, [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::$Severity, $Data)
        $PartnerTelemetryClient.Flush()
    }
}

Export-ModuleMember -Function Trace-Exception, Trace-Information, Trace-WorkflowStart, Trace-WorkflowEnd