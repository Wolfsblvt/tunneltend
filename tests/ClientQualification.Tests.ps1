BeforeAll {
    $script:QualificationScript = Join-Path $PSScriptRoot '../scripts/Invoke-ClientQualification.ps1'
    . (Join-Path $PSScriptRoot '../scripts/lib/qualification-updater.ps1')
}

Describe 'Qualification uses the tested package updater' {
    It 'refuses package acquisition when the source selector accepts the same asset' {
        $updater = Join-Path $TestDrive 'incapable-updater.ps1'
        @'
param([switch]$LibraryOnly)
function Select-WindowsReleaseAsset {
    param($Release, $ExplicitAssetName, $Architecture)
    throw 'This package cannot acquire this asset.'
}
'@ | Set-Content -LiteralPath $updater
        # Current-source selector really accepts the release; the package must still fail.
        $source = New-QualificationUpdater -Path (Join-Path $PSScriptRoot '../src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1')
        $package = New-QualificationUpdater -Path $updater
        try {
            $release = @{ assets=@(@{name='tunnel-client-v0.0.18-windows-amd64.zip'; browser_download_url='https://github.com/openai/tunnel-client/releases/download/v0.0.18/tunnel-client-v0.0.18-windows-amd64.zip'}) }
            (Get-QualificationAsset -Updater $source -Release $release -Architecture X64).name | Should -Be 'tunnel-client-v0.0.18-windows-amd64.zip'
            { Get-QualificationAsset -Updater $package -Release $release -Architecture X64 } | Should -Throw '*package cannot acquire*'
        }
        finally { Remove-Module $source,$package -Force }
    }

    It 'leaves a foreign architecture unexercised when an old package has only native selection' {
        $updater = Join-Path $TestDrive 'native-only-updater.ps1'
        @'
param([switch]$LibraryOnly)
function Select-WindowsReleaseAsset {
    param($Release, $ExplicitAssetName)
    @{ name='native-package-asset.zip' }
}
'@ | Set-Content -LiteralPath $updater
        $package = New-QualificationUpdater -Path $updater
        try {
            $native = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
            $foreign = if ($native -eq 'X64') { 'Arm64' } else { 'X64' }
            (Get-QualificationAsset -Updater $package -Release @{} -Architecture $native).name | Should -Be 'native-package-asset.zip'
            Get-QualificationAsset -Updater $package -Release @{} -Architecture $foreign | Should -BeNullOrEmpty
        }
        finally { Remove-Module $package -Force }
    }
}

Describe 'Credential-free qualification failure receipt' -Skip:(-not $IsWindows) {
    It 'records package selection failure even though the current source can acquire that release family' {
        $root = Join-Path $TestDrive 'package/src/TunnelTend'
        [IO.Directory]::CreateDirectory((Join-Path $root 'Tools')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $root 'Private')) | Out-Null
        "@{ RootModule='TunnelTend.psm1'; ModuleVersion='1.0.1'; GUID='c81e73c6-df61-453d-889c-9a1b3143570f' }" | Set-Content (Join-Path $root 'TunnelTend.psd1')
        'Export-ModuleMember -Function @()' | Set-Content (Join-Path $root 'TunnelTend.psm1')
        '# Synthetic adapter: no execution expected.' | Set-Content (Join-Path $root 'Private/20-OfficialClient.ps1')
        @'
param([switch]$LibraryOnly)
function Get-LatestStableRelease {
    param($Tag)
    @{id=123; tag_name='v0.0.18'; published_at='2026-10-23T00:00:00Z'; assets=@()}
}
function Select-WindowsReleaseAsset {
    param($Release, $ExplicitAssetName, $Architecture)
    throw 'Package selector cannot acquire this release.'
}
'@ | Set-Content (Join-Path $root 'Tools/Update-OfficialTunnelClient.ps1')
        $archive = Join-Path $TestDrive 'package.zip'
        Compress-Archive -Path (Join-Path $TestDrive 'package/*') -DestinationPath $archive
        $output = Join-Path $TestDrive 'package-failure.json'
        $info = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
        $info.UseShellExecute=$false; $info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
        foreach ($argument in @('-NoProfile','-NonInteractive','-File',$script:QualificationScript,'-PackageKind','source','-PackagePath',$archive,'-PackageVersion','1.0.1','-SourceCommit',('a'*40),'-OutputPath',$output)) { $info.ArgumentList.Add($argument) }
        $process=[Diagnostics.Process]::Start($info)
        try {
            $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Package divergence specimen timed out.' }
            $process.ExitCode | Should -Not -Be 0
            $null=$stdout.GetAwaiter().GetResult(); $stderr.GetAwaiter().GetResult() | Should -Match 'qualification failed'
        }
        finally { $process.Dispose() }
        $report=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json -AsHashtable
        $report.source.updaterSha256 | Should -Be (Get-FileHash (Join-Path $root 'Tools/Update-OfficialTunnelClient.ps1')).Hash.ToLowerInvariant()
        foreach ($architecture in $report.architectures) {
            $architecture.distribution.outcome | Should -Be 'failed'
            ($architecture.distribution.checks | Where-Object id -EQ 'package-acquisition').outcome | Should -Be 'passed'
            ($architecture.distribution.checks | Where-Object id -EQ 'asset-selection').outcome | Should -Be 'failed'
            ($architecture.distribution.checks | Where-Object id -EQ 'version-agreement').outcome | Should -Be 'not exercised'
        }
    }

    It 'preserves a bounded failed report before exiting when its tested package is unavailable' {
        $output = Join-Path $TestDrive 'report.json'
        $info = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        foreach ($argument in @('-NoProfile','-NonInteractive','-File',$script:QualificationScript,'-PackageKind','source','-SourceCommit',('a' * 40),'-OutputPath',$output)) { $info.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::Start($info)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Qualification failure receipt timed out.' }
            $process.ExitCode | Should -Not -Be 0
            $stdout.GetAwaiter().GetResult() | Should -Not -Match 'Qualification completed'
            $stderr.GetAwaiter().GetResult() | Should -Match 'qualification failed'
        }
        finally { $process.Dispose() }
        $report = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json -AsHashtable
        $report.package.sha256 | Should -BeNullOrEmpty
        $report.release | Should -BeNullOrEmpty
        foreach ($architecture in $report.architectures) {
            $architecture.distribution.outcome | Should -Be 'failed'
            @($architecture.distribution.checks | Where-Object { $_.id -eq 'package-acquisition' -and $_.outcome -eq 'failed' }).Count | Should -Be 1
            $architecture.credentialFreeCli.outcome | Should -Be 'not exercised'
            $architecture.localFleet.outcome | Should -Be 'not exercised'
            $architecture.connectedConsumer.outcome | Should -Be 'not exercised'
        }
        $report.Keys | Should -Not -Contain 'stdout'
        $report.Keys | Should -Not -Contain 'stderr'
    }
}
