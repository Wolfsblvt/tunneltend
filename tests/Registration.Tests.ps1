BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
}

Describe 'Service configuration secret ingress' {
    It 'refuses credential-bearing direct input through <name> before persistence' -ForEach @(
        @{name='url';options=@{Url='https://fixture-user:fixture-password@example.test/mcp'}}
        @{name='userinfo';options=@{Url='https://fixture-token@example.test/mcp'}}
        @{name='health';options=@{Url='http://127.0.0.1:1/mcp';HealthUrl='https://example.test/health?api_key=fixture-only'}}
        @{name='readiness';options=@{Url='http://127.0.0.1:1/mcp';ReadyUrl='https://example.test/ready?password=fixture-only'}}
        @{name='command';options=@{Command='fixture.exe';Argument=@('--secret=fixture-only')}}
    ) {
        $root = Join-Path $TestDrive ('direct-' + $name)

        { Register-TtService -Id demo @options -NoStart -StateRoot $root } | Should -Throw '*inline secret*'

        Test-Path -LiteralPath (Join-Path $root 'registry.json') | Should -BeFalse
    }

    It 'does not persist secret-bearing configuration edits to <field>' -ForEach @(
        @{field='mcp.url';value='https://fixture-user:fixture-password@example.test/mcp'}
        @{field='health.url';value='https://example.test/health?api_key=fixture-only'}
        @{field='health.readyUrl';value='https://example.test/ready?password=fixture-only'}
        @{field='host.arguments';value=@('--password=fixture-only')}
        @{field='update.command.arguments';value=@('--access-token=fixture-only')}
    ) {
        $root = Join-Path $TestDrive ('edit-' + $field.Replace('.', '-'))
        Register-TtService -Id demo -Url 'http://127.0.0.1:1/mcp' -NoStart -StateRoot $root | Out-Null
        $before = (Get-FileHash -LiteralPath (Join-Path $root 'registry.json')).Hash

        { Set-TtConfiguration -Path "services.demo.$field" -Value $value -StateRoot $root } | Should -Throw '*inline secret*'

        (Get-FileHash -LiteralPath (Join-Path $root 'registry.json')).Hash | Should -Be $before
    }

    It 'retains ordinary HTTP and command services with environment and file credential references' {
        $root = Join-Path $TestDrive 'references'
        Register-TtService -Id http -Url 'http://127.0.0.1:1/mcp' -RuntimeKeyRef 'env:FIXTURE_RUNTIME_KEY' -NoStart -StateRoot $root | Out-Null
        Register-TtService -Id command -Command 'fixture.exe' -RuntimeKeyRef 'file:C:\fixture\runtime-key.txt' -NoStart -StateRoot $root | Out-Null
        Set-TtConfiguration -Path 'services.command.mcp.command.environment' -Value @{FIXTURE_KEY='env:FIXTURE_SERVICE_KEY'} -StateRoot $root | Out-Null

        (Get-TtService -Id http -StateRoot $root).mcp.kind | Should -Be 'url'
        (Get-TtService -Id command -StateRoot $root).mcp.command.environment.FIXTURE_KEY | Should -Be 'env:FIXTURE_SERVICE_KEY'
    }
}
