BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:QuietModule = Get-Module TunnelTend
    $script:QuietFixture = Join-Path $PSScriptRoot 'Fixtures/quiet-process.ps1'
    $script:QuietPowerShell = & $script:QuietModule { Get-TtPowerShellExecutable }
    $script:QuietLauncher = & $script:QuietModule { param($root) Get-TtWindowsLauncherPath $root } $TestDrive
}

Describe 'Quiet Windows process and task boundary' {
    It 'builds a GUI executable and constructs every task mode through it on repeated registration' {
        $bytes = [IO.File]::ReadAllBytes($script:QuietLauncher)
        $pe = [BitConverter]::ToInt32($bytes, 60)
        [BitConverter]::ToUInt16($bytes, $pe + 92) | Should -Be 2
        foreach ($pass in 1..2) {
            foreach ($mode in @('startup','watchdog','maintenance')) {
                $action = & $script:QuietModule { param($mode,$root) New-TtScheduledTaskAction $mode $root } $mode $TestDrive
                $action.Execute | Should -Be $script:QuietLauncher
                $prefix = & $script:QuietModule { param($path) ConvertTo-TtCommandLine @($path) } $script:QuietPowerShell
                $action.Arguments | Should -BeLike ($prefix + ' *')
                $action.Arguments | Should -BeLike ('* automation ' + $mode + ' *')
            }
        }
    }

    It 'preserves stdout stderr exit and script argument boundaries without a console' {
        $result = & $script:QuietModule {
            param($launcher,$powerShell,$fixture)
            Invoke-TtProcess -FilePath $launcher -ArgumentList @($powerShell,'-NoProfile','-NonInteractive','-File',$fixture,'probe','','','','a b','') -AllowFailure
        } $script:QuietLauncher $script:QuietPowerShell $script:QuietFixture
        $result.exit_code | Should -Be 23
        $result.stderr.Trim() | Should -Be 'fixture-error'
        $payload = $result.stdout | ConvertFrom-Json
        $payload.console | Should -Be 0
        @($payload.arguments) | Should -Be @('a b','')
    }

    It 'quietly launches configured PowerShell without reinterpreting script flags' {
        $result = & $script:QuietModule {
            param($powerShell,$fixture)
            Invoke-TtProcess -FilePath $powerShell -ArgumentList @('-File',$fixture,'probe','','','','-WindowStyle','Normal') -AllowFailure
        } $script:QuietPowerShell $script:QuietFixture
        $result.exit_code | Should -Be 23
        ($result.stdout | ConvertFrom-Json).console | Should -Be 0
        @(($result.stdout | ConvertFrom-Json).arguments) | Should -Be @('-WindowStyle','Normal')
        $result.arguments[0..3] | Should -Be @('-NoProfile','-NonInteractive','-WindowStyle','Hidden')
    }

    It 'preserves a detached host after normal script exit or launcher cancellation' -ForEach @(@{mode='detach-exit'},@{mode='detach-wait'}) {
        $root = Join-Path $TestDrive $mode
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $info = [Diagnostics.ProcessStartInfo]::new($script:QuietLauncher)
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        foreach ($argument in @($script:QuietPowerShell,'-NoProfile','-NonInteractive','-File',$script:QuietFixture,$mode,$root,$script:QuietModule.Path,$script:QuietPowerShell)) { [void]$info.ArgumentList.Add($argument) }
        $launcher = [Diagnostics.Process]::Start($info)
        # Public PowerShell/package startup and module loading are setup, not a
        # protocol timeout. Use the product's ordinary startup observation bound.
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
        try {
            while (-not [IO.File]::Exists((Join-Path $root 'script.json')) -and [DateTimeOffset]::UtcNow -lt $deadline) {
                if ([IO.File]::Exists((Join-Path $root 'error.txt'))) { throw [IO.File]::ReadAllText((Join-Path $root 'error.txt')) }
                if ($launcher.HasExited) { throw "Fixture script exited without its identity receipt (exit $($launcher.ExitCode))." }
                Start-Sleep -Milliseconds 50
            }
            $scriptRecord = Get-Content -Raw -LiteralPath (Join-Path $root 'script.json') | ConvertFrom-Json -AsHashtable
            if ($mode -eq 'detach-wait') {
                $scriptProcess = [Diagnostics.Process]::GetProcessById($scriptRecord.pid)
                try {
                    $launcher.Kill()
                    $launcher.WaitForExit(5000) | Should -BeTrue
                    $scriptProcess.WaitForExit(5000) | Should -BeTrue
                }
                finally { $scriptProcess.Dispose() }
            }
            else {
                $launcher.WaitForExit(5000) | Should -BeTrue
                $launcher.ExitCode | Should -Be 23
            }
            [IO.File]::WriteAllText((Join-Path $root 'release-host.txt'), 'released after launcher exit')
            while (-not [IO.File]::Exists((Join-Path $root 'host-finished.txt')) -and [DateTimeOffset]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
            Get-Content -LiteralPath (Join-Path $root 'host-finished.txt') | Should -Be 'survived'
        }
        finally {
            [IO.File]::WriteAllText((Join-Path $root 'release-host.txt'), 'released for fixture cleanup')
            if (-not $launcher.HasExited) { $launcher.Kill(); $launcher.WaitForExit() }
            $launcher.Dispose()
            # These finite children can exit between an identity check and a
            # termination call. Release the host and wait without racing a kill.
            foreach ($name in @('script.json','host.json')) {
                if ([IO.File]::Exists((Join-Path $root $name))) {
                    & $script:QuietModule {
                        param($path)
                        $record = Read-TtJsonFile $path
                        $child = Get-Process -Id $record.pid -ErrorAction SilentlyContinue
                        if ($child) {
                            try { if (Test-TtOwnedProcess $record) { $child.WaitForExit(60000) | Should -BeTrue } }
                            finally { $child.Dispose() }
                        }
                    } (Join-Path $root $name)
                }
            }
        }
    }
}
