
function Get-SuggestedFix() {
    param(
        [string] $ApiKey = "",
        [string] $ErrorLog,
        [string] $CodeSnippet,
        [int] $MaxTokens = 300
    )

    $Instructions = "You are given an warning produced by the AL for Business Central compiler and the code snippet that is producing the error. Your job is to suggest a fix:"
    $Content = "Instructions: $Instructions Warning: $ErrorLog"

    if ($CodeSnippet) {
        $Content +=  " Code Snippet: $CodeSnippet"
    }

    Write-Host "Content: $Content"

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("api-key", $ApiKey)

    <#$body = @"
{
    `"max_tokens`":  $MaxTokens,
    `"messages`":  [
                     {
                         `"content`":  `"$Content`",
                         `"role`":  `"assistant`"
                     }
                 ],
    `"temperature`":  0.7
}
"@#>

    $Body = @{
        max_tokens = $MaxTokens
        messages = @(
            @{
                content = $Content
                role = "assistant"
            }
        )
        temperature = 0.7
    }

    $Body = $Body | ConvertTo-Json

    $response = Invoke-RestMethod 'https://emeaopenai.azure-api.net/openai/deployments/gpt-35-turbo-16k/chat/completions?api-version=2023-07-01-preview' -Method 'POST' -Headers $headers -Body $Body

    return $response.choices.message.content
}

function Get-CodeSnippet([Object] $Result) {

    $file = $Result.locations.physicalLocation.artifactLocation.uri
    $startLine = $Result.locations.physicalLocation.region.startLine - 1
    $readLines = $Result.locations.physicalLocation.region.endLine - $startLine + 5
    $codeSnippet = Get-Content $file | Select-Object -Skip $startLine -First $readLines
    $codeSnippet = $codeSnippet -join " "

    return $codeSnippet | ConvertTo-Json
}

function Get-WarningMessage([Object] $Result) {
    return $Result.message.text
}

function Get-CoPilotMessage([Object] $Result) 
{
    $codeSnippet = Get-CodeSnippet -Result $Result
    $warningMessage = Get-WarningMessage -Result $Result
    $suggestedFix = Get-SuggestedFix -ErrorLog $warningMessage -CodeSnippet $codeSnippet
    return $suggestedFix
}

function Enrich-SarifLog([string] $Path) {
    $sarif = Get-Content $Path | ConvertFrom-Json
    $runs = $sarif.runs
    $runs[0].results | ForEach-Object {
        $suggestedFix = Get-CoPilotMessage -Result $_
        $_.message.text = $suggestedFix
    }
    $sarif.runs = $runs
    $sarif = $sarif | ConvertTo-Json -Depth 99

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($Path, $sarif, $Utf8NoBomEncoding)
}

Export-ModuleMember *-*