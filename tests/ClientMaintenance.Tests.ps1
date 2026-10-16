BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'Official client maintenance transaction' {
    BeforeEach {
        $script:Registry = & $script:Module {
            param($root)
            $registry = New-TtDefaultRegistry
            $registry.settings.officialClient.installDirectory = Join-Path $root 'client'
            $registry.settings.officialClient.executablePath = Join-Path $root 'client/tunnel-client.exe'
            $registry.services.demo = New-TtServiceDefinition -Id demo -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'} -TunnelId tunnel_demo -Defaults $registry.settings.defaults
            $registry
        } $TestDrive
        New-Item -ItemType Directory -Path $script:Registry.settings.officialClient.installDirectory -Force | Out-Null
        Set-Content -LiteralPath $script:Registry.settings.officialClient.executablePath -Value 'previous client'
        $script:Runtime = & $script:Module { New-TtDefaultRuntimeStore }
        $script:Runtime.session.activeServices = @('demo')
        Mock Test-TtOfficialClientNeedsUpdate -ModuleName TunnelTend { @{ needed=$true; latestVersion='0.0.16'; installed=@{version='0.0.15'} } }
        Mock Get-TtServiceObservation -ModuleName TunnelTend { @{tunnel=@{running=$true};host=@{configured=$false;running=$false}} }
        Mock Save-TtRuntimeStore -ModuleName TunnelTend {}
        Mock Stop-TtManagedService -ModuleName TunnelTend {}
        Mock Start-TtManagedService -ModuleName TunnelTend { @{healthy=$true} }
        Mock Get-TtOfficialClientVersion -ModuleName TunnelTend { @{installed=$true;version='0.0.16'} }
        Mock Test-TtOfficialClientCapabilities -ModuleName TunnelTend { @{compatible=$true} }
    }

    It 'leaves the active fleet and installed bytes alone when staging fails' {
        Mock Invoke-TtBundledUpdater -ModuleName TunnelTend { @{exit_code=1;stderr='download refused';stdout=''} }
        { & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw
        Should -Invoke Stop-TtManagedService -ModuleName TunnelTend -Times 0 -Exactly
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'previous client'
    }

    It 'refuses an incompatible staged client before stopping services' {
        Mock Invoke-TtBundledUpdater -ModuleName TunnelTend { @{exit_code=0;stderr='';stdout=''} }
        Mock Test-TtOfficialClientCapabilities -ModuleName TunnelTend { @{compatible=$false} }
        { & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*capabilities*'
        Should -Invoke Stop-TtManagedService -ModuleName TunnelTend -Times 0 -Exactly
    }

    It 'refuses a staged version mismatch before stopping services' {
        Mock Invoke-TtBundledUpdater -ModuleName TunnelTend { @{exit_code=0;stderr='';stdout=''} }
        Mock Get-TtOfficialClientVersion -ModuleName TunnelTend { @{installed=$true;version='0.0.14'} }
        { & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*version*'
        Should -Invoke Stop-TtManagedService -ModuleName TunnelTend -Times 0 -Exactly
    }

    It 'allows an explicit same-version reinstall without downgrading' {
        Mock Test-TtOfficialClientNeedsUpdate -ModuleName TunnelTend { @{ needed=$false; latestVersion='0.0.16'; installed=@{version='0.0.16'} } }
        Mock Invoke-TtBundledUpdater -ModuleName TunnelTend {
            param($Registry)
            New-Item -ItemType Directory -Path $Registry.settings.officialClient.installDirectory -Force | Out-Null
            Set-Content -LiteralPath $Registry.settings.officialClient.executablePath -Value 'replacement client'
            @{exit_code=0;stderr='';stdout=''}
        }
        $result = & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root -Force } $script:Registry $script:Runtime $TestDrive
        $result.changed | Should -BeTrue
        $result.restoredServices | Should -Contain 'demo'
        Mock Test-TtOfficialClientNeedsUpdate -ModuleName TunnelTend { @{ needed=$false; latestVersion='0.0.15'; installed=@{version='0.0.16'} } }
        { & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root -Force } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*downgrade*'
        Should -Invoke Invoke-TtBundledUpdater -ModuleName TunnelTend -Times 1 -Exactly
    }

    It 'restores previous bytes and the fleet when replacement startup fails' {
        Mock Invoke-TtBundledUpdater -ModuleName TunnelTend {
            param($Registry)
            New-Item -ItemType Directory -Path $Registry.settings.officialClient.installDirectory -Force | Out-Null
            Set-Content -LiteralPath $Registry.settings.officialClient.executablePath -Value 'replacement client'
            @{exit_code=0;stderr='';stdout=''}
        }
        Mock Start-TtManagedService -ModuleName TunnelTend {
            param($Service,$Registry)
            if ((Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -eq 'replacement client') { throw 'replacement startup failed' }
            @{healthy=$true}
        }
        { & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*replacement startup failed*'
        (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'previous client'
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Times 2 -Exactly
    }
}
