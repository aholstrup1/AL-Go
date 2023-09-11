param(
    [string] $Path,
    [string] $OutputPath
)

Import-Module $PSScriptRoot/ErrorlogToSarif.psm1

$logfiles = Get-ChildItem -Path $Path -Filter errorLog.json -Recurse
Write-Host "Found $($logfiles) errorlog.Json files"
$logfiles | ForEach-Object {
    Write-Host "Processing $($_.FullName)"
    ConvertTo-SarifLog -Path $_.FullName -OutputPath $OutputPath
} 
