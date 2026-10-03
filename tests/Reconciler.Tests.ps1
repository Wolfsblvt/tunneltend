BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module=Get-Module TunnelTend
}
Describe 'TunnelTend reconciler policy' {
    It 'does not watchdog a session-suppressed service' {
        & $script:Module {
            $registry=New-TtDefaultRegistry
            $service=New-TtServiceDefinition -Id demo -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'} -TunnelId tunnel_demo -SourceWatch $false -Defaults $registry.settings.defaults
            $runtime=New-TtDefaultRuntimeStore
            $runtime.session.suppressedServices=@('demo')
            (Test-TtServiceDesiredRunning $service $runtime watchdog) | Should -BeFalse
        }
    }
    It 'allows startup only for autostart services' {
        & $script:Module {
            $registry=New-TtDefaultRegistry
            $service=New-TtServiceDefinition -Id demo -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'} -TunnelId tunnel_demo -SourceWatch $false -Autostart $false -Defaults $registry.settings.defaults
            $runtime=New-TtDefaultRuntimeStore
            (Test-TtServiceDesiredRunning $service $runtime startup) | Should -BeFalse
        }
    }
}
