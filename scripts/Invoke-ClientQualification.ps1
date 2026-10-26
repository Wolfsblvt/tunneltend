#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('source','release')][string]$PackageKind = 'release',
    [string]$PackagePath,
    [string]$PackageVersion,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [string]$ReleaseTag,
    [string]$OutputPath = (Join-Path $PSScriptRoot '../artifacts/qualification/report.json'),
    [ValidatePattern('^[0-9]{1,20}$')][string]$RunId = '0',
    [ValidateRange(1,1000000)][int]$RunAttempt = 1
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not $IsWindows) { throw 'Qualification requires Windows.' }
if ($MyInvocation.InvocationName -eq '.') { throw 'Run qualification in its own pwsh -NoProfile -NonInteractive -File process.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repositoryRoot 'src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1') -LibraryOnly
. (Join-Path $repositoryRoot 'src/TunnelTend/Private/20-OfficialClient.ps1')

function New-QualificationBoundary {
    param([string[]]$Ids)
    @{ outcome='not exercised'; checks=@($Ids | ForEach-Object { @{ id=$_; outcome='not exercised' } }) }
}
function Set-QualificationCheck {
    param([System.Collections.IDictionary]$Boundary, [string]$Id, [string]$Outcome)
    $check = @($Boundary.checks | Where-Object id -CEQ $Id)
    if ($check.Count -ne 1) { throw 'Unknown qualification check.' }
    $check[0].outcome = $Outcome
    $values = @($Boundary.checks | ForEach-Object outcome)
    $Boundary.outcome = if ('failed' -in $values) { 'failed' } elseif ('unavailable' -in $values) { 'unavailable' } elseif (@($values | Where-Object { $_ -ne 'not exercised' }).Count -eq 0) { 'not exercised' } else { 'passed' }
}
function Get-QualificationFailureOutcome {
    param([Exception]$Exception)
    if ($Exception.GetType().Name -match 'Http|WebException|Socket') { return 'unavailable' }
    return 'failed'
}

$observed = [DateTime]::UtcNow.ToString('o')
$report = [ordered]@{
    schemaVersion=1; contractVersion=1; observedAt=$observed; checkedAt=$observed
    run=@{ id=$RunId; attempt=$RunAttempt; workflow='upstream-compatibility.yml'; artifact="client-qualification-$PackageKind" }
    source=@{ repository='Wolfsblvt/tunneltend'; commit=$SourceCommit; harnessSha256=(Get-FileSha256 $PSCommandPath); adapterSha256=$null }
    package=@{ kind=$PackageKind; version=$(if ($PackageVersion) { $PackageVersion } else { $null }); sha256=$null; sourceCommit=$(if ($PackageKind -eq 'source') { $SourceCommit } else { $null }) }
    release=$null
    architectures=@(foreach ($arch in @('amd64','arm64')) {
        @{
            architecture=$arch; asset=$null; execution='not exercised'
            distribution=(New-QualificationBoundary @('package-acquisition','release-selection','asset-selection','published-digest','guarded-extraction','version-agreement','installation-agreement'))
            credentialFreeCli=(New-QualificationBoundary @('version','runtimes','runtimes-json','runtime-status','runtime-connect','runtime-stop','list-json','status-missing','stop-missing'))
            localFleet=(New-QualificationBoundary @('owned-fleet'))
            connectedConsumer=(New-QualificationBoundary @('connected-call'))
        }
    })
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('tunneltend-qualification-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
# This dedicated process executes downloaded code. Do not expose inherited
# Actions/OpenAI credentials or the operator's profile and runtime aliases.
foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
    if ([string]$key -notin @('SystemRoot','WINDIR')) { [Environment]::SetEnvironmentVariable([string]$key, $null, 'Process') }
}
foreach ($key in @('TEMP','TMP','HOME','USERPROFILE','APPDATA','LOCALAPPDATA','XDG_STATE_HOME','XDG_CONFIG_HOME','CODEX_HOME','TUNNEL_CLIENT_STATE_DIR')) { [Environment]::SetEnvironmentVariable($key, $work, 'Process') }
$testedModule = $null
$currentCheck = 'package-acquisition'
try {
    if ($PackageKind -eq 'release') {
        # Fixed product source, no installer, credentials, task registration or PATH effects.
        $product = Invoke-RestMethod 'https://api.github.com/repos/Wolfsblvt/tunneltend/releases/latest' -Headers @{Accept='application/vnd.github+json';'User-Agent'='tunneltend-qualification'} -TimeoutSec 30
        if ($product.draft -or $product.prerelease -or $product.tag_name -cnotmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid supported product release.' }
        $PackageVersion = ([string]$product.tag_name).Substring(1)
        $report.package.version = $PackageVersion
        $name = "tunneltend-$PackageVersion.zip"
        $assets = @($product.assets | Where-Object name -CEQ $name)
        if ($assets.Count -ne 1 -or [string]$assets[0].digest -cnotmatch '^sha256:[0-9a-f]{64}$') { throw 'Product package lacks a unique published digest.' }
        $uri = "https://github.com/Wolfsblvt/tunneltend/releases/download/$($product.tag_name)/$name"
        if ([string]$assets[0].browser_download_url -cne $uri) { throw 'Unexpected product package URL.' }
        $PackagePath = Join-Path $work $name
        Save-HttpsFile -Uri $uri -Destination $PackagePath -MaximumBytes 536870912 -Description 'Supported TunnelTend package'
        if ((Get-FileSha256 $PackagePath) -cne ([string]$assets[0].digest).Substring(7)) { throw 'Product package digest mismatch.' }
    }
    elseif (-not $PackagePath -or -not $PackageVersion) { throw 'Source qualification needs its actual built package and version.' }
    $report.package.sha256 = Get-FileSha256 $PackagePath
    $packageRoot = Join-Path $work 'package'
    Expand-ZipSafely -ArchivePath $PackagePath -Destination $packageRoot -MaximumExtractedBytes 1073741824 -MaximumEntries 10000
    $modulePath = Join-Path $packageRoot 'src/TunnelTend/TunnelTend.psd1'
    $testedModule = Import-Module $modulePath -Force -PassThru
    if ([string]$testedModule.Version -ne ($PackageVersion -split '-')[0]) { throw 'Product package version mismatch.' }
    $report.source.adapterSha256 = Get-FileSha256 (Join-Path $packageRoot 'src/TunnelTend/Private/20-OfficialClient.ps1')
    foreach ($record in $report.architectures) { Set-QualificationCheck $record.distribution $currentCheck 'passed' }
    $currentCheck = 'release-selection'
    $release = Get-LatestStableRelease -Tag $ReleaseTag
    if ([string]$release.tag_name -cnotmatch '^v?[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid stable version tag.' }
    $report.release = @{ id=[long]$release.id; tag=[string]$release.tag_name; publishedAt=([DateTimeOffset]$release.published_at).UtcDateTime.ToString('o') }
    foreach ($record in $report.architectures) { Set-QualificationCheck $record.distribution $currentCheck 'passed' }

    foreach ($record in $report.architectures) {
        $step = 'asset-selection'
        try {
            $arch = if ($record.architecture -eq 'amd64') { 'X64' } else { 'Arm64' }
            $asset = Select-WindowsReleaseAsset -Release $release -ExplicitAssetName '' -Architecture $arch
            # Asset naming, release URL and executable selection must describe this release.
            if ([string]$asset.browser_download_url -cne "https://github.com/openai/tunnel-client/releases/download/$($release.tag_name)/$($asset.name)") { throw 'Asset belongs to a different release.' }
            $record.asset = @{ id=[long]$asset.id; name=[string]$asset.name; sha256=$null }
            Set-QualificationCheck $record.distribution $step 'passed'
            $step = 'published-digest'
            $archive = Join-Path $work $asset.name
            if ([long]$asset.size -le 0 -or [long]$asset.size -gt 536870912) { throw 'Invalid published archive size.' }
            Save-HttpsFile -Uri $asset.browser_download_url -Destination $archive -MaximumBytes 536870912 -Description 'Official qualification asset'
            $digest = Get-PublishedArchiveSha256 $release $asset $work
            if (-not $digest -or (Get-FileSha256 $archive) -cne $digest.Hash -or (Get-Item $archive).Length -ne [long]$asset.size) { throw 'Official archive verification failed.' }
            $record.asset.sha256 = $digest.Hash
            Set-QualificationCheck $record.distribution $step 'passed'
            $step = 'guarded-extraction'
            $target = Join-Path $work $record.architecture
            Expand-ZipSafely $archive $target 1073741824 2048
            $payloadRoot = Get-PayloadRoot $target
            $manifest = @(Get-PayloadManifest $payloadRoot)
            $relative = Resolve-ExecutableRelativePath -PayloadManifest $manifest -ConfiguredRelativePath 'tunnel-client.exe' -PreviousState $null
            $exe = Get-SafeChildPath $payloadRoot $relative
            Set-QualificationCheck $record.distribution $step 'passed'
            if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne $arch) { continue }
            $record.execution = 'native'
            $state = Join-Path $work ("state-" + $record.architecture)
            $registry = & $testedModule { param($directory,$exe) $r=New-TtDefaultRegistry; $r.settings.officialClient.installDirectory=$directory; $r.settings.officialClient.executablePath=$exe; $r } $payloadRoot $exe
            $step = 'version-agreement'
            $version = & $testedModule { param($r,$s) Get-TtOfficialClientVersion $r $s } $registry $state
            if (-not $version.installed -or $version.version -cne ([string]$release.tag_name).TrimStart('v')) { throw 'Executable and release versions disagree.' }
            Set-QualificationCheck $record.distribution $step 'passed'
            $caps = & $testedModule { param($r,$s) Test-TtOfficialClientCapabilities $r $s } $registry $state
            foreach ($check in $caps.checks) { Set-QualificationCheck $record.credentialFreeCli $check.id $(if ($check.ok) { 'passed' } else { 'failed' }) }
            foreach ($check in @(Test-TtOfficialClientBehavior -Executable $exe)) { Set-QualificationCheck $record.credentialFreeCli $check.id $(if ($check.ok) { 'passed' } else { 'failed' }) }
            if ($record.credentialFreeCli.outcome -ne 'passed') { continue }
            $step = 'installation-agreement'
            $installed = Join-Path $work ("installed-" + $record.architecture)
            $transactionRegistry = & $testedModule { param($directory) $r=New-TtDefaultRegistry; $r.settings.officialClient.installDirectory=$directory; $r.settings.officialClient.executablePath=Join-Path $directory 'tunnel-client.exe'; $r } $installed
            & $testedModule { param($r,$s,$payload) $runtime=New-TtDefaultRuntimeStore; Invoke-TtClientFileTransaction $r $runtime $s $payload | Out-Null } $transactionRegistry $state $exe
            $installedVersion = & $testedModule { param($r,$s) Get-TtOfficialClientVersion $r $s } $transactionRegistry $state
            if ($installedVersion.version -cne $version.version -or (Get-FileSha256 $transactionRegistry.settings.officialClient.executablePath) -cne (Get-FileSha256 $exe)) { throw 'Installed result does not match staged bytes/version.' }
            Set-QualificationCheck $record.distribution $step 'passed'
        }
        catch { Set-QualificationCheck $record.distribution $step (Get-QualificationFailureOutcome $_.Exception) }
    }
}
catch {
    foreach ($record in $report.architectures) { Set-QualificationCheck $record.distribution $currentCheck (Get-QualificationFailureOutcome $_.Exception) }
}
finally {
    foreach ($record in $report.architectures) {
        foreach ($name in @('distribution','credentialFreeCli','localFleet','connectedConsumer')) {
            $checks = @($record[$name].checks)
            if ($name -eq 'distribution' -and $record.execution -eq 'not exercised') { $checks = @($checks | Where-Object id -NotIn @('version-agreement','installation-agreement')) }
            $values = @($checks | ForEach-Object outcome)
            $record[$name].outcome = if ('failed' -in $values) { 'failed' } elseif ('unavailable' -in $values) { 'unavailable' } elseif ('not exercised' -in $values) { 'not exercised' } else { 'passed' }
        }
    }
    $report.checkedAt = [DateTime]::UtcNow.ToString('o')
    $json = $report | ConvertTo-Json -Depth 30
    if (-not (Test-Json -Json $json -SchemaFile (Join-Path $repositoryRoot 'schemas/client-qualification.schema.json'))) { throw 'Producer generated an invalid qualification report.' }
    $destination = [IO.Path]::GetFullPath($OutputPath)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    [IO.File]::WriteAllText($destination, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    if ($testedModule) { Remove-Module $testedModule -Force }
    if ([IO.Directory]::Exists($work)) { Remove-Item -LiteralPath $work -Recurse -Force }
}
if (@($report.architectures | Where-Object { $_.distribution.outcome -ne 'passed' -or ($_.execution -eq 'native' -and $_.credentialFreeCli.outcome -ne 'passed') }).Count -gt 0) {
    throw 'Official-client qualification failed; inspect fixed check outcomes in report.json.'
}
Write-Output 'Qualification completed; fleet and connected use were not exercised.'
