# Isolate tested-package functions from the harness's current-source bootstrap.
function New-QualificationUpdater {
    param([Parameter(Mandatory)][string]$Path)
    New-Module -Name TtQualificationUpdater -ArgumentList $Path -ScriptBlock {
        param($updaterPath)
        . $updaterPath -LibraryOnly
        Export-ModuleMember -Function @()
    }
}

function Get-QualificationAsset {
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSModuleInfo]$Updater,
        [Parameter(Mandatory)][object]$Release,
        [Parameter(Mandatory)][ValidateSet('X64','Arm64')][string]$Architecture
    )
    & $Updater {
        param($release,$architecture)
        if ((Get-Command Select-WindowsReleaseAsset).Parameters.ContainsKey('Architecture')) {
            return Select-WindowsReleaseAsset -Release $release -ExplicitAssetName '' -Architecture $architecture
        }
        if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -eq $architecture) {
            return Select-WindowsReleaseAsset -Release $release -ExplicitAssetName ''
        }
        # No result means this package cannot select the requested foreign architecture.
    } $Release $Architecture
}

# Older shipped updaters have no library entry. Exercise their actual native
# executable route, then use its receipt as evidence rather than newer helpers.
function Invoke-QualificationLegacyUpdater {
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSModuleInfo]$Module,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Work,
        [Parameter(Mandatory)][string]$PowerShellPath
    )
    $installation = Join-Path $Work 'legacy-native'
    $state = Join-Path $Work 'legacy-state'
    $configPath = Join-Path $Work 'legacy-updater.json'
    $config = & $Module {
        param($installation,$state,$path)
        $registry=New-TtDefaultRegistry
        $registry.settings.officialClient.installDirectory=$installation
        $registry.settings.officialClient.executablePath=Join-Path $installation 'tunnel-client.exe'
        $config=Get-TtOfficialClientUpdaterConfig $registry $state
        Write-TtJsonAtomic $path $config
        $config
    } $installation $state $configPath
    $info=[Diagnostics.ProcessStartInfo]::new($PowerShellPath)
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    foreach ($argument in @('-NoProfile','-NonInteractive','-File',$Path,'-ConfigPath',$configPath,'-RequirePublishedChecksum')) { $info.ArgumentList.Add($argument) }
    $process=[Diagnostics.Process]::Start($info)
    try {
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(600000)) { $process.Kill($true); throw 'Package updater qualification timed out.' }
        $null=$stdout.GetAwaiter().GetResult(); $null=$stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw 'Package native updater failed.' }
    }
    finally { $process.Dispose() }
    $receipt=Get-Content -LiteralPath (Join-Path $config.stateDirectory 'state.json') -Raw | ConvertFrom-Json -AsHashtable
    if ($receipt.repository -cne 'openai/tunnel-client' -or $receipt.installedTag -cnotmatch '^v?[0-9]+\.[0-9]+\.[0-9]+$' -or $receipt.archiveSha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid package updater receipt.' }
    # This lookup names the release already acquired by the package; it does not
    # select, download, verify or extract an official-client payload for it.
    $release=Invoke-RestMethod "https://api.github.com/repos/openai/tunnel-client/releases/tags/$($receipt.installedTag)" -Headers @{Accept='application/vnd.github+json';'User-Agent'='tunneltend-qualification'} -TimeoutSec 30
    if ($release.draft -or $release.prerelease -or [long]$release.id -ne [long]$receipt.releaseId) { throw 'Package receipt/release identity mismatch.' }
    $assets=@($release.assets | Where-Object name -CEQ $receipt.assetName)
    if ($assets.Count -ne 1) { throw 'Package receipt asset is ambiguous.' }
    # The shipped configuration explicitly requests this executable. Do not
    # consume a receipt-controlled path outside the disposable installation.
    if ($receipt.executableRelativePath -cne 'tunnel-client.exe') { throw 'Unexpected package executable receipt.' }
    @{ release=$release; asset=$assets[0]; digest=$receipt.archiveSha256; root=$installation; executable=(Join-Path $installation 'tunnel-client.exe') }
}
