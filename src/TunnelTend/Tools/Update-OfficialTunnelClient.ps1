#requires -Version 7.2
#requires -PSEdition Core

<#
.SYNOPSIS
Safely updates the Windows release of openai/tunnel-client from the official
GitHub repository.

.DESCRIPTION
The updater:
  * queries only https://api.github.com/repos/openai/tunnel-client;
  * selects the stable Windows ZIP for the current architecture;
  * verifies the GitHub SHA-256 digest, a published checksum, or (as a
    fallback) trusted OpenAI Authenticode signatures;
  * extracts into an isolated staging directory with traversal and size guards;
  * identifies running processes by exact executable path;
  * backs up every managed destination file before replacement;
  * replaces files through same-directory temporary files;
  * restores the backup if installation or restart fails;
  * records the installed release and file hashes in a local state file.

The first successful run adopts the existing installation and installs the
latest stable release. Subsequent runs compare against the updater state, not
against an unreliable filename or timestamp.

.PARAMETER ConfigPath
Path to OpenAITunnelUpdater.json. Defaults to a file next to this script.

.PARAMETER CheckOnly
Checks whether an update or repair is needed without downloading or changing
anything.

.PARAMETER Force
Reinstalls the latest stable release even when the recorded version and hashes
are already current. It does not permit a downgrade.

.PARAMETER AllowUnverifiedAsset
Emergency escape hatch. Permits an asset that has neither a published SHA-256
value nor sufficient trusted OpenAI Authenticode signatures. Invalid signatures
are still rejected. Prefer fixing the release-selection/checksum issue instead.

.EXAMPLE
pwsh -NoProfile -File .\Update-OpenAITunnelClient.ps1 `
  -ConfigPath .\OpenAITunnelUpdater.json -CheckOnly

.EXAMPLE
pwsh -NoProfile -File .\Update-OpenAITunnelClient.ps1 `
  -ConfigPath .\OpenAITunnelUpdater.json
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string] $ConfigPath,

    [Parameter()]
    [switch] $CheckOnly,

    [Parameter()]
    [switch] $Force,

    [Parameter()]
    [switch] $AllowUnverifiedAsset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not $IsWindows) {
    throw 'This updater is intentionally Windows-only.'
}

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:LogFile = $null
$script:VerboseLogging = $false

$RepositoryOwner = 'openai'
$RepositoryName = 'tunnel-client'
$LatestReleaseApi = 'https://api.github.com/repos/openai/tunnel-client/releases/latest'
$OfficialReleasePathPrefix = '/openai/tunnel-client/releases/download/'
$UpdaterUserAgent = 'OpenAI-Tunnel-Client-Updater/1.0'

function Get-OptionalValue {
    param(
        [Parameter(Mandatory)] [object] $Object,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter()] [AllowNull()] [object] $DefaultValue
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function Get-StringSha256 {
    param([Parameter(Mandatory)] [string] $Value)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return [Convert]::ToHexString($algorithm.ComputeHash($bytes)).ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory)] [string] $Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function ConvertTo-AbsolutePath {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $BaseDirectory
    )

    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ([string]::IsNullOrWhiteSpace($expanded)) {
        throw 'A configured path resolved to an empty value.'
    }

    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return [System.IO.Path]::GetFullPath($expanded)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $BaseDirectory -ChildPath $expanded))
}

function Get-SafeChildPath {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [string] $RelativePath
    )

    $relative = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if ([string]::IsNullOrWhiteSpace($relative) -or
        [System.IO.Path]::IsPathRooted($relative) -or
        $relative.Contains(':')) {
        throw "Unsafe relative path: '$RelativePath'."
    }

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $rootPrefix = $rootFull.TrimEnd([char[]]'\/') + [System.IO.Path]::DirectorySeparatorChar
    $candidate = [System.IO.Path]::GetFullPath((Join-Path -Path $rootFull -ChildPath $relative))

    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its managed root: '$RelativePath'."
    }

    return $candidate
}

function ConvertTo-CanonicalRelativePath {
    param([Parameter(Mandatory)] [string] $Path)
    return $Path.Replace('\', '/')
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string] $Level,

        [Parameter(Mandatory)]
        [string] $Message
    )

    $line = '{0} [{1}] {2}' -f ([DateTimeOffset]::UtcNow.ToString('o')), $Level, $Message
    if ($null -ne $script:LogFile) {
        [System.IO.File]::AppendAllText(
            $script:LogFile,
            $line + [Environment]::NewLine,
            $script:Utf8NoBom)
    }

    switch ($Level) {
        'DEBUG' {
            if ($script:VerboseLogging) {
                Write-Host $line
            }
        }
        'WARN'  { Write-Warning $Message }
        'ERROR' { Write-Warning "ERROR: $Message" }
        default { Write-Host $Message }
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)] [scriptblock] $Operation,
        [Parameter(Mandatory)] [string] $Description,
        [int] $Attempts = 3
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return & $Operation
        }
        catch {
            if ($attempt -ge $Attempts) {
                throw
            }

            $delay = [Math]::Min(8, [Math]::Pow(2, $attempt - 1))
            Write-Log -Level 'WARN' -Message (
                "$Description failed (attempt $attempt/$Attempts): $($_.Exception.Message). " +
                "Retrying in $delay second(s).")
            Start-Sleep -Seconds $delay
        }
    }
}

function Assert-OfficialReleaseAssetUrl {
    param([Parameter(Mandatory)] [string] $Url)

    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https' -or
        $uri.Host -ne 'github.com' -or
        -not $uri.AbsolutePath.StartsWith(
            $OfficialReleasePathPrefix,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing non-official release asset URL: $Url"
    }
}

function Test-AllowedDownloadHost {
    param([Parameter(Mandatory)] [Uri] $Uri)

    if ($Uri.Scheme -ne 'https') {
        return $false
    }

    if ($Uri.Host -eq 'github.com') {
        return $true
    }

    return $Uri.Host.EndsWith('.githubusercontent.com', [StringComparison]::OrdinalIgnoreCase)
}

function Save-HttpsFile {
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [long] $MaximumBytes,
        [Parameter(Mandatory)] [string] $Description
    )

    Invoke-WithRetry -Description $Description -Operation {
        if ([System.IO.File]::Exists($Destination)) {
            [System.IO.File]::Delete($Destination)
        }

        $handler = [System.Net.Http.HttpClientHandler]::new()
        $handler.AllowAutoRedirect = $true
        $handler.MaxAutomaticRedirections = 8
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromMinutes(5)
        $client.DefaultRequestHeaders.UserAgent.ParseAdd($UpdaterUserAgent)

        $response = $null
        $input = $null
        $output = $null
        try {
            $response = $client.GetAsync(
                $Uri,
                [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
            ).GetAwaiter().GetResult()

            $response.EnsureSuccessStatusCode()

            $finalUri = $response.RequestMessage.RequestUri
            if (-not (Test-AllowedDownloadHost -Uri $finalUri)) {
                throw "Download redirected to an unexpected host: $finalUri"
            }

            $contentLength = $response.Content.Headers.ContentLength
            if ($null -ne $contentLength -and $contentLength -gt $MaximumBytes) {
                throw "Download is larger than the configured limit ($contentLength bytes)."
            }

            $parent = Split-Path -Parent $Destination
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null

            $input = $response.Content.ReadAsStream()
            $output = [System.IO.FileStream]::new(
                $Destination,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None)

            $buffer = [byte[]]::new(131072)
            [long] $total = 0
            while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $total += $read
                if ($total -gt $MaximumBytes) {
                    throw "Download exceeded the configured limit of $MaximumBytes bytes."
                }
                $output.Write($buffer, 0, $read)
            }

            $output.Flush($true)
        }
        catch {
            if ([System.IO.File]::Exists($Destination)) {
                [System.IO.File]::Delete($Destination)
            }
            throw
        }
        finally {
            if ($null -ne $output) { $output.Dispose() }
            if ($null -ne $input) { $input.Dispose() }
            if ($null -ne $response) { $response.Dispose() }
            $client.Dispose()
            $handler.Dispose()
        }
    } | Out-Null
}

function Get-LatestStableRelease {
    $headers = @{
        'Accept'               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = $UpdaterUserAgent
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)"
    }

    $release = Invoke-WithRetry -Description 'GitHub release query' -Operation {
        Invoke-RestMethod -Method Get -Uri $LatestReleaseApi -Headers $headers
    }

    if ($release.draft -or $release.prerelease) {
        throw 'GitHub returned a draft or prerelease from the stable-release endpoint.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$release.tag_name)) {
        throw 'The latest release has no tag name.'
    }

    $htmlUri = [Uri][string]$release.html_url
    if ($htmlUri.Scheme -ne 'https' -or
        $htmlUri.Host -ne 'github.com' -or
        -not $htmlUri.AbsolutePath.StartsWith(
            '/openai/tunnel-client/releases/tag/',
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The API response did not identify an official openai/tunnel-client release.'
    }

    return $release
}

function Select-WindowsReleaseAsset {
    param(
        [Parameter(Mandatory)] [object] $Release,
        [AllowEmptyString()] [string] $ExplicitAssetName
    )

    $assets = @($Release.assets | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_.name) -and
        -not [string]::IsNullOrWhiteSpace([string]$_.browser_download_url)
    })

    if ($assets.Count -eq 0) {
        throw 'The release contains no downloadable assets.'
    }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitAssetName)) {
        $selected = @($assets | Where-Object {
            [string]$_.name -eq $ExplicitAssetName
        })
        if ($selected.Count -ne 1) {
            $available = ($assets.name | Sort-Object) -join ', '
            throw "Configured asset '$ExplicitAssetName' was not found exactly once. Available: $available"
        }
        if ([string]$selected[0].name -notmatch '(?i)\.zip$') {
            throw 'The configured asset is not a ZIP archive.'
        }
        Assert-OfficialReleaseAssetUrl -Url ([string]$selected[0].browser_download_url)
        return $selected[0]
    }

    $windowsPattern = '(?i)(?:^|[-_.])(windows|win|win32|win64|pc-windows)(?:[-_.]|$)'
    $knownArchitecturePattern = '(?i)(?:^|[-_.])(x86_64|x64|amd64|aarch64|arm64|i386|i686|x86)(?:[-_.]|$)'

    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    $architecturePattern = switch ($architecture) {
        'X64'   { '(?i)(?:^|[-_.])(x86_64|x64|amd64)(?:[-_.]|$)' }
        'Arm64' { '(?i)(?:^|[-_.])(aarch64|arm64)(?:[-_.]|$)' }
        'X86'   { '(?i)(?:^|[-_.])(i386|i686|x86)(?:[-_.]|$)' }
        default { throw "Unsupported Windows architecture: $architecture" }
    }

    $zipAssets = @($assets | Where-Object { [string]$_.name -match '(?i)\.zip$' })

    # Releases may publish the primary tunnel-client, the runtime-only binary,
    # and a cloudflared-flavoured runtime for the same Windows architecture.
    # Only the primary client carries the command surface TunnelTend manages.
    # Prefer its exact release-family name and fail closed if that family is
    # ambiguous instead of selecting another executable by accident.
    $primaryClientMatches = @($zipAssets | Where-Object {
        [string]$_.name -match '(?i)^tunnel-client-v[^/]+-' -and
        [string]$_.name -match $windowsPattern -and
        [string]$_.name -match $architecturePattern
    })

    $selected = $null
    if ($primaryClientMatches.Count -eq 1) {
        $selected = $primaryClientMatches[0]
    }
    elseif ($primaryClientMatches.Count -gt 1) {
        $names = ($primaryClientMatches.name | Sort-Object) -join ', '
        throw "More than one primary tunnel-client Windows/$architecture ZIP matched: $names. Configure assetName explicitly."
    }
    else {
        $architectureMatches = @($zipAssets | Where-Object {
            [string]$_.name -match $windowsPattern -and
            [string]$_.name -match $architecturePattern -and
            [string]$_.name -notmatch '(?i)(?:^|[-_.])(runtime|cloudflared)(?:[-_.]|$)'
        })

        if ($architectureMatches.Count -eq 1) {
            $selected = $architectureMatches[0]
        }
        elseif ($architectureMatches.Count -gt 1) {
            $names = ($architectureMatches.name | Sort-Object) -join ', '
            throw "More than one primary Windows/$architecture ZIP matched: $names. Configure assetName explicitly."
        }
        else {
            $genericWindowsAssets = @($zipAssets | Where-Object {
                [string]$_.name -match $windowsPattern -and
                [string]$_.name -notmatch $knownArchitecturePattern -and
                [string]$_.name -notmatch '(?i)(?:^|[-_.])(runtime|cloudflared)(?:[-_.]|$)'
            })

            if ($genericWindowsAssets.Count -eq 1) {
                $selected = $genericWindowsAssets[0]
            }
            else {
                $names = ($zipAssets.name | Sort-Object) -join ', '
                throw "Could not select exactly one primary tunnel-client Windows/$architecture ZIP. ZIP assets: $names. Configure assetName explicitly."
            }
        }
    }

    Assert-OfficialReleaseAssetUrl -Url ([string]$selected.browser_download_url)
    return $selected
}

function Convert-ReleaseTagToVersion {
    param([Parameter(Mandatory)] [string] $Tag)

    $clean = $Tag.Trim() -replace '^[vV]', ''
    $core = ($clean -split '-', 2)[0]
    try {
        return [version]::Parse($core)
    }
    catch {
        return $null
    }
}

function Find-Sha256InChecksumText {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $TargetFileName,
        [bool] $AllowBareHash
    )

    foreach ($rawLine in ($Text -split "`r?`n")) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match '^(?<hash>[a-fA-F0-9]{64})\s+[*]?(?<name>.+?)\s*$') {
            $listedName = [System.IO.Path]::GetFileName($Matches['name'].Trim())
            if ($listedName -eq $TargetFileName) {
                return $Matches['hash'].ToLowerInvariant()
            }
        }

        if ($line -match '^SHA256\s*\((?<name>.+?)\)\s*=\s*(?<hash>[a-fA-F0-9]{64})$') {
            $listedName = [System.IO.Path]::GetFileName($Matches['name'].Trim())
            if ($listedName -eq $TargetFileName) {
                return $Matches['hash'].ToLowerInvariant()
            }
        }
    }

    if ($AllowBareHash -and $Text.Trim() -match '^[a-fA-F0-9]{64}$') {
        return $Text.Trim().ToLowerInvariant()
    }

    return $null
}

function Get-PublishedArchiveSha256 {
    param(
        [Parameter(Mandatory)] [object] $Release,
        [Parameter(Mandatory)] [object] $Asset,
        [Parameter(Mandatory)] [string] $StagingDirectory
    )

    $digestProperty = $Asset.PSObject.Properties['digest']
    if ($null -ne $digestProperty -and
        -not [string]::IsNullOrWhiteSpace([string]$digestProperty.Value)) {
        $digest = [string]$digestProperty.Value
        if ($digest -match '^(?i)sha256:(?<hash>[a-f0-9]{64})$') {
            return [pscustomobject]@{
                Hash   = $Matches['hash'].ToLowerInvariant()
                Source = 'GitHub release-asset digest'
            }
        }
        throw "The release asset advertises an unsupported digest format: '$digest'."
    }

    $assetName = [string]$Asset.name
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($assetName)
    $allAssets = @($Release.assets)

    $checksumCandidates = @($allAssets | Where-Object {
        $name = [string]$_.name
        $name -eq "$assetName.sha256" -or
        $name -eq "$baseName.sha256" -or
        $name -match '(?i)^(sha256sums|sha256sum|checksums?|hashes)(\.[^.]+)?$' -or
        $name -match '(?i)(sha256|checksum).*(\.txt|\.sum|\.sha256)$'
    } | Sort-Object -Property @{ Expression = {
        $name = [string]$_.name
        if ($name -eq "$assetName.sha256") { 0 }
        elseif ($name -eq "$baseName.sha256") { 1 }
        else { 2 }
    }}, @{ Expression = { [string]$_.name } })

    foreach ($checksumAsset in $checksumCandidates) {
        Assert-OfficialReleaseAssetUrl -Url ([string]$checksumAsset.browser_download_url)
        $checksumPath = Join-Path $StagingDirectory ([System.IO.Path]::GetFileName([string]$checksumAsset.name))
        Save-HttpsFile `
            -Uri ([string]$checksumAsset.browser_download_url) `
            -Destination $checksumPath `
            -MaximumBytes 4194304 `
            -Description "Checksum download '$($checksumAsset.name)'"

        $text = [System.IO.File]::ReadAllText($checksumPath)
        $isPerAssetFile = ([string]$checksumAsset.name -eq "$assetName.sha256") -or
                          ([string]$checksumAsset.name -eq "$baseName.sha256")
        $hash = Find-Sha256InChecksumText `
            -Text $text `
            -TargetFileName $assetName `
            -AllowBareHash $isPerAssetFile

        if ($null -ne $hash) {
            return [pscustomobject]@{
                Hash   = $hash
                Source = "release checksum asset '$($checksumAsset.name)'"
            }
        }
    }

    return $null
}

function Expand-ZipSafely {
    param(
        [Parameter(Mandatory)] [string] $ArchivePath,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [long] $MaximumExtractedBytes,
        [Parameter(Mandatory)] [int] $MaximumEntries
    )

    Add-Type -AssemblyName System.IO.Compression
    [System.IO.Directory]::CreateDirectory($Destination) | Out-Null

    $root = [System.IO.Path]::GetFullPath($Destination)
    $rootPrefix = $root.TrimEnd([char[]]'\/') + [System.IO.Path]::DirectorySeparatorChar
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

    try {
        if ($archive.Entries.Count -gt $MaximumEntries) {
            throw "ZIP contains $($archive.Entries.Count) entries; limit is $MaximumEntries."
        }

        [long] $declaredTotal = 0
        foreach ($entry in $archive.Entries) {
            $declaredTotal += [long]$entry.Length
            if ($declaredTotal -gt $MaximumExtractedBytes) {
                throw "ZIP declares more than $MaximumExtractedBytes extracted bytes."
            }
        }

        [long] $actualTotal = 0
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ([string]::IsNullOrWhiteSpace($name)) { continue }

            if ($name.StartsWith('/') -or
                $name.Contains(':') -or
                ($name -split '/') -contains '..') {
                throw "ZIP contains an unsafe path: '$name'."
            }

            # Reject Unix symbolic links. On Windows they would otherwise become
            # confusing payload files rather than trustworthy regular files.
            # ExternalAttributes is a signed Int32; regular Unix files commonly
            # set its sign bit. Shift and mask without a checked UInt32 cast.
            $unixType = (($entry.ExternalAttributes -shr 16) -band 0xF000)
            if ($unixType -eq 0xA000) {
                throw "ZIP contains a symbolic link: '$name'."
            }

            $relative = $name.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $target = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
            if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "ZIP entry escapes the extraction root: '$name'."
            }

            if ($name.EndsWith('/')) {
                [System.IO.Directory]::CreateDirectory($target) | Out-Null
                continue
            }

            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
            $input = $entry.Open()
            $output = $null
            try {
                $output = [System.IO.FileStream]::new(
                    $target,
                    [System.IO.FileMode]::CreateNew,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None)

                $buffer = [byte[]]::new(131072)
                while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $actualTotal += $read
                    if ($actualTotal -gt $MaximumExtractedBytes) {
                        throw "ZIP extraction exceeded the $MaximumExtractedBytes-byte limit."
                    }
                    $output.Write($buffer, 0, $read)
                }
                $output.Flush($true)
            }
            finally {
                if ($null -ne $output) { $output.Dispose() }
                $input.Dispose()
            }

            try {
                [System.IO.File]::SetLastWriteTimeUtc($target, $entry.LastWriteTime.UtcDateTime)
            }
            catch {
                Write-Log -Level 'DEBUG' -Message "Could not preserve ZIP timestamp for '$name'."
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Get-PayloadRoot {
    param([Parameter(Mandatory)] [string] $ExtractionRoot)

    $children = @(Get-ChildItem -LiteralPath $ExtractionRoot -Force)
    $files = @($children | Where-Object { -not $_.PSIsContainer })
    $directories = @($children | Where-Object { $_.PSIsContainer })

    if ($files.Count -eq 0 -and $directories.Count -eq 1) {
        return $directories[0].FullName
    }

    return $ExtractionRoot
}

function Get-PayloadManifest {
    param([Parameter(Mandatory)] [string] $PayloadRoot)

    $files = @(Get-ChildItem -LiteralPath $PayloadRoot -File -Recurse -Force)
    if ($files.Count -eq 0) {
        throw 'The release archive contains no files.'
    }

    $manifest = foreach ($file in $files) {
        $relative = [System.IO.Path]::GetRelativePath($PayloadRoot, $file.FullName)
        [pscustomobject]@{
            RelativePath = ConvertTo-CanonicalRelativePath -Path $relative
            SourcePath   = $file.FullName
            Length       = [long]$file.Length
            Sha256       = Get-FileSha256 -Path $file.FullName
        }
    }

    return @($manifest | Sort-Object RelativePath)
}

function Resolve-ExecutableRelativePath {
    param(
        [Parameter(Mandatory)] [object[]] $PayloadManifest,
        [AllowEmptyString()] [string] $ConfiguredRelativePath,
        [AllowNull()] [object] $PreviousState
    )

    $executables = @($PayloadManifest | Where-Object {
        [System.IO.Path]::GetExtension($_.RelativePath) -eq '.exe'
    })

    if ($executables.Count -eq 0) {
        throw 'The selected Windows release archive contains no .exe file.'
    }

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredRelativePath)) {
        $wanted = ConvertTo-CanonicalRelativePath -Path $ConfiguredRelativePath.TrimStart([char[]]'\/')
        $matches = @($executables | Where-Object {
            $_.RelativePath -eq $wanted
        })
        if ($matches.Count -ne 1) {
            $available = ($executables.RelativePath | Sort-Object) -join ', '
            throw "Configured executableRelativePath '$wanted' does not match exactly one payload executable. Available: $available"
        }
        return $matches[0].RelativePath
    }

    if ($null -ne $PreviousState) {
        $oldPath = [string](Get-OptionalValue -Object $PreviousState -Name 'executableRelativePath' -DefaultValue '')
        if (-not [string]::IsNullOrWhiteSpace($oldPath)) {
            $oldMatches = @($executables | Where-Object { $_.RelativePath -eq $oldPath })
            if ($oldMatches.Count -eq 1) {
                return $oldMatches[0].RelativePath
            }
        }
    }

    if ($executables.Count -eq 1) {
        return $executables[0].RelativePath
    }

    $tunnelMatches = @($executables | Where-Object {
        [System.IO.Path]::GetFileNameWithoutExtension($_.RelativePath) -match '(?i)tunnel'
    })
    if ($tunnelMatches.Count -eq 1) {
        return $tunnelMatches[0].RelativePath
    }

    $available = ($executables.RelativePath | Sort-Object) -join ', '
    throw "The archive contains multiple executable candidates: $available. Configure executableRelativePath explicitly."
}

function Test-PayloadCodeSignatures {
    param(
        [Parameter(Mandatory)] [object[]] $PayloadManifest,
        [Parameter(Mandatory)] [string] $ExecutableRelativePath
    )

    $codeFiles = @($PayloadManifest | Where-Object {
        [System.IO.Path]::GetExtension($_.RelativePath) -in @('.exe', '.dll', '.sys')
    })

    $allCodeFilesValid = $codeFiles.Count -gt 0
    $mainExecutableIsOpenAI = $false
    $signers = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $codeFiles) {
        $signature = Get-AuthenticodeSignature -LiteralPath $file.SourcePath
        switch ([string]$signature.Status) {
            'Valid' {
                $subject = [string]$signature.SignerCertificate.Subject
                if (-not [string]::IsNullOrWhiteSpace($subject)) {
                    [void]$signers.Add($subject)
                }
                if ($file.RelativePath -eq $ExecutableRelativePath -and
                    $subject -match '(?i)\bOpenAI\b') {
                    $mainExecutableIsOpenAI = $true
                }
            }
            'NotSigned' {
                $allCodeFilesValid = $false
            }
            default {
                throw "Code file '$($file.RelativePath)' has invalid Authenticode status '$($signature.Status)': $($signature.StatusMessage)"
            }
        }
    }

    return [pscustomobject]@{
        AllCodeFilesValid      = $allCodeFilesValid
        MainExecutableIsOpenAI = $mainExecutableIsOpenAI
        Signers                = @($signers)
    }
}

function Read-StateFile {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not [System.IO.File]::Exists($Path)) {
        return $null
    }

    try {
        $state = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json -Depth 20
        if ([int](Get-OptionalValue -Object $state -Name 'schemaVersion' -DefaultValue 0) -ne 1) {
            throw 'Unsupported state schema.'
        }
        return $state
    }
    catch {
        throw "Could not read updater state '$Path': $($_.Exception.Message)"
    }
}

function Test-ManagedInstallation {
    param(
        [AllowNull()] [object] $State,
        [Parameter(Mandatory)] [string] $InstallDirectory
    )

    if ($null -eq $State) {
        return $false
    }

    $managedFiles = @(Get-OptionalValue -Object $State -Name 'managedFiles' -DefaultValue @())
    if ($managedFiles.Count -eq 0) {
        return $false
    }

    foreach ($record in $managedFiles) {
        $relative = [string]$record.relativePath
        $expectedHash = [string]$record.sha256
        $path = Get-SafeChildPath -Root $InstallDirectory -RelativePath $relative
        if (-not [System.IO.File]::Exists($path)) {
            Write-Log -Level 'WARN' -Message "Managed file is missing: '$relative'."
            return $false
        }

        if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
            $actualHash = Get-FileSha256 -Path $path
            if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
                Write-Log -Level 'WARN' -Message "Managed file hash differs: '$relative'."
                return $false
            }
        }
    }

    return $true
}

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [object] $Value
    )

    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = "$Path.new-$PID-$([Guid]::NewGuid().ToString('N'))"
    $json = $Value | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($temporary, $json, $script:Utf8NoBom)

    try {
        if ([System.IO.File]::Exists($Path)) {
            try {
                [System.IO.File]::Replace($temporary, $Path, $null, $true)
            }
            catch {
                Move-Item -LiteralPath $temporary -Destination $Path -Force
            }
        }
        else {
            [System.IO.File]::Move($temporary, $Path)
        }
    }
    finally {
        if ([System.IO.File]::Exists($temporary)) {
            [System.IO.File]::Delete($temporary)
        }
    }
}

function Assert-InstallDirectoryWritable {
    param([Parameter(Mandatory)] [string] $InstallDirectory)

    [System.IO.Directory]::CreateDirectory($InstallDirectory) | Out-Null
    $probe = Join-Path $InstallDirectory ('.updater-write-test-' + [Guid]::NewGuid().ToString('N'))
    try {
        [System.IO.File]::WriteAllText($probe, 'test', $script:Utf8NoBom)
    }
    catch {
        throw "Install directory is not writable: '$InstallDirectory'. Run the updater with suitable rights or move the client. $($_.Exception.Message)"
    }
    finally {
        if ([System.IO.File]::Exists($probe)) {
            [System.IO.File]::Delete($probe)
        }
    }
}

if (-not ('OpenAITunnelUpdater.NativeCommandLine' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace OpenAITunnelUpdater
{
    internal static class NativeCommandLine
    {
        [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr CommandLineToArgvW(string commandLine, out int argumentCount);

        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr memory);

        internal static string[] Split(string commandLine)
        {
            if (String.IsNullOrWhiteSpace(commandLine))
                return Array.Empty<string>();

            IntPtr pointer = CommandLineToArgvW(commandLine, out int count);
            if (pointer == IntPtr.Zero)
                throw new Win32Exception(Marshal.GetLastWin32Error());

            try
            {
                var result = new string[count];
                for (int i = 0; i < count; i++)
                {
                    IntPtr item = Marshal.ReadIntPtr(pointer, i * IntPtr.Size);
                    result[i] = Marshal.PtrToStringUni(item) ?? String.Empty;
                }
                return result;
            }
            finally
            {
                LocalFree(pointer);
            }
        }
    }
}
'@
}

function Get-ProcessesByExecutablePath {
    param([Parameter(Mandatory)] [string[]] $ExecutablePaths)

    $targets = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $ExecutablePaths) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$targets.Add([System.IO.Path]::GetFullPath($path))
        }
    }

    $fileNames = @($targets | ForEach-Object { [System.IO.Path]::GetFileName($_) } | Sort-Object -Unique)
    $results = @()

    foreach ($fileName in $fileNames) {
        $escapedName = $fileName.Replace("'", "''")
        $candidates = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = '$escapedName'" -ErrorAction Stop)
        foreach ($candidate in $candidates) {
            $executablePath = [string]$candidate.ExecutablePath
            if ([string]::IsNullOrWhiteSpace($executablePath)) {
                try {
                    $executablePath = [string](Get-Process -Id ([int]$candidate.ProcessId) -ErrorAction Stop).Path
                }
                catch {
                    continue
                }
            }

            try {
                $fullPath = [System.IO.Path]::GetFullPath($executablePath)
            }
            catch {
                continue
            }

            if ($targets.Contains($fullPath)) {
                $results += [pscustomobject]@{
                    ProcessId     = [int]$candidate.ProcessId
                    ExecutablePath = $fullPath
                    CommandLine    = [string]$candidate.CommandLine
                }
            }
        }
    }

    return @($results | Sort-Object ProcessId -Unique)
}

function Get-ScheduledTaskIdentity {
    param([Parameter(Mandatory)] [string] $FullName)

    $normalized = $FullName.Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw 'Scheduled task name is empty.'
    }

    $lastSlash = $normalized.LastIndexOf('\')
    if ($lastSlash -lt 0) {
        return [pscustomobject]@{ TaskPath = '\'; TaskName = $normalized }
    }

    $taskName = $normalized.Substring($lastSlash + 1)
    $taskPath = $normalized.Substring(0, $lastSlash + 1)
    if ([string]::IsNullOrWhiteSpace($taskName)) {
        throw "Invalid scheduled task name: '$FullName'."
    }
    if ([string]::IsNullOrWhiteSpace($taskPath)) {
        $taskPath = '\'
    }
    elseif (-not $taskPath.StartsWith('\')) {
        $taskPath = '\' + $taskPath
    }

    return [pscustomobject]@{ TaskPath = $taskPath; TaskName = $taskName }
}

function Get-ClientManagerState {
    param(
        [AllowEmptyString()] [string] $TaskFullName,
        [AllowEmptyString()] [string] $ServiceName
    )

    if (-not [string]::IsNullOrWhiteSpace($TaskFullName) -and
        -not [string]::IsNullOrWhiteSpace($ServiceName)) {
        throw 'Configure either clientScheduledTaskName or clientServiceName, not both.'
    }

    if (-not [string]::IsNullOrWhiteSpace($TaskFullName)) {
        $identity = Get-ScheduledTaskIdentity -FullName $TaskFullName
        $task = Get-ScheduledTask -TaskPath $identity.TaskPath -TaskName $identity.TaskName
        return [pscustomobject]@{
            Type       = 'Task'
            WasActive  = ([string]$task.State -eq 'Running')
            TaskPath   = $identity.TaskPath
            TaskName   = $identity.TaskName
            ServiceName = $null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ServiceName)) {
        $service = Get-Service -Name $ServiceName
        return [pscustomobject]@{
            Type        = 'Service'
            WasActive   = ([string]$service.Status -eq 'Running')
            TaskPath    = $null
            TaskName    = $null
            ServiceName = $ServiceName
        }
    }

    return [pscustomobject]@{
        Type        = 'None'
        WasActive   = $false
        TaskPath    = $null
        TaskName    = $null
        ServiceName = $null
    }
}

function Stop-Manager {
    param([Parameter(Mandatory)] [object] $Manager)

    switch ($Manager.Type) {
        'Task' {
            $task = Get-ScheduledTask -TaskPath $Manager.TaskPath -TaskName $Manager.TaskName
            if ([string]$task.State -eq 'Running') {
                Stop-ScheduledTask -TaskPath $Manager.TaskPath -TaskName $Manager.TaskName
            }
        }
        'Service' {
            $service = Get-Service -Name $Manager.ServiceName
            if ([string]$service.Status -ne 'Stopped') {
                Stop-Service -Name $Manager.ServiceName
                $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
            }
        }
    }
}

function Stop-ExactClientProcesses {
    param(
        [Parameter(Mandatory)] [string[]] $ExecutablePaths,
        [Parameter(Mandatory)] [int] $TimeoutSeconds
    )

    $processes = @(Get-ProcessesByExecutablePath -ExecutablePaths $ExecutablePaths)
    foreach ($snapshot in $processes) {
        try {
            $process = Get-Process -Id $snapshot.ProcessId -ErrorAction Stop
            if ($process.MainWindowHandle -ne 0) {
                [void]$process.CloseMainWindow()
            }
        }
        catch {
            # The process may already have exited.
        }
    }

    $graceDeadline = [DateTime]::UtcNow.AddSeconds([Math]::Min(5, $TimeoutSeconds))
    do {
        $remaining = @(Get-ProcessesByExecutablePath -ExecutablePaths $ExecutablePaths)
        if ($remaining.Count -eq 0) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $graceDeadline)

    foreach ($snapshot in $remaining) {
        try {
            Stop-Process -Id $snapshot.ProcessId -Force -ErrorAction Stop
        }
        catch {
            if (Get-Process -Id $snapshot.ProcessId -ErrorAction SilentlyContinue) {
                throw
            }
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $remaining = @(Get-ProcessesByExecutablePath -ExecutablePaths $ExecutablePaths)
        if ($remaining.Count -eq 0) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)

    $ids = ($remaining.ProcessId -join ', ')
    throw "Client process(es) did not stop or were immediately respawned: $ids"
}

function Prepare-ClientForUpdate {
    param(
        [Parameter(Mandatory)] [string[]] $ExecutablePaths,
        [Parameter(Mandatory)] [string] $NewExecutablePath,
        [Parameter(Mandatory)] [ValidateSet('Defer', 'Restart', 'Stop')] [string] $Policy,
        [AllowEmptyString()] [string] $TaskFullName,
        [AllowEmptyString()] [string] $ServiceName,
        [AllowNull()] [object] $ConfiguredRestartArguments,
        [Parameter(Mandatory)] [bool] $RestartArgumentsWereConfigured,
        [Parameter(Mandatory)] [string] $RestartWorkingDirectory,
        [Parameter(Mandatory)] [int] $StopTimeoutSeconds
    )

    $manager = Get-ClientManagerState -TaskFullName $TaskFullName -ServiceName $ServiceName
    $processes = @(Get-ProcessesByExecutablePath -ExecutablePaths $ExecutablePaths)
    $anythingActive = $manager.WasActive -or $processes.Count -gt 0

    if ($Policy -eq 'Defer' -and $anythingActive) {
        return [pscustomobject]@{
            Deferred      = $true
            ShouldRestart = $false
            Manager       = $manager
            DirectStarts  = @()
        }
    }

    $directStarts = @()
    if ($Policy -eq 'Restart' -and $manager.Type -eq 'None') {
        foreach ($process in $processes) {
            $arguments = @()
            if ($RestartArgumentsWereConfigured) {
                $arguments = @($ConfiguredRestartArguments | ForEach-Object { [string]$_ })
            }
            else {
                if ([string]::IsNullOrWhiteSpace($process.CommandLine)) {
                    throw 'Cannot capture the running client command line. Configure restartArguments or manage the client through a scheduled task/service.'
                }

                $parts = [OpenAITunnelUpdater.NativeCommandLine]::Split($process.CommandLine)
                if ($parts.Count -eq 0) {
                    throw 'Cannot parse the running client command line.'
                }
                if ($parts.Count -gt 1) {
                    $arguments = @($parts[1..($parts.Count - 1)])
                }
            }

            $directStarts += [pscustomobject]@{
                Arguments             = $arguments
                WorkingDirectory      = $RestartWorkingDirectory
                OriginalExecutablePath = $process.ExecutablePath
            }
        }
    }

    $context = [pscustomobject]@{
        Deferred      = $false
        ShouldRestart = ($Policy -eq 'Restart' -and $anythingActive)
        Manager       = $manager
        DirectStarts  = $directStarts
        NewExecutable = $NewExecutablePath
    }

    try {
        if ($manager.Type -ne 'None' -and $anythingActive) {
            Stop-Manager -Manager $manager
        }
        if ($processes.Count -gt 0 -or $manager.WasActive) {
            Stop-ExactClientProcesses -ExecutablePaths $ExecutablePaths -TimeoutSeconds $StopTimeoutSeconds
        }
        return $context
    }
    catch {
        if ($context.ShouldRestart) {
            try {
                switch ($manager.Type) {
                    'Task' {
                        if ($manager.WasActive) {
                            Start-ScheduledTask -TaskPath $manager.TaskPath -TaskName $manager.TaskName
                        }
                    }
                    'Service' {
                        if ($manager.WasActive) {
                            Start-Service -Name $manager.ServiceName
                        }
                    }
                    default {
                        $stillRunning = @(Get-ProcessesByExecutablePath -ExecutablePaths $ExecutablePaths)
                        if ($stillRunning.Count -eq 0) {
                            foreach ($start in $directStarts) {
                                [void](Start-DirectProcess `
                                    -ExecutablePath $start.OriginalExecutablePath `
                                    -Arguments @($start.Arguments) `
                                    -WorkingDirectory $start.WorkingDirectory)
                            }
                        }
                    }
                }
            }
            catch {
                Write-Log -Level 'ERROR' -Message 'Client could not be resumed after a failed stop attempt.'
            }
        }
        throw
    }
}

function Start-DirectProcess {
    param(
        [Parameter(Mandatory)] [string] $ExecutablePath,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string] $WorkingDirectory
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ExecutablePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    return [System.Diagnostics.Process]::Start($startInfo)
}

function Resume-Client {
    param(
        [Parameter(Mandatory)] [object] $Context,
        [Parameter(Mandatory)] [int] $ObservationSeconds
    )

    if (-not $Context.ShouldRestart) {
        return
    }

    switch ($Context.Manager.Type) {
        'Task' {
            Start-ScheduledTask -TaskPath $Context.Manager.TaskPath -TaskName $Context.Manager.TaskName
            $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(1, $ObservationSeconds))
            do {
                $task = Get-ScheduledTask -TaskPath $Context.Manager.TaskPath -TaskName $Context.Manager.TaskName
                if ([string]$task.State -eq 'Running') { return }
                Start-Sleep -Milliseconds 250
            } while ([DateTime]::UtcNow -lt $deadline)
            throw 'The client scheduled task did not remain running after restart.'
        }
        'Service' {
            Start-Service -Name $Context.Manager.ServiceName
            $service = Get-Service -Name $Context.Manager.ServiceName
            $service.WaitForStatus('Running', [TimeSpan]::FromSeconds([Math]::Max(5, $ObservationSeconds)))
            return
        }
        default {
            $started = @()
            foreach ($start in $Context.DirectStarts) {
                $started += Start-DirectProcess `
                    -ExecutablePath $Context.NewExecutable `
                    -Arguments @($start.Arguments) `
                    -WorkingDirectory $start.WorkingDirectory
            }

            if ($ObservationSeconds -gt 0) {
                Start-Sleep -Seconds $ObservationSeconds
                $exited = @($started | Where-Object { $_.HasExited })
                if ($exited.Count -gt 0) {
                    throw 'A directly restarted client process exited during the restart observation window.'
                }
            }
        }
    }
}

function Stop-ClientForRollback {
    param(
        [Parameter(Mandatory)] [object] $Context,
        [Parameter(Mandatory)] [string[]] $ExecutablePaths,
        [Parameter(Mandatory)] [int] $TimeoutSeconds
    )

    try {
        Stop-Manager -Manager $Context.Manager
    }
    catch {
        Write-Log -Level 'WARN' -Message "Could not stop the client manager during rollback: $($_.Exception.Message)"
    }

    try {
        Stop-ExactClientProcesses -ExecutablePaths $ExecutablePaths -TimeoutSeconds $TimeoutSeconds
    }
    catch {
        Write-Log -Level 'WARN' -Message "Could not stop all client processes during rollback: $($_.Exception.Message)"
    }
}

function New-Backup {
    param(
        [Parameter(Mandatory)] [string] $BackupRoot,
        [Parameter(Mandatory)] [string] $InstallDirectory,
        [Parameter(Mandatory)] [object[]] $NewManifest,
        [AllowNull()] [object] $PreviousState
    )

    $oldTag = if ($null -ne $PreviousState) {
        [string](Get-OptionalValue -Object $PreviousState -Name 'installedTag' -DefaultValue 'unknown')
    }
    else {
        'unmanaged'
    }
    $safeTag = $oldTag -replace '[^A-Za-z0-9_.-]', '_'
    $directory = Join-Path $BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $safeTag)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null

    $paths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $NewManifest) {
        [void]$paths.Add([string]$file.RelativePath)
    }

    if ($null -ne $PreviousState) {
        foreach ($record in @(Get-OptionalValue -Object $PreviousState -Name 'managedFiles' -DefaultValue @())) {
            [void]$paths.Add([string]$record.relativePath)
        }
    }

    $records = @()
    foreach ($relative in ($paths | Sort-Object)) {
        $destination = Get-SafeChildPath -Root $InstallDirectory -RelativePath $relative
        $exists = [System.IO.File]::Exists($destination)
        $attributes = $null
        if ($exists) {
            $backupFile = Get-SafeChildPath -Root $directory -RelativePath $relative
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backupFile)) | Out-Null
            [System.IO.File]::Copy($destination, $backupFile, $true)
            $attributes = [int](Get-Item -LiteralPath $destination -Force).Attributes
        }

        $records += [pscustomobject]@{
            relativePath = $relative
            existed      = $exists
            attributes   = $attributes
        }
    }

    $manifestPath = Join-Path $directory 'backup-manifest.json'
    Write-JsonAtomically -Path $manifestPath -Value ([ordered]@{
        schemaVersion = 1
        createdAtUtc  = [DateTimeOffset]::UtcNow.ToString('o')
        files         = $records
    })

    return [pscustomobject]@{
        Directory = $directory
        Manifest  = $records
    }
}

function Copy-FileAtomically {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Destination
    )

    $parent = Split-Path -Parent $Destination
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Destination) + '.new-' + [Guid]::NewGuid().ToString('N'))
    [System.IO.File]::Copy($Source, $temporary, $false)

    try {
        if ([System.IO.File]::Exists($Destination)) {
            $item = Get-Item -LiteralPath $Destination -Force
            if ($item.IsReadOnly) { $item.IsReadOnly = $false }

            try {
                [System.IO.File]::Replace($temporary, $Destination, $null, $true)
            }
            catch {
                $oldTemporary = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Destination) + '.old-' + [Guid]::NewGuid().ToString('N'))
                [System.IO.File]::Move($Destination, $oldTemporary)
                try {
                    [System.IO.File]::Move($temporary, $Destination)
                    [System.IO.File]::Delete($oldTemporary)
                }
                catch {
                    if ([System.IO.File]::Exists($Destination)) {
                        [System.IO.File]::Delete($Destination)
                    }
                    if ([System.IO.File]::Exists($oldTemporary)) {
                        [System.IO.File]::Move($oldTemporary, $Destination)
                    }
                    throw
                }
            }
        }
        else {
            [System.IO.File]::Move($temporary, $Destination)
        }
    }
    finally {
        if ([System.IO.File]::Exists($temporary)) {
            [System.IO.File]::Delete($temporary)
        }
    }
}

function Install-Payload {
    param(
        [Parameter(Mandatory)] [object[]] $PayloadManifest,
        [Parameter(Mandatory)] [string] $InstallDirectory,
        [AllowNull()] [object] $PreviousState
    )

    $newPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $PayloadManifest) {
        [void]$newPaths.Add([string]$file.RelativePath)
        $destination = Get-SafeChildPath -Root $InstallDirectory -RelativePath $file.RelativePath
        Copy-FileAtomically -Source $file.SourcePath -Destination $destination

        $actualHash = Get-FileSha256 -Path $destination
        if ($actualHash -ne $file.Sha256) {
            throw "Post-install hash mismatch for '$($file.RelativePath)'."
        }
    }

    if ($null -ne $PreviousState) {
        foreach ($oldFile in @(Get-OptionalValue -Object $PreviousState -Name 'managedFiles' -DefaultValue @())) {
            $oldRelative = [string]$oldFile.relativePath
            if (-not $newPaths.Contains($oldRelative)) {
                $oldPath = Get-SafeChildPath -Root $InstallDirectory -RelativePath $oldRelative
                if ([System.IO.File]::Exists($oldPath)) {
                    [System.IO.File]::Delete($oldPath)
                }
            }
        }
    }
}

function Restore-Backup {
    param(
        [Parameter(Mandatory)] [object] $Backup,
        [Parameter(Mandatory)] [string] $InstallDirectory
    )

    foreach ($record in $Backup.Manifest) {
        $destination = Get-SafeChildPath -Root $InstallDirectory -RelativePath ([string]$record.relativePath)
        if ([bool]$record.existed) {
            $source = Get-SafeChildPath -Root $Backup.Directory -RelativePath ([string]$record.relativePath)
            Copy-FileAtomically -Source $source -Destination $destination
            if ($null -ne $record.attributes) {
                (Get-Item -LiteralPath $destination -Force).Attributes = [System.IO.FileAttributes][int]$record.attributes
            }
        }
        elseif ([System.IO.File]::Exists($destination)) {
            [System.IO.File]::Delete($destination)
        }
    }
}

function Remove-OldDirectories {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [int] $Keep
    )

    if (-not [System.IO.Directory]::Exists($Root)) { return }
    $directories = @(Get-ChildItem -LiteralPath $Root -Directory | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($directory in @($directories | Select-Object -Skip $Keep)) {
        try {
            Remove-Item -LiteralPath $directory.FullName -Recurse -Force
        }
        catch {
            Write-Log -Level 'WARN' -Message "Could not remove old directory '$($directory.FullName)': $($_.Exception.Message)"
        }
    }
}

function Remove-OldLogs {
    param(
        [Parameter(Mandatory)] [string] $LogDirectory,
        [int] $Keep = 20
    )

    if (-not [System.IO.Directory]::Exists($LogDirectory)) { return }
    $logs = @(Get-ChildItem -LiteralPath $LogDirectory -File -Filter '*.log' | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($log in @($logs | Select-Object -Skip $Keep)) {
        try { Remove-Item -LiteralPath $log.FullName -Force }
        catch { }
    }
}

function Invoke-Updater {
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $script:ConfigPath = Join-Path $PSScriptRoot 'OpenAITunnelUpdater.json'
    }
    else {
        $script:ConfigPath = $ConfigPath
    }

    $script:ConfigPath = [System.IO.Path]::GetFullPath($script:ConfigPath)
    if (-not [System.IO.File]::Exists($script:ConfigPath)) {
        throw "Configuration file not found: '$script:ConfigPath'."
    }

    $configDirectory = Split-Path -Parent $script:ConfigPath
    $config = [System.IO.File]::ReadAllText($script:ConfigPath) | ConvertFrom-Json -Depth 20

    $installSetting = [string](Get-OptionalValue -Object $config -Name 'installDirectory' -DefaultValue '')
    if ([string]::IsNullOrWhiteSpace($installSetting)) {
        throw 'installDirectory must be configured.'
    }
    $installDirectory = ConvertTo-AbsolutePath -Path $installSetting -BaseDirectory $configDirectory

    $configuredExecutable = [string](Get-OptionalValue -Object $config -Name 'executableRelativePath' -DefaultValue '')
    $explicitAssetName = [string](Get-OptionalValue -Object $config -Name 'assetName' -DefaultValue '')
    $policyRaw = [string](Get-OptionalValue -Object $config -Name 'runningProcessPolicy' -DefaultValue 'Defer')
    $policy = switch -Regex ($policyRaw.Trim()) {
        '^(?i)defer$'   { 'Defer'; break }
        '^(?i)restart$' { 'Restart'; break }
        '^(?i)stop$'    { 'Stop'; break }
        default { throw "Invalid runningProcessPolicy '$policyRaw'. Use Defer, Restart, or Stop." }
    }

    $clientTaskName = [string](Get-OptionalValue -Object $config -Name 'clientScheduledTaskName' -DefaultValue '')
    $clientServiceName = [string](Get-OptionalValue -Object $config -Name 'clientServiceName' -DefaultValue '')

    $restartProperty = $config.PSObject.Properties['restartArguments']
    $restartArgumentsWereConfigured = $null -ne $restartProperty -and $null -ne $restartProperty.Value
    $configuredRestartArguments = if ($restartArgumentsWereConfigured) {
        @($restartProperty.Value | ForEach-Object { [string]$_ })
    }
    else {
        $null
    }

    $workingSetting = [string](Get-OptionalValue -Object $config -Name 'restartWorkingDirectory' -DefaultValue '')
    $restartWorkingDirectory = if ([string]::IsNullOrWhiteSpace($workingSetting)) {
        $installDirectory
    }
    else {
        ConvertTo-AbsolutePath -Path $workingSetting -BaseDirectory $configDirectory
    }

    $backupRetention = [int](Get-OptionalValue -Object $config -Name 'backupRetention' -DefaultValue 3)
    $stopTimeoutSeconds = [int](Get-OptionalValue -Object $config -Name 'stopTimeoutSeconds' -DefaultValue 15)
    $restartObservationSeconds = [int](Get-OptionalValue -Object $config -Name 'restartObservationSeconds' -DefaultValue 4)
    $maximumArchiveBytes = [long](Get-OptionalValue -Object $config -Name 'maximumArchiveBytes' -DefaultValue 536870912)
    $maximumExtractedBytes = [long](Get-OptionalValue -Object $config -Name 'maximumExtractedBytes' -DefaultValue 1073741824)
    $maximumArchiveEntries = [int](Get-OptionalValue -Object $config -Name 'maximumArchiveEntries' -DefaultValue 5000)
    $script:VerboseLogging = [bool](Get-OptionalValue -Object $config -Name 'verboseLogging' -DefaultValue $false)
    $permitUnverified = $AllowUnverifiedAsset.IsPresent -or
        [bool](Get-OptionalValue -Object $config -Name 'allowUnverifiedAsset' -DefaultValue $false)

    if ($backupRetention -lt 1 -or $backupRetention -gt 20) { throw 'backupRetention must be between 1 and 20.' }
    if ($stopTimeoutSeconds -lt 1 -or $stopTimeoutSeconds -gt 300) { throw 'stopTimeoutSeconds must be between 1 and 300.' }
    if ($restartObservationSeconds -lt 0 -or $restartObservationSeconds -gt 60) { throw 'restartObservationSeconds must be between 0 and 60.' }
    if ($maximumArchiveBytes -lt 1048576) { throw 'maximumArchiveBytes is implausibly small.' }
    if ($maximumExtractedBytes -lt $maximumArchiveBytes) { throw 'maximumExtractedBytes must not be smaller than maximumArchiveBytes.' }
    if ($maximumArchiveEntries -lt 1 -or $maximumArchiveEntries -gt 100000) { throw 'maximumArchiveEntries is out of range.' }

    $installHash = (Get-StringSha256 -Value $installDirectory).Substring(0, 16)
    $stateSetting = [string](Get-OptionalValue -Object $config -Name 'stateDirectory' -DefaultValue '')
    $stateDirectory = if ([string]::IsNullOrWhiteSpace($stateSetting)) {
        Join-Path $env:LOCALAPPDATA "OpenAI\TunnelClientUpdater\$installHash"
    }
    else {
        ConvertTo-AbsolutePath -Path $stateSetting -BaseDirectory $configDirectory
    }

    $logDirectory = Join-Path $stateDirectory 'logs'
    $backupRoot = Join-Path $stateDirectory 'backups'
    $stagingRoot = Join-Path $stateDirectory 'staging'
    [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
    $script:LogFile = Join-Path $logDirectory ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')

    $mutex = [System.Threading.Mutex]::new($false, "Local\OpenAITunnelUpdater-$installHash")
    $hasMutex = $false
    try {
        try {
            $hasMutex = $mutex.WaitOne(0)
        }
        catch [System.Threading.AbandonedMutexException] {
            $hasMutex = $true
            Write-Log -Level 'WARN' -Message 'Recovered an abandoned updater lock from a previous interrupted run.'
        }

        if (-not $hasMutex) {
            Write-Log -Level 'INFO' -Message 'Another updater instance is already running; exiting.'
            return
        }

        Write-Log -Level 'INFO' -Message "Checking the latest stable openai/tunnel-client release for '$installDirectory'."

        $statePath = Join-Path $stateDirectory 'state.json'
        $state = Read-StateFile -Path $statePath
        $release = Get-LatestStableRelease
        $asset = Select-WindowsReleaseAsset -Release $release -ExplicitAssetName $explicitAssetName

        $latestTag = [string]$release.tag_name
        $installedTag = if ($null -ne $state) {
            [string](Get-OptionalValue -Object $state -Name 'installedTag' -DefaultValue '')
        }
        else {
            ''
        }

        if ($null -ne $state -and $installedTag -ne $latestTag) {
            $latestVersion = Convert-ReleaseTagToVersion -Tag $latestTag
            $installedVersion = Convert-ReleaseTagToVersion -Tag $installedTag
            if ($null -ne $latestVersion -and $null -ne $installedVersion) {
                if ($latestVersion -lt $installedVersion) {
                    throw "Refusing automatic downgrade from '$installedTag' to '$latestTag'."
                }
                if ($latestVersion -eq $installedVersion -and -not $Force) {
                    Write-Log -Level 'INFO' -Message "Installed tag '$installedTag' and latest tag '$latestTag' resolve to the same version; no action taken."
                    return
                }
            }
            elseif (-not $Force) {
                throw "Cannot safely compare installed tag '$installedTag' with latest tag '$latestTag'. Re-run with -Force only after inspection."
            }
        }

        $installationHealthy = Test-ManagedInstallation -State $state -InstallDirectory $installDirectory
        $needsUpdate = $Force -or $null -eq $state -or $installedTag -ne $latestTag -or -not $installationHealthy

        if (-not $needsUpdate) {
            Write-Log -Level 'INFO' -Message "Already current at $latestTag; all managed file hashes match."
            return
        }

        $reason = if ($null -eq $state) {
            'first managed installation'
        }
        elseif ($installedTag -ne $latestTag) {
            "update from $installedTag"
        }
        elseif (-not $installationHealthy) {
            'repair of changed or missing managed files'
        }
        else {
            'forced reinstall'
        }

        Write-Log -Level 'INFO' -Message "Latest stable release is $latestTag; action required: $reason."
        Write-Log -Level 'INFO' -Message "Selected release asset: $($asset.name) ($($asset.size) bytes)."

        if ($CheckOnly) {
            Write-Output ([pscustomobject]@{
                Repository       = "$RepositoryOwner/$RepositoryName"
                InstalledTag     = if ([string]::IsNullOrWhiteSpace($installedTag)) { $null } else { $installedTag }
                LatestTag        = $latestTag
                AssetName        = [string]$asset.name
                ActionRequired   = $true
                Reason           = $reason
                RunningPolicy    = $policy
            })
            return
        }

        Assert-InstallDirectoryWritable -InstallDirectory $installDirectory

        $stagingDirectory = Join-Path $stagingRoot ([Guid]::NewGuid().ToString('N'))
        $extractDirectory = Join-Path $stagingDirectory 'extracted'
        [System.IO.Directory]::CreateDirectory($stagingDirectory) | Out-Null

        try {
            $archivePath = Join-Path $stagingDirectory ([System.IO.Path]::GetFileName([string]$asset.name))
            if ([long]$asset.size -gt $maximumArchiveBytes) {
                throw "Release asset exceeds maximumArchiveBytes: $($asset.size) > $maximumArchiveBytes."
            }

            Save-HttpsFile `
                -Uri ([string]$asset.browser_download_url) `
                -Destination $archivePath `
                -MaximumBytes $maximumArchiveBytes `
                -Description "Release download '$($asset.name)'"

            $downloadedLength = (Get-Item -LiteralPath $archivePath).Length
            if ([long]$asset.size -gt 0 -and $downloadedLength -ne [long]$asset.size) {
                throw "Downloaded size mismatch: expected $($asset.size), got $downloadedLength."
            }

            $actualArchiveHash = Get-FileSha256 -Path $archivePath
            $publishedHash = Get-PublishedArchiveSha256 -Release $release -Asset $asset -StagingDirectory $stagingDirectory
            $archiveVerified = $false
            $verificationSource = $null
            if ($null -ne $publishedHash) {
                if ($actualArchiveHash -ne $publishedHash.Hash) {
                    throw "SHA-256 mismatch for '$($asset.name)'. Expected $($publishedHash.Hash), got $actualArchiveHash."
                }
                $archiveVerified = $true
                $verificationSource = $publishedHash.Source
                Write-Log -Level 'INFO' -Message "Archive SHA-256 verified using $verificationSource."
            }

            Expand-ZipSafely `
                -ArchivePath $archivePath `
                -Destination $extractDirectory `
                -MaximumExtractedBytes $maximumExtractedBytes `
                -MaximumEntries $maximumArchiveEntries

            $payloadRoot = Get-PayloadRoot -ExtractionRoot $extractDirectory
            $payloadManifest = @(Get-PayloadManifest -PayloadRoot $payloadRoot)
            $newExecutableRelative = Resolve-ExecutableRelativePath `
                -PayloadManifest $payloadManifest `
                -ConfiguredRelativePath $configuredExecutable `
                -PreviousState $state

            $signatureResult = Test-PayloadCodeSignatures `
                -PayloadManifest $payloadManifest `
                -ExecutableRelativePath $newExecutableRelative

            $signatureVerified = $signatureResult.AllCodeFilesValid -and $signatureResult.MainExecutableIsOpenAI
            if ($signatureVerified) {
                $signerList = ($signatureResult.Signers -join '; ')
                Write-Log -Level 'INFO' -Message "All executable code files have valid Authenticode signatures; main executable signer identifies OpenAI. Signer(s): $signerList"
                if (-not $archiveVerified) {
                    $verificationSource = 'trusted OpenAI Authenticode signatures on all executable code files'
                }
            }

            if (-not $archiveVerified -and -not $signatureVerified) {
                if (-not $permitUnverified) {
                    throw (
                        'The release supplied no usable SHA-256 digest/checksum and its code files were not all ' +
                        'validly signed by OpenAI. Refusing installation. Inspect the official release, then use ' +
                        '-AllowUnverifiedAsset only as a conscious exception.')
                }
                $verificationSource = 'explicit AllowUnverifiedAsset override'
                Write-Log -Level 'WARN' -Message 'Proceeding without independently published digest or sufficient OpenAI code signatures because an explicit override is enabled.'
            }

            $newExecutablePath = Get-SafeChildPath -Root $installDirectory -RelativePath $newExecutableRelative
            $trackedExecutablePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            [void]$trackedExecutablePaths.Add($newExecutablePath)
            if ($null -ne $state) {
                $oldExecutableRelative = [string](Get-OptionalValue -Object $state -Name 'executableRelativePath' -DefaultValue '')
                if (-not [string]::IsNullOrWhiteSpace($oldExecutableRelative)) {
                    [void]$trackedExecutablePaths.Add((Get-SafeChildPath -Root $installDirectory -RelativePath $oldExecutableRelative))
                    if (($clientTaskName -or $clientServiceName) -and $oldExecutableRelative -ne $newExecutableRelative) {
                        throw 'The release changed executableRelativePath while a task/service manager is configured. Update the manager action deliberately before installing this release.'
                    }
                }
            }
            $executablePaths = @($trackedExecutablePaths)

            $managerState = Get-ClientManagerState -TaskFullName $clientTaskName -ServiceName $clientServiceName
            $runningNow = @(Get-ProcessesByExecutablePath -ExecutablePaths $executablePaths)
            if ($policy -eq 'Defer' -and ($managerState.WasActive -or $runningNow.Count -gt 0)) {
                Write-Log -Level 'INFO' -Message "Client is running; update to $latestTag was safely deferred by policy."
                return
            }

            $backup = New-Backup `
                -BackupRoot $backupRoot `
                -InstallDirectory $installDirectory `
                -NewManifest $payloadManifest `
                -PreviousState $state
            Write-Log -Level 'INFO' -Message "Backup created at '$($backup.Directory)'."

            $restartContext = $null
            try {
                $restartContext = Prepare-ClientForUpdate `
                    -ExecutablePaths $executablePaths `
                    -NewExecutablePath $newExecutablePath `
                    -Policy $policy `
                    -TaskFullName $clientTaskName `
                    -ServiceName $clientServiceName `
                    -ConfiguredRestartArguments $configuredRestartArguments `
                    -RestartArgumentsWereConfigured $restartArgumentsWereConfigured `
                    -RestartWorkingDirectory $restartWorkingDirectory `
                    -StopTimeoutSeconds $stopTimeoutSeconds

                if ($restartContext.Deferred) {
                    Write-Log -Level 'INFO' -Message "Client is running; update to $latestTag was safely deferred by policy."
                    return
                }

                Install-Payload `
                    -PayloadManifest $payloadManifest `
                    -InstallDirectory $installDirectory `
                    -PreviousState $state

                Resume-Client -Context $restartContext -ObservationSeconds $restartObservationSeconds

                $newState = [ordered]@{
                    schemaVersion             = 1
                    repository                = "$RepositoryOwner/$RepositoryName"
                    installDirectory          = $installDirectory
                    installedTag              = $latestTag
                    releaseId                 = [long]$release.id
                    releasePublishedAtUtc     = [string]$release.published_at
                    assetName                 = [string]$asset.name
                    archiveSha256             = $actualArchiveHash
                    verificationSource        = $verificationSource
                    executableRelativePath    = $newExecutableRelative
                    installedAtUtc            = [DateTimeOffset]::UtcNow.ToString('o')
                    managedFiles              = @($payloadManifest | ForEach-Object {
                        [ordered]@{
                            relativePath = $_.RelativePath
                            length       = $_.Length
                            sha256       = $_.Sha256
                        }
                    })
                }
                Write-JsonAtomically -Path $statePath -Value $newState
                Write-Log -Level 'INFO' -Message "Successfully installed openai/tunnel-client $latestTag."
            }
            catch {
                $updateFailure = $_
                Write-Log -Level 'ERROR' -Message "Update failed after backup creation: $($updateFailure.Exception.Message)"
                $rollbackFailure = $null

                try {
                    if ($null -ne $restartContext) {
                        Stop-ClientForRollback `
                            -Context $restartContext `
                            -ExecutablePaths $executablePaths `
                            -TimeoutSeconds $stopTimeoutSeconds
                    }
                    Restore-Backup -Backup $backup -InstallDirectory $installDirectory
                    Write-Log -Level 'WARN' -Message 'Previous managed files were restored from backup.'

                    if ($null -ne $restartContext -and $restartContext.ShouldRestart) {
                        $oldExecutable = if ($null -ne $state) {
                            $oldRelative = [string](Get-OptionalValue -Object $state -Name 'executableRelativePath' -DefaultValue $newExecutableRelative)
                            Get-SafeChildPath -Root $installDirectory -RelativePath $oldRelative
                        }
                        else {
                            $newExecutablePath
                        }
                        $restartContext.NewExecutable = $oldExecutable
                        Resume-Client -Context $restartContext -ObservationSeconds $restartObservationSeconds
                        Write-Log -Level 'WARN' -Message 'Previous client version was restarted after rollback.'
                    }
                }
                catch {
                    $rollbackFailure = $_
                    Write-Log -Level 'ERROR' -Message "Rollback also failed: $($rollbackFailure.Exception.Message). Backup remains at '$($backup.Directory)'."
                }

                if ($null -ne $rollbackFailure) {
                    throw "Update failed and rollback was incomplete. Update error: $($updateFailure.Exception.Message). Rollback error: $($rollbackFailure.Exception.Message)."
                }
                throw "Update failed; previous files were restored. $($updateFailure.Exception.Message)"
            }

            Remove-OldDirectories -Root $backupRoot -Keep $backupRetention
        }
        finally {
            if ([System.IO.Directory]::Exists($stagingDirectory)) {
                try { Remove-Item -LiteralPath $stagingDirectory -Recurse -Force }
                catch { Write-Log -Level 'WARN' -Message "Could not remove staging directory '$stagingDirectory'." }
            }
        }
    }
    finally {
        if ($hasMutex) {
            try { $mutex.ReleaseMutex() } catch { }
        }
        $mutex.Dispose()
        Remove-OldLogs -LogDirectory $logDirectory -Keep 20
    }
}

try {
    Invoke-Updater
    exit 0
}
catch {
    $message = $_.Exception.Message
    if ($null -ne $script:LogFile) {
        Write-Log -Level 'ERROR' -Message $message
        Write-Host "Log: $script:LogFile"
    }
    else {
        Write-Warning "ERROR: $message"
    }
    exit 1
}
