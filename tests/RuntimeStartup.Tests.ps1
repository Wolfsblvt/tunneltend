BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'Official runtime startup admission' {
    BeforeEach {
        $script:Registry = & $script:Module {
            $r = New-TtDefaultRegistry
            $r.services.demo = New-TtServiceDefinition -Id demo -TunnelId tunnel_demo -SourceWatch $false -Defaults $r.settings.defaults -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'}
            $r.services.demo.health.startupTimeoutSeconds = 1
            $r
        }
        $script:Runtime = & $script:Module { New-TtDefaultRuntimeStore }
        $script:ConnectCode = 2
        $script:ConnectPayload = @{alias='demo';tunnel=@{id='tunnel_demo'};launched=$true;process_running=$true;runtime_state='starting';healthy=$false;ready=$false}
        $script:StatusStates = [Collections.Generic.Queue[string]]::new()
        $script:FinalState = 'ready'
        Mock Get-TtOfficialRuntimeList -ModuleName TunnelTend { @{aliases=@()} }
        Mock Stop-TtOfficialRuntime -ModuleName TunnelTend {}
        Mock Write-TtLog -ModuleName TunnelTend {}
        # Double only the external CLI boundary. JSON parsing, admission,
        # observation, bounded waiting and managed startup remain real.
        Mock Invoke-TtOfficialClient -ModuleName TunnelTend {
            param($Arguments)
            if ($Arguments[1] -eq 'connect') {
                return @{exit_code=$script:ConnectCode;stdout=($script:ConnectPayload | ConvertTo-Json -Depth 10 -Compress);stderr=''}
            }
            if ($Arguments[1] -ne 'status') { throw "Unexpected official command: $Arguments" }
            $state = if ($script:StatusStates.Count) { $script:StatusStates.Dequeue() } else { $script:FinalState }
            $running = $state -notin @('stopped','wrong-identity')
            # A stale health URL can answer while the recorded process no
            # longer has its owned identity; it must not complete startup.
            $healthy = $state -in @('healthy','ready','wrong-identity')
            $payload = @{alias='demo';tunnel_id='tunnel_demo';runtime_state=$state;process_running=$running;healthy=$healthy;ready=($state -in @('ready','wrong-identity'))}
            @{exit_code=0;stdout=($payload | ConvertTo-Json -Compress);stderr=''}
        }
    }

    It 'waits through launched starting and healthy-but-unready status before reporting ready' {
        $script:StatusStates.Enqueue('starting')
        $script:StatusStates.Enqueue('healthy')
        $script:Registry.services.demo.health.startupTimeoutSeconds = 5
        $result = & $script:Module { param($r,$s,$root) Start-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $TestDrive
        $result.ready | Should -BeTrue
        Should -Invoke Invoke-TtOfficialClient -ModuleName TunnelTend -Exactly 3 -ParameterFilter { $Arguments[1] -eq 'status' }
        $script:Runtime.services.demo.recovery.lastResult | Should -Be 'healthy'
    }

    It 'carries the same admission through an ordinary restart' {
        $result = & $script:Module { param($r,$s,$root) Restart-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $TestDrive
        $result.ready | Should -BeTrue
        Should -Invoke Invoke-TtOfficialClient -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Arguments[1] -eq 'connect' }
    }

    It 'refuses a nonzero connect with <reason> before polling' -ForEach @(
        @{reason='an ordinary command error';field='code';value=1},
        @{reason='no launch';field='launched';value=$false},
        @{reason='a string launch flag';field='launched';value='true'},
        @{reason='no running process';field='process_running';value=$false},
        @{reason='a string running flag';field='process_running';value='true'},
        @{reason='a stopped state';field='runtime_state';value='stopped'},
        @{reason='a different alias';field='alias';value='other'},
        @{reason='a different tunnel';field='tunnel';value=@{id='other'}},
        @{reason='no structured payload';field='payload';value=$null}
    ) {
        if ($field -eq 'code') { $script:ConnectCode = $value }
        elseif ($field -eq 'payload') { $script:ConnectPayload = $value }
        else { $script:ConnectPayload[$field] = $value }
        { & $script:Module { param($r,$s,$root) Start-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*connect failed*'
        Should -Invoke Invoke-TtOfficialClient -ModuleName TunnelTend -Exactly 0 -ParameterFilter { $Arguments[1] -eq 'status' }
    }

    It 'fails bounded observation when the runtime stays <state>' -ForEach @(
        @{state='starting'}, @{state='healthy'}, @{state='stopped'}, @{state='wrong-identity'}
    ) {
        $script:FinalState = $state
        { & $script:Module { param($r,$s,$root) Start-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $TestDrive } | Should -Throw '*after startup*'
        $script:Runtime.services.demo.recovery.lastResult | Should -Not -Be 'healthy'
    }

    Context 'Client replacement and rollback use real managed startup' {
        BeforeEach {
            $script:Registry.settings.officialClient.installDirectory = Join-Path $TestDrive 'client'
            $script:Registry.settings.officialClient.executablePath = Join-Path $TestDrive 'client/tunnel-client.exe'
            New-Item -ItemType Directory $script:Registry.settings.officialClient.installDirectory -Force | Out-Null
            Set-Content -LiteralPath $script:Registry.settings.officialClient.executablePath -Value 'previous client'
            $script:Runtime.session.activeServices = @('demo')
            Mock Test-TtOfficialClientNeedsUpdate -ModuleName TunnelTend { @{needed=$true;latestVersion='0.0.16';installed=@{version='0.0.15'}} }
            Mock Get-TtOfficialClientVersion -ModuleName TunnelTend { @{installed=$true;version='0.0.16'} }
            Mock Test-TtOfficialClientCapabilities -ModuleName TunnelTend { @{compatible=$true} }
            Mock Invoke-TtBundledUpdater -ModuleName TunnelTend {
                param($Registry)
                New-Item -ItemType Directory $Registry.settings.officialClient.installDirectory -Force | Out-Null
                Set-Content -LiteralPath $Registry.settings.officialClient.executablePath -Value 'replacement client'
                @{exit_code=0;stdout='';stderr=''}
            }
        }

        It 'keeps the replacement when a launched fleet runtime becomes ready' {
            $result = & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root -Force } $script:Registry $script:Runtime $TestDrive
            $result.changed | Should -BeTrue
            $result.restoredServices | Should -Contain demo
            (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'replacement client'
        }

        It 'reports replacement failure while allowing the rolled-back runtime to settle' {
            Mock Invoke-TtOfficialClient -ModuleName TunnelTend {
                param($Arguments,$Registry)
                $replacement = (Get-Content -Raw $Registry.settings.officialClient.executablePath).Trim() -eq 'replacement client'
                if ($Arguments[1] -eq 'connect') {
                    if ($replacement) { return @{exit_code=1;stdout='';stderr='replacement refused'} }
                    return @{exit_code=2;stdout=($script:ConnectPayload | ConvertTo-Json -Depth 10 -Compress);stderr=''}
                }
                @{exit_code=0;stdout='{"alias":"demo","tunnel_id":"tunnel_demo","process_running":true,"healthy":true,"ready":true,"runtime_state":"ready"}';stderr=''}
            }
            $failure = $null
            try { & $script:Module { param($r,$s,$root) Invoke-TtOfficialClientUpdateInternal $r $s $root -Force } $script:Registry $script:Runtime $TestDrive }
            catch { $failure = $_.Exception.Message }
            $failure | Should -BeLike '*fleet restoration failed*replacement refused*'
            $failure | Should -Not -BeLike '*recovery was incomplete*'
            (Get-Content -Raw $script:Registry.settings.officialClient.executablePath).Trim() | Should -Be 'previous client'
            Should -Invoke Invoke-TtOfficialClient -ModuleName TunnelTend -Exactly 2 -ParameterFilter { $Arguments[1] -eq 'connect' }
        }
    }
}
