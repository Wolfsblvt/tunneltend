BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:ClientModule = Get-Module TunnelTend
}

Describe 'Client executable custody and explicit restore' {
    BeforeEach {
        $script:Registry = & $script:ClientModule {
            param($root)
            $r = New-TtDefaultRegistry
            $r.settings.officialClient.installDirectory = Join-Path $root 'shared-tools'
            $r.settings.officialClient.executablePath = Join-Path $root 'shared-tools/selected-client.exe'
            foreach ($id in @('alpha','beta','suppressed')) {
                $r.services[$id] = New-TtServiceDefinition -Id $id -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'} -TunnelId ('tunnel_'+$id) -Defaults $r.settings.defaults
            }
            $r
        } $TestDrive
        $script:Runtime = & $script:ClientModule { New-TtDefaultRuntimeStore }
        $script:Runtime.session.activeServices = @('alpha','beta','suppressed')
        $script:Runtime.session.suppressedServices = @('suppressed')
        New-Item -ItemType Directory -Path $script:Registry.settings.officialClient.installDirectory -Force | Out-Null
        Set-Content -LiteralPath $script:Registry.settings.officialClient.executablePath -Value 'current client'
        Set-Content -LiteralPath (Join-Path $script:Registry.settings.officialClient.installDirectory 'unrelated.txt') -Value 'keep this'
        $script:BackupPath = Join-Path $TestDrive 'restore-point'
        New-Item -ItemType Directory -Path $script:BackupPath -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:BackupPath 'selected-client.exe') -Value 'backup client'
        Set-Content -LiteralPath (Join-Path $script:BackupPath 'unrelated.txt') -Value 'obsolete sibling'
        @{createdAt='2026-10-16';version='0.0.15';installDirectory=$script:Registry.settings.officialClient.installDirectory} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:BackupPath 'tunneltend-backup.json')
        Mock Test-TtOfficialClientNeedsUpdate -ModuleName TunnelTend { @{needed=$true;latestVersion='0.0.16';installed=@{version='0.0.15'}} }
        Mock Get-TtOfficialClientVersion -ModuleName TunnelTend { @{installed=$true;version='0.0.16'} }
        Mock Test-TtOfficialClientCapabilities -ModuleName TunnelTend { @{compatible=$true} }
        Mock Get-TtServiceObservation -ModuleName TunnelTend { @{tunnel=@{running=$true};host=@{configured=$false;running=$false}} }
        Mock Stop-TtManagedService -ModuleName TunnelTend {}
        Mock Start-TtManagedService -ModuleName TunnelTend { @{healthy=$true} }
        Mock Invoke-TtBundledUpdater -ModuleName TunnelTend {
            param($Registry)
            New-Item -ItemType Directory -Path $Registry.settings.officialClient.installDirectory -Force | Out-Null
            Set-Content -LiteralPath $Registry.settings.officialClient.executablePath -Value 'updated client'
            @{exit_code=0;stderr='';stdout=''}
        }
    }

    It 'updates only the selected filename and backs up no unrelated sibling' {
        $result = & $script:ClientModule { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root } $script:Registry $script:Runtime $TestDrive
        $result.changed | Should -BeTrue
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'updated client'
        (Get-Content -Raw (Join-Path $script:Registry.settings.officialClient.installDirectory 'unrelated.txt')).Trim() | Should -Be 'keep this'
        Test-Path (Join-Path $script:Registry.settings.officialClient.installDirectory 'tunnel-client.exe') | Should -BeFalse
        @(Get-ChildItem -LiteralPath $result.backup -File).Count | Should -Be 2
        (Get-Content -Raw (Join-Path $result.backup 'tunnel-client.exe')).Trim() | Should -Be 'current client'
        $result.restoredServices | Should -Contain 'alpha'
        $result.restoredServices | Should -Contain 'beta'
        $result.restoredServices | Should -Not -Contain 'suppressed'
        $script:Runtime.session.suppressedServices | Should -Be @('suppressed')
        (& $script:ClientModule { param($root) Get-TtRuntimeStore $root } $TestDrive).session.suppressedServices | Should -Be @('suppressed')
    }

    It 'rolls back only client bytes and restores every intended service after update startup fails' {
        Mock Start-TtManagedService -ModuleName TunnelTend {
            param($Service,$Registry)
            if ($Service.id -eq 'alpha' -and (Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -eq 'updated client') { throw 'alpha update startup failed' }
            @{healthy=$true}
        }
        { & $script:ClientModule { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*alpha update startup failed*'
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'current client'
        (Get-Content -Raw (Join-Path $script:Registry.settings.officialClient.installDirectory 'unrelated.txt')).Trim() | Should -Be 'keep this'
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Exactly 2 -ParameterFilter { $Service.id -eq 'beta' }
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Exactly 0 -ParameterFilter { $Service.id -eq 'suppressed' }
    }

    It 'restores a legacy directory backup without reverting unrelated files or the selected name' {
        $result = & $script:ClientModule { param($r,$s,$root,$backup) Restore-TtOfficialClientBackupInternal $r $s $root $backup } $script:Registry $script:Runtime $TestDrive $script:BackupPath
        $result.restored | Should -BeTrue
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'backup client'
        (Get-Content -Raw (Join-Path $script:Registry.settings.officialClient.installDirectory 'unrelated.txt')).Trim() | Should -Be 'keep this'
        $result.services | Should -Be @('alpha','beta')
    }

    It 'keeps current bytes recoverable until all restore startups succeed and attempts later services' {
        Mock Start-TtManagedService -ModuleName TunnelTend {
            param($Service,$Registry)
            if ((Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -eq 'backup client') {
                @(Get-ChildItem -LiteralPath $Registry.settings.officialClient.installDirectory -Filter 'selected-client.exe.previous-*').Count | Should -Be 1
                if ($Service.id -eq 'alpha') { throw 'alpha restore startup failed' }
            }
            @{healthy=$true}
        }
        { & $script:ClientModule { param($r,$s,$root,$backup) Restore-TtOfficialClientBackupInternal $r $s $root $backup } $script:Registry $script:Runtime $TestDrive $script:BackupPath } | Should -Throw '*alpha restore startup failed*'
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'current client'
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Exactly 2 -ParameterFilter { $Service.id -eq 'beta' }
    }

    It 'returns the fleet to current bytes after the installed restore fails capabilities' {
        Mock Test-TtOfficialClientCapabilities -ModuleName TunnelTend {
            param($Registry)
            @{compatible=((Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -ne 'backup client' -or $Registry.settings.officialClient.executablePath -like '*restore-point*')}
        }
        { & $script:ClientModule { param($r,$s,$root,$backup) Restore-TtOfficialClientBackupInternal $r $s $root $backup } $script:Registry $script:Runtime $TestDrive $script:BackupPath } | Should -Throw '*capabilities*'
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'current client'
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Service.id -eq 'beta' }
    }

    It 'restores original bytes and attempts later services after restore startup fails' {
        Mock Start-TtManagedService -ModuleName TunnelTend {
            param($Service,$Registry)
            if ($Service.id -eq 'alpha' -and (Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -eq 'backup client') { throw 'alpha restore startup failed' }
            @{healthy=$true}
        }
        { & $script:ClientModule { param($r,$s,$root,$backup) Restore-TtOfficialClientBackupInternal $r $s $root $backup } $script:Registry $script:Runtime $TestDrive $script:BackupPath } | Should -Throw '*alpha restore startup failed*'
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'current client'
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Exactly 2 -ParameterFilter { $Service.id -eq 'beta' }
    }

    It 'leaves the fleet untouched when payload copying fails before replacement' {
        Mock Copy-Item -ModuleName TunnelTend { throw 'copy refused' } -ParameterFilter { $Destination -like '*.pending-*' }
        { & $script:ClientModule { param($r,$s,$root,$backup) Restore-TtOfficialClientBackupInternal $r $s $root $backup } $script:Registry $script:Runtime $TestDrive $script:BackupPath } | Should -Throw '*copy refused*'
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'current client'
        Should -Invoke Stop-TtManagedService -ModuleName TunnelTend -Exactly 0
    }

    It 'keeps fallback bytes and reports incomplete recovery when a replacement runtime refuses stop' {
        Mock Start-TtManagedService -ModuleName TunnelTend { throw 'startup failed' }
        Mock Stop-TtManagedService -ModuleName TunnelTend {
            param($Service,$Registry)
            if ((Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -eq 'backup client') { throw 'ownership refused' }
        }
        { & $script:ClientModule { param($r,$s,$root,$backup) Restore-TtOfficialClientBackupInternal $r $s $root $backup } $script:Registry $script:Runtime $TestDrive $script:BackupPath } | Should -Throw '*recovery was incomplete*ownership refused*'
        $fallback = @(Get-ChildItem -LiteralPath $script:Registry.settings.officialClient.installDirectory -Filter 'selected-client.exe.previous-*')
        $fallback.Count | Should -Be 1
        (Get-Content -Raw $fallback[0].FullName).Trim() | Should -Be 'current client'
        (Get-Content -Raw (Join-Path $script:Registry.settings.officialClient.installDirectory 'unrelated.txt')).Trim() | Should -Be 'keep this'
    }
}
