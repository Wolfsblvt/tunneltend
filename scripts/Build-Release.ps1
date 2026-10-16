[CmdletBinding()]
param(
    [string]$Version = '0.1.0-preview.1',
    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Validate before the version participates in any deletion or output path.
if ($Version -notmatch '^(?<base>\d+\.\d+\.\d+)(?:-(?<pre>[0-9A-Za-z.-]+))?$') {
    throw "Version '$Version' is not semantic versioning."
}
$baseVersion = $Matches.base
$prerelease = if ($Matches.ContainsKey('pre')) { $Matches.pre } else { '' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $SkipTests) {
    & (Join-Path $PSScriptRoot 'Invoke-Tests.ps1')
    & (Join-Path $PSScriptRoot 'Invoke-RepositoryValidation.ps1')
}

$artifacts = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$stage = Join-Path $artifacts "tunneltend-$Version"
Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage | Out-Null

$include = @(
    'assets', 'carriers', 'docs', 'examples', 'schemas', 'scripts', 'src', 'tests',
    'AGENTS.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'Install-TunnelTend.cmd',
    'LICENSE', 'README.md', 'SECURITY.md', 'PSScriptAnalyzerSettings.psd1',
    'tunneltend.cmd', 'tunneltend.ps1'
)
foreach ($item in $include) {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $stage -Recurse -Force
}


& (Join-Path $stage 'scripts/Build-WindowsLauncher.ps1') -OutputPath (Join-Path $stage 'bin/TunnelTend.TaskHost.exe') | Out-Null

# Stamp the staged package without mutating the source checkout.
$stagedManifest = Join-Path $stage 'src/TunnelTend/TunnelTend.psd1'
$manifestText = Get-Content $stagedManifest -Raw
$manifestText = [regex]::Replace($manifestText, "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion = '$baseVersion'")
if ($prerelease) {
    if ($manifestText -match "Prerelease\s*=") {
        $manifestText = [regex]::Replace($manifestText, "Prerelease\s*=\s*'[^']*'", "Prerelease = '$prerelease'")
    }
} else {
    $manifestText = [regex]::Replace($manifestText, "(?m)^\s*Prerelease\s*=.*\r?\n", '')
}
Set-Content $stagedManifest $manifestText -Encoding utf8NoBOM
$stagedModule = Join-Path $stage 'src/TunnelTend/TunnelTend.psm1'
$moduleText = Get-Content $stagedModule -Raw
$versionPattern = [regex]::Escape('$script:TtModuleVersion') + "\s*=\s*'[^']+'"
$moduleText = [regex]::Replace($moduleText, $versionPattern, "`$script:TtModuleVersion = '$Version'")
Set-Content $stagedModule $moduleText -Encoding utf8NoBOM
$stagedUtilities = Join-Path $stage 'src/TunnelTend/Private/00-Utilities.ps1'
$utilityText = Get-Content $stagedUtilities -Raw
$utilityText = [regex]::Replace($utilityText, $versionPattern, "`$script:TtModuleVersion = '$Version'")
Set-Content $stagedUtilities $utilityText -Encoding utf8NoBOM
$stagedInstaller = Join-Path $stage 'scripts/Install-TunnelTend.ps1'
$installerText = Get-Content $stagedInstaller -Raw
$installerText = $installerText.Replace("version='0.1.0-preview.1'", "version='$Version'")
Set-Content $stagedInstaller $installerText -Encoding utf8NoBOM

$zip = Join-Path $artifacts "tunneltend-$Version.zip"
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content "$zip.sha256" -Encoding ascii
$manifest = [ordered]@{
    name = 'tunneltend'
    version = $Version
    createdAt = [DateTimeOffset]::UtcNow.ToString('o')
    sha256 = $hash
    files = @(Get-ChildItem $stage -Recurse -File | ForEach-Object {
        [IO.Path]::GetRelativePath($stage, $_.FullName).Replace('\', '/')
    })
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $artifacts "tunneltend-$Version.manifest.json") -Encoding utf8NoBOM
Write-Host $zip
