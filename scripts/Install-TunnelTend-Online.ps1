<#
.SYNOPSIS
Download, verify and install the latest TunnelTend release in one step.

.DESCRIPTION
This is the script served at https://tunneltend.com/install.ps1. It resolves the selected
GitHub release of Wolfsblvt/tunneltend, downloads the release ZIP and its published SHA-256
file, refuses any checksum mismatch, extracts the release into a directory you control, and
then runs the ordinary guided installer from that directory. It never bundles or replaces
OpenAI's official tunnel client; the installer acquires that separately and verifies it.

One line, guided installer (asks about sign-in startup, the watchdog and client updates):

    irm https://tunneltend.com/install.ps1 | iex

With installer switches, for example a deterministic unattended installation:

    & ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) -NonInteractive -DisableAutoUpdate

Download and verify only, without installing:

    & ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) -NoInstall

.PARAMETER Version
An exact release version such as 1.0.0. The default is the latest stable release.

.PARAMETER DownloadRoot
Where the verified release is extracted. Default: %LOCALAPPDATA%\TunnelTend\downloads.

.PARAMETER NoInstall
Download, verify and extract the release, then stop and print where it is.

.NOTES
Every argument this script does not itself declare is passed to scripts\Install-TunnelTend.ps1
as named parameters, for example -NonInteractive, -DisableAutostart, -DisableAutoUpdate,
-DisableWatchdog, -InstallRoot or -AutostartAliases a,b. This script deliberately has no
[CmdletBinding()] and no declared catch-all parameter: both would drop the "this is a parameter
name" marking that splatting @args preserves, and `-NonInteractive` would reach the installer
as a positional InstallRoot value.
#>
param(
    [string]$Version,
    [string]$DownloadRoot,
    [switch]$NoInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repository = 'Wolfsblvt/tunneltend'
$apiBase = "https://api.github.com/repos/$repository/releases"
$headers = @{ 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'tunneltend-install' }

if (-not $IsWindows) { throw 'TunnelTend installation currently targets Windows.' }
if ($PSVersionTable.PSVersion -lt [version]'7.4.0') {
    throw "TunnelTend requires PowerShell 7.4 or newer; this is $($PSVersionTable.PSVersion). Install it with: winget install --id Microsoft.PowerShell --source winget"
}
if (-not $DownloadRoot) { $DownloadRoot = Join-Path $env:LOCALAPPDATA 'TunnelTend/downloads' }
$DownloadRoot = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($DownloadRoot))

function Write-Step([string]$Text) { [Console]::Out.WriteLine("tunneltend install: $Text") }

# 1. Resolve the release and its two assets.
$releaseUrl = if ($Version) { "$apiBase/tags/v$($Version.TrimStart('v'))" } else { "$apiBase/latest" }
Write-Step "resolving release from $releaseUrl"
$release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -MaximumRedirection 3
if ($release.draft -or $release.prerelease) { throw "Release $($release.tag_name) is a draft or prerelease; choose a stable version." }
$tag = [string]$release.tag_name
$resolvedVersion = $tag.TrimStart('v')
$zipName = "tunneltend-$resolvedVersion.zip"
$zipAsset = @($release.assets | Where-Object name -eq $zipName)
$shaAsset = @($release.assets | Where-Object name -eq "$zipName.sha256")
if ($zipAsset.Count -ne 1 -or $shaAsset.Count -ne 1) { throw "Release $tag does not publish exactly one $zipName and one $zipName.sha256 asset." }
foreach ($asset in @($zipAsset[0], $shaAsset[0])) {
    $uri = [Uri]$asset.browser_download_url
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com') { throw "Refusing a release asset that is not served from https://github.com: $($asset.browser_download_url)" }
}

# 2. Download both files to a fresh temporary directory.
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tunneltend-download-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    $zipPath = Join-Path $temp $zipName
    $shaPath = Join-Path $temp "$zipName.sha256"
    Write-Step "downloading $zipName ($([math]::Round($zipAsset[0].size / 1KB)) KB)"
    Invoke-WebRequest -Uri $zipAsset[0].browser_download_url -Headers $headers -OutFile $zipPath -MaximumRedirection 5
    Invoke-WebRequest -Uri $shaAsset[0].browser_download_url -Headers $headers -OutFile $shaPath -MaximumRedirection 5

    # 3. Verify the published SHA-256 before anything is extracted.
    $expected = ((Get-Content -LiteralPath $shaPath -Raw) -split '\s+' | Where-Object { $_ } | Select-Object -First 1).ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$') { throw "The published checksum file for $zipName is not a SHA-256 digest." }
    $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        Remove-Item -LiteralPath $zipPath -Force
        throw "Checksum mismatch for $zipName. Expected $expected but downloaded $actual. Nothing was installed."
    }
    Write-Step "verified SHA-256 $actual"

    # 4. Extract into a versioned directory you control.
    $extractRoot = Join-Path $DownloadRoot "tunneltend-$resolvedVersion"
    if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
    $installer = Join-Path $extractRoot 'scripts/Install-TunnelTend.ps1'
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw "The extracted release does not contain scripts/Install-TunnelTend.ps1: $extractRoot" }
    Write-Step "extracted TunnelTend $resolvedVersion to $extractRoot"
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($NoInstall) {
    Write-Step "download verified; not installing. Run the installer yourself with: pwsh -NoProfile -File `"$installer`""
    return
}

# 5. Run the ordinary installer from the verified release, in this console, so the guided
#    questions still work. Splatting the automatic $args keeps each switch and value bound to its
#    parameter name; a typed string array would turn them all into positional values.
Write-Step 'starting the installer'
& $installer @args
Write-Step "done. Open a new terminal, then run: tunneltend status"
