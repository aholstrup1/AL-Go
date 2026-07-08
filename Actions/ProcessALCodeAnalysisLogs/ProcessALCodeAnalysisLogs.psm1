<#
    .SYNOPSIS
    Normalizes a file path by converting backslashes to forward slashes and removing leading drive letters.
    .DESCRIPTION
    This function takes a file path as input, converts all backslashes to forward slashes,
    and removes any leading drive letters (e.g., "C:") to standardize the path format.
    .PARAMETER Path
    The file path to normalize.
#>
function NormalizePath {
    param(
        [string] $Path
    )
    if ($null -eq $Path) {
        return $null
    }
    $normalizedPath = $Path -replace '\\', '/' # Convert backslashes to forward slashes
    $normalizedPath = $normalizedPath -replace '^[A-Za-z]:', '' # Remove leading drive letter
    $normalizedPath = $normalizedPath -replace '^\./', '' # Remove leading ./
    return $normalizedPath
}

<#
    .SYNOPSIS
    Converts a workspace-relative path into a valid SARIF artifact URI.
    .DESCRIPTION
    SARIF artifactLocation URIs must be valid URI references. Relative paths from BC projects can contain
    characters that are not valid in a URI (most commonly spaces, e.g. '1.Setup Data/Foo.al'), which makes
    github/codeql-action/upload-sarif log "'...' is not a valid URI" warnings and can prevent alerts from
    mapping to files. This URI-encodes each path segment individually with [Uri]::EscapeDataString while
    preserving the '/' separators, producing a valid relative URI (e.g. '1.Setup%20Data/Foo.al').
    .PARAMETER RelativePath
    The forward-slash-separated workspace-relative path to encode.
    .OUTPUTS
    The URI-encoded relative path, or the original value when it is null or empty.
#>
function ConvertTo-SarifArtifactUri {
    param(
        [Parameter(Mandatory = $false)]
        [string] $RelativePath
    )
    if ([string]::IsNullOrEmpty($RelativePath)) {
        return $RelativePath
    }
    return (($RelativePath -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

<#
    .SYNOPSIS
    Gets the relative path from a base path to a target path using PowerShell 5/7 compatible approach.
    .DESCRIPTION
    This function calculates the relative path from a base path to a target path by temporarily
    changing to the base directory and using Resolve-Path -Relative.
    .PARAMETER BasePath
    The base path from which to calculate the relative path.
    .PARAMETER TargetPath
    The target path to which the relative path should point.
#>
function GetRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BasePath,
        [Parameter(Mandatory = $true)]
        [string] $TargetPath
    )
    $relativePath = $null

    try {
        # Push to the base path location
        Push-Location -Path $BasePath

        # Get the relative path from current location to target
        $relativePath = Resolve-Path -Path $TargetPath -Relative
    }
    catch {
        OutputDebug -message "Error getting relative path from '$BasePath' to '$TargetPath': $_"
    }
    finally {
        # Always pop back to original location
        Pop-Location
    }
    return $relativePath
}

$script:__workspaceFileIndex = $null
$script:__workspaceFileIndexRoot = $null

<#
    .SYNOPSIS
    Returns a lazily-built index of file names to full paths for the given workspace.
    .DESCRIPTION
    Enumerates the workspace once and caches a hashtable keyed by lower-cased file name, whose values
    are the list of full paths sharing that name. Subsequent calls for the same workspace reuse the
    cached index. This avoids re-scanning the entire workspace for every file lookup, which is critical
    when processing large numbers of diagnostics.
    .PARAMETER WorkspacePath
    The workspace path to index.
#>
function Get-WorkspaceFileIndex {
    param(
        [Parameter(Mandatory = $true)]
        [string] $WorkspacePath
    )

    if (($null -ne $script:__workspaceFileIndex) -and ($script:__workspaceFileIndexRoot -eq $WorkspacePath)) {
        return $script:__workspaceFileIndex
    }

    $index = @{}
    Get-ChildItem -Path $WorkspacePath -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $key = $_.Name.ToLowerInvariant()
        if (-not $index.ContainsKey($key)) {
            $index[$key] = [System.Collections.Generic.List[string]]::new()
        }
        $index[$key].Add($_.FullName)
    }

    $script:__workspaceFileIndex = $index
    $script:__workspaceFileIndexRoot = $WorkspacePath
    return $index
}

<#
    .SYNOPSIS
    Clears the cached workspace file index.
    .DESCRIPTION
    Primarily used by tests to force the index to be rebuilt for a new workspace.
#>
function Reset-WorkspaceFileIndex {
    $script:__workspaceFileIndex = $null
    $script:__workspaceFileIndexRoot = $null
}

<#
    .SYNOPSIS
    Finds a file in the workspace based on its absolute path.
    .DESCRIPTION
    Given an absolute path, this function searches the workspace for a file with the same name and returns its relative path.
    If no file is found, it returns $null.
    .PARAMETER AbsolutePath
    The absolute path of the file to find.
    .PARAMETER WorkspacePath
    The workspace path to search in. Defaults to the GITHUB_WORKSPACE environment variable.
#>
function Get-FileFromAbsolutePath {
    param(
        [Parameter(HelpMessage = "The absolute path of the file to find.", Mandatory = $true)]
        [string] $AbsolutePath,
        [Parameter(HelpMessage = "The workspace path to search in.", Mandatory = $false)]
        [string] $WorkspacePath = $ENV:GITHUB_WORKSPACE
    )

    # Remove leading drive letter and convert backslashes to forward slashes to match unix-style paths
    $normalizedPath = NormalizePath -path $AbsolutePath

    if (Test-Path -Path $normalizedPath -PathType Leaf) {
        OutputDebug -message "File exists at absolute path: $AbsolutePath"
        # If the file exists at the absolute path, return the relative path from the workspace root
        $relativePath = GetRelativePath -BasePath $workspacePath -TargetPath $normalizedPath
        return NormalizePath -Path $relativePath
    }

    # Extract the file name from the absolute path
    $fileName = [System.IO.Path]::GetFileName($normalizedPath)

    # Search the workspace for a file with that name. Use a lazily-built index (name -> full paths)
    # so the workspace is enumerated at most once per process, instead of once per lookup. This keeps
    # processing large numbers of diagnostics (e.g. multi-country builds) from scaling quadratically.
    $index = Get-WorkspaceFileIndex -WorkspacePath $WorkspacePath
    $key = $fileName.ToLowerInvariant()
    if ($index.ContainsKey($key) -and $index[$key].Count -eq 1) {
        OutputDebug -message "Found one matching file for absolute path: $AbsolutePath"
        $relativePath = GetRelativePath -BasePath $workspacePath -TargetPath $index[$key][0]
        return NormalizePath -Path $relativePath
    }

    OutputDebug -message "Could not find file for absolute path: $AbsolutePath"
    return $null
}

<#
    .SYNOPSIS
    Extracts the most appropriate message from an issue object.
    .DESCRIPTION
    Given an issue object, this function checks for the presence of "shortMessage" and "fullMessage" properties
    and returns the most appropriate one based on their availability.
    If neither property is available, it returns $null.
    .PARAMETER issue
    The issue object to extract the message from.
#>
function Get-IssueMessage {
    param(
        [Parameter(HelpMessage = "The issue object to extract the message from.", Mandatory = $true)]
        [PSCustomObject] $issue
    )

    if ($issue.PSObject.Properties.Name -contains "shortMessage") {
        return $issue.shortMessage
    } elseif ($issue.PSObject.Properties.Name -contains "fullMessage") {
        return $issue.fullMessage
    } else {
        return $null
    }
}

<#
    .SYNOPSIS
    Maps the issue severity from the AL code analysis log to a standardized severity level.
    .DESCRIPTION
    This function takes an issue object and checks its "severity" property.
    It maps the severity levels "error", "warning", "info", and "hidden" to "error", "warning", "note", and "none" respectively.
    If the severity is not recognized, it defaults to "none".
    .PARAMETER issue
    The issue object to extract the severity from.
    .OUTPUTS
    A string representing the standardized severity level.
#>
function Get-IssueSeverity {
    param(
        [Parameter(HelpMessage = "The issue object to extract the severity from.", Mandatory = $true)]
        [PSCustomObject] $issue
    )

    if ($issue.properties.PSObject.Properties.Name -notcontains "severity") {
        return "none"
    }

    $compilerSeverity = $issue.properties.severity

    switch ($compilerSeverity.ToLower()) {
        "error"   { return "error" }
        "warning" { return "warning" }
        "info"    { return "note" }
        "hidden"  { return "none" }
        default    { return "none" }
    }
}

Export-ModuleMember -Function Get-FileFromAbsolutePath, Get-IssueMessage, Get-IssueSeverity, Get-WorkspaceFileIndex, Reset-WorkspaceFileIndex, ConvertTo-SarifArtifactUri
