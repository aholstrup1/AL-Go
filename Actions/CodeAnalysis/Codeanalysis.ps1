param(
    [string] $Path,
    [string] $OutputPath
)

Import-Module $PSScriptRoot/ErrorlogToSarif.psm1

# Get all errorlog.json files and merge them into a single file
$mergedErrorLog = Join-Path $Path "MergedErrorLog.json"
Merge-Errorlogs -Path $Path -OutputPath $mergedErrorLog

# Convert the merged file to a SARIF log
if (Test-Path $mergedErrorLog) {
    ConvertTo-SarifLog -Path $mergedErrorLog -OutputPath $OutputPath
} else {
    Write-Error "Could not find merged errorlog file at $mergedErrorLog"
}

if (Test-Path $OutputPath) {
    Add-Content -Encoding UTF8 -Path $env:GITHUB_OUTPUT -Value "SarifLogExists=$true" 
} else {
    Add-Content -Encoding UTF8 -Path $env:GITHUB_OUTPUT -Value "SarifLogExists=$false" 
}