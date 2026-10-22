BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
}

Describe 'CLI command argument preservation' {
    It 'persists repeated arguments literally while retaining comma-separated scope selectors' {
        Mock Write-TtCliResult -ModuleName TunnelTend {}
        $root = Join-Path $TestDrive 'literal-arguments'
        $expected = @('a,b', '  padded  ', '', 'say "hello"', 'C:\trailing\', '--literal')
        $arguments = @('service','register','--command','fixture.exe','--id','literal','--no-start','--state-root',$root,'--organization-id','org_one,org_two')
        foreach ($value in $expected) { $arguments += "--arg=$value" }

        Invoke-TtCli $arguments | Should -Be 0

        $service = Get-TtService -Id literal -StateRoot $root
        @($service.mcp.command.arguments).Count | Should -Be $expected.Count
        for ($index = 0; $index -lt $expected.Count; $index++) {
            $service.mcp.command.arguments[$index] | Should -BeExactly $expected[$index]
        }
        $service.tunnel.organizationIds | Should -Be @('org_one','org_two')
    }
}

Describe 'CLI convergence reporting' {
    BeforeEach {
        Mock Write-TtCliResult -ModuleName TunnelTend {}
    }

    It 'returns degraded and a diagnostic when reconciliation fails without a mutation' {
        Mock Invoke-TtReconcile -ModuleName TunnelTend { @{changed=$false;plan=@{actions=@()};results=@(@{serviceId='demo';action='start';ok=$false;error='Synthetic startup failure'})} }

        Invoke-TtCli @('reconcile','--json') | Should -Be 2

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter {
            $Envelope.status -eq 'degraded' -and @($Envelope.diagnostics).Count -eq 1 -and $Envelope.diagnostics[0].message -match 'Synthetic startup failure' -and -not $Envelope.data.results[0].ok
        }
    }

    It 'keeps partial fleet progress visible while returning failure' {
        Mock Invoke-TtReconcile -ModuleName TunnelTend { @{changed=$true;plan=@{actions=@()};results=@(@{serviceId='one';ok=$true},@{serviceId='two';ok=$false;error='Synthetic second-service failure'})} }

        Invoke-TtCli @('reconcile','--json') | Should -Be 2

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'degraded' -and $Envelope.data.changed -and $Envelope.data.results.Count -eq 2 }
    }

    It 'does not announce successful repair application after failed convergence' {
        Mock Invoke-TtRepair -ModuleName TunnelTend { @{changed=$false;results=@(@{serviceId='demo';ok=$false;error='Synthetic repair failure'})} }

        Invoke-TtCli @('repair','--apply','--json') | Should -Be 2

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'degraded' }
    }

    It 'exposes a caught startup client-update failure' {
        Mock Invoke-TtStartup -ModuleName TunnelTend { @{mode='startup';session=@{id='new-session'};update=@{changed=$false;error='Synthetic client update failure'};reconcile=@{changed=$false;results=@()}} }

        Invoke-TtCli @('automation','startup','--json') | Should -Be 2

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'degraded' -and @($Envelope.diagnostics).Count -eq 1 -and $Envelope.diagnostics[0].message -match 'Synthetic client update failure' }
    }

    It 'reports client and application-update failures while preserving successful updates' {
        Mock Invoke-TtMaintenance -ModuleName TunnelTend {
            @{mode='maintenance';clientUpdate=@{changed=$false;error='Synthetic client failure'};serviceUpdates=@(@{serviceId='one';updated=$false;error='Synthetic application failure'},@{serviceId='two';updated=$true});reconcile=@{changed=$false;results=@()}}
        }

        Invoke-TtCli @('automation','maintenance','--json') | Should -Be 2

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'degraded' -and @($Envelope.diagnostics).Count -eq 2 -and $Envelope.data.serviceUpdates[1].updated }
    }

    It 'reports a normal recovery-policy deferral without inventing a failed operation' {
        Mock Invoke-TtWatchdog -ModuleName TunnelTend { @{mode='watchdog';reconcile=@{changed=$false;results=@(@{serviceId='demo';ok=$false;skipped=$true;reason='backoff'})}} }

        Invoke-TtCli @('automation','watchdog','--json') | Should -Be 0

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'noop' -and @($Envelope.diagnostics).Count -eq 1 -and $Envelope.diagnostics[0].code -eq 'operation.skipped' -and $Envelope.data.reconcile.results[0].skipped }
    }

    It 'does not claim a maintenance change when there was no update or reconciliation change' {
        Mock Invoke-TtMaintenance -ModuleName TunnelTend { @{mode='maintenance';clientUpdate=@{changed=$false};serviceUpdates=@();reconcile=@{changed=$false;results=@()}} }

        Invoke-TtCli @('automation','maintenance','--json') | Should -Be 0

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'noop' }
    }

    It 'reports a successfully established startup session as a real state change' {
        Mock Invoke-TtStartup -ModuleName TunnelTend { @{mode='startup';session=@{id='new-session'};update=$null;reconcile=@{changed=$false;results=@()}} }

        Invoke-TtCli @('automation','startup','--json') | Should -Be 0

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'changed' }
    }

    It 'keeps a read-only reconciliation preview planned even when it identifies an error' {
        Mock Invoke-TtReconcile -ModuleName TunnelTend { @{changed=$false;plan=@{actions=@(@{serviceId='demo';action='error';reason='configuration-invalid'})};results=@()} }

        Invoke-TtCli @('reconcile','--plan','--json') | Should -Be 0

        Should -Invoke Write-TtCliResult -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Envelope.status -eq 'planned' }
    }
}

Describe 'CLI human-readable rendering' {
    BeforeAll {
        # Write-TtCliResult prints through [Console]::Out; capture it with a replacement writer.
        function Invoke-CapturedRender([hashtable]$Envelope) {
            $previous = [Console]::Out
            $writer = [IO.StringWriter]::new()
            try {
                [Console]::SetOut($writer)
                & (Get-Module TunnelTend) { param($envelope) Write-TtCliResult $envelope } $Envelope
            }
            finally { [Console]::SetOut($previous) }
            return $writer.ToString()
        }
    }

    It 'renders every status field of a service on one line' {
        $envelope = & (Get-Module TunnelTend) { New-TtEnvelope -Command status -Status degraded -Data ([ordered]@{ services=@([ordered]@{ id='demo'; desiredState='running'; observedState='stopped'; healthy=$false; autostart=$true; watchdog=$false }) }) }
        $text = Invoke-CapturedRender $envelope
        $text | Should -Match '^\[--\] demo\s+desired=running observed=stopped\s+autostart=True watchdog=False'
    }

    It 'renders health and doctor lines with all their arguments' {
        $health = & (Get-Module TunnelTend) { New-TtEnvelope -Command health -Data ([ordered]@{ healthy=$true; services=@([ordered]@{ serviceId='demo'; healthy=$true; ready=$false; state='running' }) }) }
        (Invoke-CapturedRender $health) | Should -Match 'demo\s+healthy=True ready=False state=running'
        $doctor = & (Get-Module TunnelTend) { New-TtEnvelope -Command doctor -Status degraded -Data $null -Diagnostics @([ordered]@{ severity='warning'; code='service.unhealthy'; message='Synthetic diagnosis' }) }
        (Invoke-CapturedRender $doctor) | Should -Match '^\[WARNING\] service\.unhealthy: Synthetic diagnosis'
    }
}
