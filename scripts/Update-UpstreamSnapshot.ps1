[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'tunneltend'
}
$release = Invoke-RestMethod `
    -Uri 'https://api.github.com/repos/openai/tunnel-client/releases/latest' `
    -Headers $headers `
    -TimeoutSec 30

if ($release.draft -or $release.prerelease) {
    throw 'The latest stable release endpoint returned a draft or prerelease.'
}
if ([string]::IsNullOrWhiteSpace([string]$release.tag_name)) {
    throw 'The latest stable release has no tag.'
}

$windowsAssets = @($release.assets |
    Where-Object { [string]$_.name -match '(?i)^tunnel-client-v[^/]+-windows-(amd64|arm64)\.zip$' } |
    Sort-Object name |
    ForEach-Object {
        $match = [regex]::Match([string]$_.name, '(?i)-windows-(amd64|arm64)\.zip$')
        [ordered]@{
            architecture = $match.Groups[1].Value.ToLowerInvariant()
            name = [string]$_.name
            size = [long]$_.size
            digest = [string]$_.digest
            browserDownloadUrl = [string]$_.browser_download_url
        }
    })
if ($windowsAssets.Count -ne 2) {
    $names = @($release.assets.name | Sort-Object) -join ', '
    throw "Expected exactly the primary amd64 and arm64 Windows ZIPs. Release assets: $names"
}
foreach ($asset in $windowsAssets) {
    if ($asset.digest -notmatch '^sha256:[0-9a-fA-F]{64}$') {
        throw "Release asset '$($asset.name)' has no valid GitHub SHA-256 digest."
    }
}

$checksumAssets = @($release.assets | Where-Object { [string]$_.name -eq 'SHA256SUMS.txt' })
if ($checksumAssets.Count -ne 1) {
    throw 'Expected exactly one SHA256SUMS.txt release asset.'
}
$checksumAsset = $checksumAssets[0]
if ([string]$checksumAsset.digest -notmatch '^sha256:[0-9a-fA-F]{64}$') {
    throw 'SHA256SUMS.txt has no valid GitHub SHA-256 digest.'
}

$snapshot = [ordered]@{
    schemaVersion = 1
    repository = 'openai/tunnel-client'
    releaseId = [long]$release.id
    tag = [string]$release.tag_name
    name = [string]$release.name
    publishedAt = [string]$release.published_at
    updatedAt = [string]$release.updated_at
    releaseUrl = [string]$release.html_url
    checksumAsset = [ordered]@{
        name = [string]$checksumAsset.name
        size = [long]$checksumAsset.size
        digest = [string]$checksumAsset.digest
        browserDownloadUrl = [string]$checksumAsset.browser_download_url
    }
    windowsAssets = $windowsAssets
}

$outputPath = Join-Path $root 'docs/research/openai-tunnel-client-release.json'
$json = $snapshot | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText(
    $outputPath,
    $json + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
