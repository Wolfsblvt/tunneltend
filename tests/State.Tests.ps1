BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module=Get-Module TunnelTend
}
Describe 'TunnelTend state model' {
    It 'uses schema version one and autonomous defaults' {
        $registry=& $script:Module { New-TtDefaultRegistry }
        $registry.schemaVersion | Should -Be 1
        $registry.settings.automation.autostart | Should -BeTrue
        $registry.settings.automation.watchdog | Should -BeTrue
        $registry.settings.automation.autoUpdate | Should -BeTrue
    }
    It 'refuses raw runtime secrets' {
        { & $script:Module { Resolve-TtSecretReference 'not-a-reference' } } | Should -Throw
    }
    It 'normalizes ids' {
        (& $script:Module { ConvertTo-TtServiceId 'Docs_MCP' }) | Should -Be 'docs-mcp'
    }
    It 'keeps absent tunnel scopes as empty arrays' {
        $service = & $script:Module {
            $registry = New-TtDefaultRegistry
            New-TtServiceDefinition -Id demo -Mcp @{ kind = 'url'; url = 'http://127.0.0.1:1/mcp' } -TunnelId tunnel_demo -SourceWatch $false -Defaults $registry.settings.defaults
        }
        @($service.tunnel.organizationIds).Count | Should -Be 0
        @($service.tunnel.workspaceIds).Count | Should -Be 0
    }
}
