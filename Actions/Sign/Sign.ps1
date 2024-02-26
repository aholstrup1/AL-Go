﻿[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'GitHub Secrets are transferred as plain text')]
param(
    [Parameter(HelpMessage = "Azure Credentials secret", Mandatory = $true)]
    [string] $AzureCredentialsJson,
    [Parameter(HelpMessage = "The path to the files to be signed", Mandatory = $true)]
    [String] $PathToFiles,
    [Parameter(HelpMessage = "The URI of the timestamp server", Mandatory = $false)]
    [string] $TimestampService = "http://timestamp.digicert.com",
    [Parameter(HelpMessage = "The digest algorithm to use for signing and timestamping", Mandatory = $false)]
    [string] $digestAlgorithm = "sha256",
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $ParentTelemetryScopeJson = '7b7d'
)

$telemetryScope = $null

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    Import-Module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Sign.psm1" -Resolve)
    DownloadAndImportBcContainerHelper
    $telemetryScope = CreateScope -eventId 'DO0083' -parentTelemetryScopeJson $ParentTelemetryScopeJson

    Write-Host "::group::Install AzureSignTool"
    dotnet tool install --tool-path . sign --version 0.9.1-beta.24123.2 # TODO: Update version
    Write-Host "::endgroup::"

    $Files = Get-ChildItem -Path $PathToFiles -File | Select-Object -ExpandProperty FullName
    Write-Host "Signing files:"
    $Files | ForEach-Object {
        Write-Host "- $_"
    }

    $AzureCredentials = ConvertFrom-Json $AzureCredentialsJson
    $settings = $env:Settings | ConvertFrom-Json
    if ($settings.keyVaultName) {
        $AzureKeyVaultName = $settings.keyVaultName
    }
    elseif ($AzureCredentials.PSobject.Properties.name -eq "keyVaultName") {
        $AzureKeyVaultName = $AzureCredentials.keyVaultName
    }
    else {
        throw "KeyVaultName is not specified in AzureCredentials nor in settings. Please specify it in one of them."
    }
    
    $description = "Signed with AL-Go for GitHub"
    $descriptionUrl = "$ENV:GITHUB_SERVER_URL/$ENV:GITHUB_REPOSITORY"

    RetryCommand -Command { Param( $AzureKeyVaultName, $AzureCredentials, $digestAlgorithm, $TimestampService, $Certificate, $Files)
        ./sign code azure-key-vault `
            --azure-key-vault-url "https://$AzureKeyVaultName.vault.azure.net/" `
            --azure-key-vault-client-id $AzureCredentials.clientId `
            --azure-key-vault-tenant-id $AzureCredentials.tenantId `
            --azure-key-vault-client-secret $AzureCredentials.clientSecret `
            --azure-key-vault-certificate $Certificate `
            --timestamp-url "$TimestampService" `
            --timestamp-digest $digestAlgorithm `
            --file-digest $digestAlgorithm `
            --description $description `
            --description-url $descriptionUrl `
            --verbosity "Information" `
            --base-directory $PathToFiles `
            '**/*.app'
    } -MaxRetries 3 -ArgumentList $AzureKeyVaultName, $AzureCredentials, $digestAlgorithm, $TimestampService, $Settings.keyVaultCodesignCertificateName, $Files

    TrackTrace -telemetryScope $telemetryScope
}
catch {
    if (Get-Module BcContainerHelper) {
        TrackException -telemetryScope $telemetryScope -errorRecord $_
    }
    throw
}
