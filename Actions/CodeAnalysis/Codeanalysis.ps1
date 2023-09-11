param(
    [string] $Path,
    [string] $OutputPath
)

Import-Module $PSScriptRoot/ErrorlogToSarif.psm1

ConvertTo-SarifLog -Path $Path -OutputPath $OutputPath