. (Join-Path -Path $PSScriptRoot -ChildPath ".\AL-Go-Helper.ps1" -Resolve)

#region Loading telemetry helper
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
#endregion

#region Helper functions
function GetActionName() {
    if ($null -eq $ENV:GITHUB_ACTION_PATH) {
        return ""
    }
    return $ENV:GITHUB_ACTION_PATH.Split("/")[-1]
}

function GetAlGoVersion() {
    if ($null -eq $ENV:GITHUB_ACTION_PATH) {
        return ""
    }

    $actionPath = "$ENV:GITHUB_ACTION_PATH".Split('\')
    $branch = $actionPath[$actionPath.Count-2]
    $owner = $actionPath[$actionPath.Count-4]

    if ($owner -ne "microsoft") {
        return "Developer/Private"
    } else {
        return $branch
    }
}
#endregion

function AddTelemetryEvent()
{
    param(
        [Parameter(Mandatory = $true)]
        [String] $Message,
        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $Data = @{},
        [Parameter(Mandatory = $false)]
        [ValidateSet("Information", "Error")]
        [String] $Severity = 'Information'
    )

    try {
        # Add powershell version
        Add-TelemetryData -Hashtable $Data -Key 'PowerShellVersion' -Value ($PSVersionTable.PSVersion.ToString())

        if ((Get-Module BcContainerHelper)) {
            Add-TelemetryData -Hashtable $Data -Key 'BcContainerHelperVersion' -Value ((Get-Module BcContainerHelper).Version.ToString())
        }

        Add-TelemetryData -Hashtable $Data -Key 'ALGoVersion' -Value (GetAlGoVersion)
        Add-TelemetryData -Hashtable $Data -Key 'WorkflowName' -Value $ENV:GITHUB_WORKFLOW
        Add-TelemetryData -Hashtable $Data -Key 'RunnerOs' -Value $ENV:RUNNER_OS
        Add-TelemetryData -Hashtable $Data -Key 'RunId' -Value $ENV:GITHUB_RUN_ID
        Add-TelemetryData -Hashtable $Data -Key 'RunNumber' -Value $ENV:GITHUB_RUN_NUMBER
        Add-TelemetryData -Hashtable $Data -Key 'RunAttempt' -Value $ENV:GITHUB_RUN_ATTEMPT
        Add-TelemetryData -Hashtable $Data -Key 'JobId' -Value $ENV:GITHUB_JOB

        ### Add GitHub Repository information
        Add-TelemetryData -Hashtable $Data -Key 'Repository' -Value $ENV:GITHUB_REPOSITORY

        $repoSettings = ReadSettings
        if ($repoSettings.microsoftTelemetryConnectionString -ne '') {
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
    } catch {
        Write-Host "Failed to log telemetry event: $_"
    }
}

<#
    .SYNOPSIS
    Logs an information message to telemetry

    .DESCRIPTION
    Logs an information message to telemetry

    .PARAMETER Message
    The message to log to telemetry

    .PARAMETER AdditionalData
    Additional data to log to telemetry

    .EXAMPLE
    Trace-Information -Message "AL-Go action ran: $actionName"
#>
function Trace-Information() {
    param(
        [String] $Message,
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    )

    if (-not $Message) {
        $Message = "AL-Go action ran: $(GetActionName)"
    }

    AddTelemetryEvent -Message $Message -Severity 'Information' -Data $AdditionalData
}

<#
    .SYNOPSIS
    Logs an exception message to telemetry

    .DESCRIPTION
    Logs an exception message to telemetry

    .PARAMETER ErrorRecord
    The error record to log to telemetry

    .EXAMPLE
    Trace-Exception -ErrorRecord $ErrorRecord
#>
function Trace-Exception() {
    param(
        [System.Management.Automation.ErrorRecord] $ErrorRecord = $null
    )

    [System.Collections.Generic.Dictionary[[System.String], [System.String]]] $AdditionalData = @{}
    if ($ErrorRecord -ne $null) {
        Add-TelemetryData -Hashtable $AdditionalData -Key 'ErrorMessage' -Value $ErrorRecord.Exception.Message
        Add-TelemetryData -Hashtable $AdditionalData -Key 'ErrorStackTrace' -Value $ErrorRecord.ScriptStackTrace
    }

    $Message = "AL-Go action failed: $(GetActionName)"
    AddTelemetryEvent -Message $Message -Severity 'Error' -Data $AdditionalData
}

<#
    .SYNOPSIS
    Adds a key-value pair to a hashtable if the key does not already exist

    .DESCRIPTION
    Adds a key-value pair to a hashtable if the key does not already exist

    .PARAMETER Hashtable
    The hashtable to add the key-value pair to

    .PARAMETER Key
    The key to add to the hashtable

    .PARAMETER Value
    The value to add to the hashtable

    .EXAMPLE
    Add-TelemetryData -Hashtable $AdditionalData -Key 'RepoType' -Value 'PTE'
#>
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

Export-ModuleMember -Function Trace-Information, Trace-Exception, Add-TelemetryData