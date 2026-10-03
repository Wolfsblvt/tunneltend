BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'TunnelTend utility contracts' {
    It 'accepts only complete secret references' {
        (& $script:Module { Test-TtSecretReference 'env:CONTROL_PLANE_API_KEY' }) | Should -BeTrue
        (& $script:Module { Test-TtSecretReference 'file:C:\secure\runtime-key.txt' }) | Should -BeTrue
        (& $script:Module { Test-TtSecretReference 'env:CONTROL_PLANE_API_KEY extra' }) | Should -BeFalse
        (& $script:Module { Test-TtSecretReference "env:CONTROL_PLANE_API_KEY`n" }) | Should -BeFalse
    }

    It 'renders command targets with the official POSIX-like quoting contract' {
        $actual = & $script:Module {
            ConvertTo-TtCommandString -File 'C:\Program Files\node.exe' -Arguments @('server path.js', "owner's")
        }
        $actual | Should -Be "'C:\Program Files\node.exe' 'server path.js' 'owner'\''s'"
    }

    It 'places the persistent JSON flag on the selected runtimes subcommand' {
        $arguments = & $script:Module {
            $registry = New-TtDefaultRegistry
            $service = New-TtServiceDefinition `
                -Id 'docs-mcp' `
                -Mcp @{ kind = 'url'; url = 'http://127.0.0.1:3001/mcp' } `
                -TunnelId 'tunnel_docs' `
                -SourceWatch $false `
                -Defaults $registry.settings.defaults
            Get-TtConnectArguments $service
        }

        $arguments[0..2] | Should -Be @('runtimes', 'connect', '--alias')
        $arguments[-1] | Should -Be '--json'
    }

    It 'ignores blank service selectors instead of manufacturing an empty id' {
        $selected = & $script:Module {
            Resolve-TtServiceSelection -ServiceId @('', '  ') -Services ([ordered]@{ alpha = @{}; beta = @{} })
        }
        $selected | Should -Be @('alpha', 'beta')
    }

    It 'keeps boolean options from consuming positional commands and service ids' {
        $parsed = & $script:Module {
            Parse-TtCliArguments @('--json', 'status', 'demo', '--force')
        }
        @($parsed.positionals) | Should -Be @('status', 'demo')
        $parsed.options.json | Should -BeTrue
        $parsed.options.force | Should -BeTrue
    }

    It 'does not create an absent state root during read-only operations' {
        $state = Join-Path ([IO.Path]::GetTempPath()) ('tt-pester-readonly-' + [Guid]::NewGuid().ToString('N'))
        try {
            & $script:Module {
                param($root)
                Set-Item Function:Get-TtOfficialClientVersion -Value { [ordered]@{ installed = $false; version = $null; path = 'missing'; error = 'missing' } }
                Set-Item Function:Test-TtOfficialClientCapabilities -Value { [ordered]@{ compatible = $false; checks = @() } }
                Set-Item Function:Get-TtAutomationStatusInternal -Value { [ordered]@{ supported = $false; tasks = @(); desired = @() } }
                Get-TtStatus -StateRoot $root | Out-Null
                Get-TtHealth -StateRoot $root | Out-Null
                Invoke-TtDoctor -StateRoot $root | Out-Null
            } $state
            Test-Path -LiteralPath $state | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $state -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}