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
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}

    $alGoSettingsPath = "$ENV:GITHUB_WORKSPACE/.github/AL-Go-Settings.json"
    if (Test-Path -Path $alGoSettingsPath) {
        $repoSettings = Get-Content -Path $alGoSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Log the repository type
        if ($repoSettings.PSObject.Properties.Name -contains 'type') {
            Add-TelemetryData -Hashtable $AdditionalData -Key 'RepoType' -Value $repoSettings.type
        }

        # Log the template URL
        if ($repoSettings.PSObject.Properties.Name -contains 'templateUrl') {
            Add-TelemetryData -Hashtable $AdditionalData -Key 'TemplateUrl' -Value $repoSettings.templateUrl
        }

        # Log the Al-Go version
        $alGoVersion = "main"
        Add-TelemetryData -Hashtable $AdditionalData -Key 'AlGoVersion' -Value $alGoVersion
    }

    Add-TelemetryEvent -Message "AL-Go workflow started: $($ENV:GITHUB_WORKFLOW.Trim())" -Severity 'Information' -Data $AdditionalData
}

function Trace-WorkflowEnd($TelemetryScopeJson) {
    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}

    $telemetryScope = $null
    if ($TelemetryScopeJson -ne '') {
        $telemetryScope = $TelemetryScopeJson | ConvertFrom-Json
    }

    # Calculate the workflow conclusion using the github api
    $workflowJobs = gh api /repos/$ENV:GITHUB_REPOSITORY/actions/runs/$ENV:GITHUB_RUN_ID/jobs -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" | ConvertFrom-Json
    if ($workflowJobs -ne $null) {
        $failedJobs = $workflowJobs.jobs | Where-Object { $_.conclusion -eq "failure" }
        if ($failedJobs -eq $null) {
            $workflowConclusion = "Success"
        } else {
            $workflowConclusion = "Failure"
        }
        Add-TelemetryData -Hashtable $AdditionalData -Key 'WorkflowConclusion' -Value $workflowConclusion
    }

    # Calculate the workflow duration using the github api
    <#if ($telemetryScope -and ($telemetryScope.workflowStartTime -ne $null)) {
        Write-Host "Calculating workflow duration..."
        $workflowTiming= [DateTime]::UtcNow.Subtract([DateTime]::Parse($telemetryScope.workflowStartTime)).TotalSeconds
        Add-TelemetryData -Hashtable $AdditionalData -Key 'WorkflowDuration' -Value $workflowTiming
    }#>

    $workFlowName = $ENV:GITHUB_WORKFLOW.Trim().Replace("/", "")

    Add-TelemetryEvent -Message "AL-Go workflow ran: $workFlowName" -Severity 'Information' -Data $AdditionalData
}

function Trace-Exception() {
    param(
        [String] $Message,
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{},
        [System.Management.Automation.ErrorRecord] $ErrorRecord = $null
    )

    if (-not $Message) {
        $actionName = $ENV:GITHUB_ACTION_PATH.Split("/")[-1]
        $Message = "AL-Go action failed: $actionName"
    }

    if ($ErrorRecord -ne $null) {
        Add-TelemetryData -Hashtable $AdditionalData -Key 'ErrorMessage', -Value $ErrorRecord.Exception.Message
        Add-TelemetryData -Hashtable $AdditionalData -Key 'ErrorStackTrace', -Value $ErrorRecord.ScriptStackTrace
    }

    Add-TelemetryEvent -Message $Message -Severity 'Error' -Data $AdditionalData
}

function Trace-Information() {
    param(
        [String] $Message,
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    )

    if (-not $Message) {
        $actionName = $ENV:GITHUB_ACTION_PATH.Split("/")[-1]
        $Message = "AL-Go action ran: $actionName"
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
    Add-TelemetryData -Hashtable $Data -Key 'PowerShellVersion' -Value ($PSVersionTable.PSVersion.ToString())

    if ((Get-Module BcContainerHelper)) {
        Add-TelemetryData -Hashtable $Data -Key 'BcContainerHelperVersion' -Value ((Get-Module BcContainerHelper).Version.ToString())
    }

    ### Add GitHub Actions information
    if ($ENV:GITHUB_ACTION_PATH -ne $null)
    {
        $actionPath = $ENV:GITHUB_ACTION_PATH.Substring($ENV:GITHUB_ACTION_PATH.IndexOf('AL-Go')) -replace '\\', '/'
        Add-TelemetryData -Hashtable $Data -Key 'ActionPath' -Value $actionPath
    }

    Add-TelemetryData -Hashtable $Data -Key 'WorkflowName' -Value $ENV:GITHUB_WORKFLOW
    Add-TelemetryData -Hashtable $Data -Key 'RunnerOs' -Value $ENV:RUNNER_OS
    Add-TelemetryData -Hashtable $Data -Key 'RunId' -Value $ENV:GITHUB_RUN_ID
    Add-TelemetryData -Hashtable $Data -Key 'RunNumber' -Value $ENV:GITHUB_RUN_NUMBER
    Add-TelemetryData -Hashtable $Data -Key 'RunAttempt' -Value $ENV:GITHUB_RUN_ATTEMPT
    Add-TelemetryData -Hashtable $Data -Key 'JobId' -Value $ENV:GITHUB_JOB

    ### Add GitHub Repository information
    Add-TelemetryData -Hashtable $Data -Key 'Repository' -Value $ENV:GITHUB_REPOSITORY

    Write-Host "Tracking trace with severity $Severity and message $Message"
    $repoSettings = ReadSettings

    if ($repoSettings.microsoftTelemetryConnectionString -ne '') {
        Write-Host "Enabling Microsoft telemetry..."
        $MicrosoftTelemetryClient = Get-ApplicationInsightsTelemetryClient -TelemetryConnectionString $repoSettings.microsoftTelemetryConnectionString
        Write-Host "Logging telemetry with message: $Message, severity: $Severity"
        # Log key and value pairs in data hashtab
        $data.GetEnumerator() | ForEach-Object {
            Write-Host "Key: $($_.Key), Value: $($_.Value)"
        }

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

function Add-TelemetryData() {
    param(
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Hashtable,
        [String] $Key,
        [String] $Value
    )

    if (-not $Hashtable.ContainsKey($Key) -and ($Value -ne '')) {
        $Hashtable.Add($Key, $Value)
    }

}

Export-ModuleMember -Function Trace-Exception, Trace-Information, Trace-WorkflowStart, Trace-WorkflowEnd