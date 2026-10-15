BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module=Get-Module TunnelTend
}
Describe 'TunnelTend state model' {
    It 'uses the installed state root while preserving an explicit environment override' {
        $program = Join-Path $TestDrive 'program'
        $selected = Join-Path $TestDrive 'selected-state'
        New-Item -ItemType Directory -Path (Join-Path $program 'src/TunnelTend') -Force | Out-Null
        @{ stateRoot = $selected } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $program 'install.json')
        & $script:Module {
            param($program, $selected, $override)
            $previousModuleRoot = $script:TtModuleRoot
            $previousEnvironment = $env:TUNNELTEND_STATE_DIR
            try {
                $script:TtModuleRoot = Join-Path $program 'src/TunnelTend'
                $env:TUNNELTEND_STATE_DIR = $null
                Get-TtDefaultStateRoot | Should -Be $selected
                $env:TUNNELTEND_STATE_DIR = $override
                Get-TtDefaultStateRoot | Should -Be $override
            }
            finally {
                $script:TtModuleRoot = $previousModuleRoot
                $env:TUNNELTEND_STATE_DIR = $previousEnvironment
            }
        } $program $selected (Join-Path $TestDrive 'explicit-override')
    }

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
