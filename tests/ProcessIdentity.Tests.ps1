BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:IdentityModule = Get-Module TunnelTend
}

Describe 'Persisted process generation identity' {
    It 'recognizes the same live process through the actual runtime save and reload path' {
        & $script:IdentityModule {
            param($root)
            $runtime = New-TtDefaultRuntimeStore
            $record = Get-TtRuntimeServiceRecord $runtime 'identity-fixture' -Create
            $record.hostProcess = Get-TtProcessInfo $PID
            Save-TtRuntimeStore $runtime $root
            $reloaded = Get-TtRuntimeStore $root
            Test-TtOwnedProcess $reloaded.services['identity-fixture'].hostProcess | Should -BeTrue
        } $TestDrive
    }

    It 'compares timestamp instants without losing timezone or generation evidence' {
        Mock Get-TtProcessInfo -ModuleName TunnelTend {
            @{running=$true;executable_path='fixture-host.exe';start_time_utc='2026-10-16T12:34:56.1234567Z'}
        }
        & $script:IdentityModule {
            $instant = [DateTimeOffset]::Parse('2026-10-16T12:34:56.1234567Z')
            foreach ($representation in @($instant.UtcDateTime, $instant.LocalDateTime, $instant, $instant.ToOffset([TimeSpan]::FromHours(2)), $instant.ToString('o'))) {
                $record = @{pid=77777;executable_path='fixture-host.exe';start_time_utc=$representation}
                Test-TtOwnedProcess $record | Should -BeTrue
            }
            Test-TtOwnedProcess @{pid=77777;executable_path='fixture-host.exe';start_time_utc=$instant.AddMinutes(-1)} | Should -BeFalse
            Test-TtOwnedProcess @{pid=77777;executable_path='different-host.exe';start_time_utc=$instant} | Should -BeFalse
        }
    }

    It 'can stop its own bounded child using identity reloaded from runtime state' {
        & $script:IdentityModule {
            param($root)
            $owned = Start-TtDetachedProcess -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 15')
            try {
                # A just-created Windows process may not expose its executable
                # yet. Establish the live precondition before testing JSON.
                $deadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
                do {
                    $observable = Test-TtOwnedProcess $owned
                    if (-not $observable) { Start-Sleep -Milliseconds 50 }
                } while (-not $observable -and [DateTimeOffset]::UtcNow -lt $deadline)
                $observable | Should -BeTrue -Because 'the fixture must expose its original live identity before testing persistence'
                $runtime = New-TtDefaultRuntimeStore
                $record = Get-TtRuntimeServiceRecord $runtime 'child-fixture' -Create
                $record.hostProcess = $owned
                Save-TtRuntimeStore $runtime $root
                $reloaded = (Get-TtRuntimeStore $root).services['child-fixture'].hostProcess
                Test-TtOwnedProcess $reloaded | Should -BeTrue
                Stop-TtOwnedProcess $reloaded 0
                (Get-TtProcessInfo $owned.pid).running | Should -BeFalse
            }
            finally {
                # On a regression failure, only the original independently held
                # identity can clean up this finite fixture; never a bare PID.
                if (Test-TtOwnedProcess $owned) { Stop-TtOwnedProcess $owned 0 }
            }
        } $TestDrive
    }
}
