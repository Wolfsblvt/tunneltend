BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:ContractModule = Get-Module TunnelTend
}

Describe 'Official CLI contract without cosmetic wording' {
    BeforeEach {
        Mock Invoke-TtOfficialClient -ModuleName TunnelTend {
            param($Arguments)
            $text = if ($Arguments[0] -eq '--version') { 'tunnel-client version 0.0.18' } else {
                'Different prose: --json --alias --mcp-command --mcp-server-url --runtime-api-key --tunnel-id --organization-id --workspace-id --admin-profile --profile --profile-dir'
            }
            @{exit_code=0;stdout=$text;stderr=''}
        }
        Mock Get-TtOfficialClientPath -ModuleName TunnelTend { 'unused.exe' }
        Mock Test-TtOfficialClientBehavior -ModuleName TunnelTend { @(@{id='list-json';ok=$true},@{id='status-missing';ok=$true},@{id='stop-missing';ok=$true}) }
    }

    It 'accepts changed help descriptions while retaining every required target flag' {
        $result = & $script:ContractModule { Test-TtOfficialClientCapabilities -Behavioral }
        $result.compatible | Should -BeTrue
        @($result.checks).Count | Should -Be 9
        Should -Invoke Test-TtOfficialClientBehavior -ModuleName TunnelTend -Exactly -Times 1
    }

    It 'refuses losing the URL target even when the command target remains' {
        Mock Invoke-TtOfficialClient -ModuleName TunnelTend { @{exit_code=0;stdout='0.0.18 --json --alias --mcp-command --runtime-api-key --tunnel-id --organization-id --workspace-id --admin-profile --profile --profile-dir';stderr=''} }
        $result = & $script:ContractModule { Test-TtOfficialClientCapabilities }
        $result.compatible | Should -BeFalse
        @($result.checks | Where-Object { $_.id -eq 'runtime-connect' -and -not $_.ok }).Count | Should -Be 1
        Should -Invoke Test-TtOfficialClientBehavior -ModuleName TunnelTend -Exactly -Times 0
    }

    It 'refuses a changed structured behavior despite all help checks passing' {
        Mock Test-TtOfficialClientBehavior -ModuleName TunnelTend { @(@{id='list-json';ok=$false}) }
        (& $script:ContractModule { Test-TtOfficialClientCapabilities -Behavioral }).compatible | Should -BeFalse
    }
}
