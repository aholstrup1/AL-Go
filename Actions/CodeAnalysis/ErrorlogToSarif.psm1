function ConvertTo-SarifLog {
    param (
        [string] $Path,
        [string] $OutputPath
    )

    $sarif = Get-SarifLog -Path $Path

    if ($OutputPath) {
        $sarifTrimmed = ($sarif | ConvertTo-Json -Depth 100).Trim()
        Write-Host "Writing SARIF log to $OutputPath"
        Write-Host $sarifTrimmed
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($OutputPath, $sarifTrimmed, $Utf8NoBomEncoding)
    }
    else {
        return $sarif
    }
    
}

function Get-SarifLog([string] $Path) {
    $errorlog = Get-Content $Path | ConvertFrom-Json

    Write-Host "Converting errorlog to SARIF log"
    Write-Host (Get-Content $Path)

    $sarifSchema = "https://json.schemastore.org/sarif-2.1.0.json"
    $version = "2.1.0"
    $runs = Get-Runs -ErrorLog $errorlog

    # construct json object with schema, version and runs
    $sarif = @{
        '$schema' = $sarifSchema
        version   = $version
        runs      = @($runs)
    }
    return $sarif
}

function Get-Runs([object] $ErrorLog) {
    $runs = @()
    $run = @{
        tool    = @{
            driver = @{
                name    = "Al-Go Code Analysis"
                version = "1.0.0"
                rules   = @(Get-Rules -ErrorLog $ErrorLog)
            }
        }
        results = @(Get-Results -ErrorLog $ErrorLog)
    }
    $runs += $run
    return $runs
}

function Get-Results([object] $ErrorLog) {
    # ruleId = ruleId
    # level = properties.severity
    # message.text = shortMessage
    $results = @()
    foreach ($error in $ErrorLog.issues) {
        $result = @{
            ruleId    = $error.ruleId
            level     = ($error.properties.severity).ToLower()
            message   = @{
                text = "$($error.fullMessage)"
            }
            locations = @(Get-Locations -ErrorLocation $error.locations)
        }
        $results += $result
    }
    return $results
}

function Get-Locations([object] $ErrorLocation) {
    $locations = @()
    foreach ($location in $ErrorLocation) {
        $location = @{
            physicalLocation = @{
                artifactLocation = @{
                    uri = GetLocalPath -Path $location.analysisTarget.uri
                }
                region           = @{
                    startLine   = $location.analysisTarget.region.startLine
                    startColumn = $location.analysisTarget.region.startColumn
                    endLine     = $location.analysisTarget.region.endLine
                    endColumn   = $location.analysisTarget.region.endColumn
                }
            }
        }
        $locations += $location
    }
    return $locations
}


function Get-Rules([object] $ErrorLog) {
    # Id = ruleId
    # Name = ruleId
    # ShortDescription.Text = properties.title
    # FullDescription.Text = properties.description
    # defaultConfiguration.level = properties.defaultSeverity
    # help.text = properties.helpLink
    # properties.tags = properties.category
    $rules = @()
    foreach ($error in $ErrorLog.issues) {
        if (RuleExists -ExistingRules $rules -RuleId $error.ruleId) {
            continue
        }

        if ($error.properties.title) {
            $message = $error.properties.title
        } else {
            $message = $error.fullMessage
        }

        $rule = @{
            id                   = $error.ruleId
            name                 = $error.ruleId
            shortDescription     = @{
                text = "$message"
            }
            fullDescription      = @{
                text = "$message"
            }
            defaultConfiguration = @{
                level = ($error.properties.defaultSeverity).ToLower()
            }
            help                 = @{
                text = $error.properties.helpLink
            }
            properties           = @{
                tags = @($error.properties.category)
            }
        }
        $rules += $rule
    }

    return $rules
}

function RuleExists($ExistingRules, $RuleId) {
    foreach ($rule in $ExistingRules) {
        if ($rule.id -eq $RuleId) {
            return $true
        }
    }
    return $false
}

function GetLocalPath($Path) {
    $localPath = $Path.Replace("c:\shared\", "")
    return $localPath
}

function Merge-Errorlogs([string] $Path, [string] $OutputPath) {
    $errorLogFiles = Get-ChildItem -Path "$Path\*ErrorLog*.json" -Recurse
    $mergedErrorLog = @()

    $issues = @()
    $version = ""
    $toolInfo = @{}

    foreach ($errorLogFile in $errorLogFiles) {
        $errorLog = Get-Content $errorLogFile.FullName | ConvertFrom-Json

        $issues += $errorLog.issues
        $version = $errorLog.version
        $toolInfo = $errorLog.toolInfo
    }

    $mergedErrorLog = @{
        version   = $version
        toolInfo  = $toolInfo
        issues    = $issues
    }

    $mergedErrorLog | ConvertTo-Json -Depth 100 | Out-File $OutputPath -Encoding utf8
}

Export-ModuleMember -Function Merge-Errorlogs
Export-ModuleMember -Function ConvertTo-SarifLog