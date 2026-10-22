BeforeAll {
    $script:Online = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../scripts/Install-TunnelTend-Online.ps1'))
    $work = Join-Path $TestDrive 'online'
    $payload = Join-Path $work 'payload'
    New-Item -ItemType Directory -Path (Join-Path $payload 'scripts') -Force | Out-Null
    # A stand-in installer that reports how its parameters were bound. The bootstrap is the
    # real script; only the network and the release payload are replaced.
    Set-Content -LiteralPath (Join-Path $payload 'scripts/Install-TunnelTend.ps1') -Value @'
[CmdletBinding(SupportsShouldProcess)]
param([string]$InstallRoot,[switch]$NonInteractive,[switch]$DisableAutoUpdate,[string[]]$AutostartAliases,[string[]]$RegisterPath,[switch]$Fail)
if ($Fail) { throw 'installer failed on purpose' }
[Console]::Out.WriteLine(('BOUND ' + (@{ InstallRoot = $InstallRoot; NonInteractive = [bool]$NonInteractive; DisableAutoUpdate = [bool]$DisableAutoUpdate; AutostartAliases = @($AutostartAliases); RegisterPath = @($RegisterPath); WhatIf = [bool]$WhatIfPreference } | ConvertTo-Json -Compress)))
'@
    $script:Zip = Join-Path $work 'tunneltend-9.9.9.zip'
    Compress-Archive -Path (Join-Path $payload '*') -DestinationPath $script:Zip
    Set-Content -LiteralPath "$script:Zip.sha256" -Value "$((Get-FileHash -LiteralPath $script:Zip -Algorithm SHA256).Hash.ToLowerInvariant())  tunneltend-9.9.9.zip"
    $script:Work = $work

    # Runs the served script the documented way (a script block built from its text) in a
    # child PowerShell, with the two web cmdlets answered from the local release.
    function script:Invoke-Bootstrap([string]$ArgumentText) {
        $harness = Join-Path $script:Work 'harness.ps1'
        Set-Content -LiteralPath $harness -Value @'
param([string]$Online,[string]$Zip,[string]$DownloadRoot)
function Invoke-RestMethod {
    param($Uri,$Headers,$MaximumRedirection)
    [pscustomobject]@{
        draft = $false; prerelease = $false; tag_name = 'v9.9.9'
        assets = @(
            [pscustomobject]@{ name = 'tunneltend-9.9.9.zip'; size = 1024; browser_download_url = 'https://github.com/Wolfsblvt/tunneltend/releases/download/v9.9.9/tunneltend-9.9.9.zip' }
            [pscustomobject]@{ name = 'tunneltend-9.9.9.zip.sha256'; size = 100; browser_download_url = 'https://github.com/Wolfsblvt/tunneltend/releases/download/v9.9.9/tunneltend-9.9.9.zip.sha256' }
        )
    }
}
function Invoke-WebRequest {
    param($Uri,$Headers,$OutFile,$MaximumRedirection)
    $source = if ("$Uri".EndsWith('.sha256')) { "$Zip.sha256" } else { $Zip }
    Copy-Item -LiteralPath $source -Destination $OutFile
}
$bootstrap = [scriptblock]::Create((Get-Content -Raw -LiteralPath $Online))
# Typed the way a user types it, so lists and quoting go through the PowerShell parser.
$typed = [scriptblock]::Create("param(`$bootstrap,`$DownloadRoot) & `$bootstrap -DownloadRoot `$DownloadRoot $env:TT_BOOTSTRAP_ARGUMENTS")
& $typed $bootstrap $DownloadRoot
'@
        $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $downloadRoot = Join-Path $script:Work ('downloads-' + [Guid]::NewGuid().ToString('N'))
        foreach ($argument in @('-NoProfile','-NonInteractive','-File',$harness,$script:Online,$script:Zip,$downloadRoot)) { $start.ArgumentList.Add($argument) }
        $start.Environment['TT_BOOTSTRAP_ARGUMENTS'] = $ArgumentText
        $process = [Diagnostics.Process]::Start($start)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(60000)) { $process.Kill($true); throw 'Bootstrap specimen timed out.' }
            [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.GetAwaiter().GetResult(); Error = $stderr.GetAwaiter().GetResult() }
        }
        finally { $process.Dispose() }
    }

    function script:Get-Bound($Result) {
        $line = @($Result.Output -split '\r?\n' | Where-Object { $_ -like 'BOUND *' })
        $line.Count | Should -Be 1 -Because "output: $($Result.Output) error: $($Result.Error)"
        $line[0].Substring(6) | ConvertFrom-Json -AsHashtable
    }
}

Describe 'Online installer bootstrap' {
    It 'forwards named switches to the ordinary installer instead of treating them as positional values' {
        $result = Invoke-Bootstrap '-NonInteractive -DisableAutoUpdate'
        $result.ExitCode | Should -Be 0 -Because $result.Error
        $bound = Get-Bound $result
        $bound.NonInteractive | Should -BeTrue
        $bound.DisableAutoUpdate | Should -BeTrue
        $bound.InstallRoot | Should -BeNullOrEmpty
    }
    It 'forwards values, lists and common parameters to the parameters they name' {
        $result = Invoke-Bootstrap '-InstallRoot ''C:\Disposable Programs\TunnelTend'' -AutostartAliases one,two -RegisterPath C:\src\a -WhatIf'
        $result.ExitCode | Should -Be 0 -Because $result.Error
        $bound = Get-Bound $result
        $bound.InstallRoot | Should -Be 'C:\Disposable Programs\TunnelTend'
        $bound.AutostartAliases | Should -Be @('one','two')
        $bound.RegisterPath | Should -Be @('C:\src\a')
        $bound.WhatIf | Should -BeTrue
        $bound.NonInteractive | Should -BeFalse
    }
    It 'runs the installer with no arguments and stays out of its way' {
        $result = Invoke-Bootstrap ''
        $result.ExitCode | Should -Be 0 -Because $result.Error
        (Get-Bound $result).NonInteractive | Should -BeFalse
    }
    It 'keeps its own parameters and does not install under NoInstall' {
        $result = Invoke-Bootstrap '-NoInstall -NonInteractive'
        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match 'not installing'
        $result.Output | Should -Not -Match 'BOUND '
    }
    It 'fails visibly with the installer error and a nonzero exit when the installer fails' {
        $result = Invoke-Bootstrap '-Fail'
        $result.ExitCode | Should -Not -Be 0
        $result.Error | Should -Match 'installer failed on purpose'
        $result.Output | Should -Not -Match 'done\.'
    }
}
