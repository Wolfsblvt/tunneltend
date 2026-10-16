BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module=Get-Module TunnelTend
}

Describe 'Managed lifecycle ownership and intent' {
    BeforeEach {
        $script:StateRoot = Join-Path $TestDrive 'lifecycle-state'
        $script:Registry = & $script:Module {
            param($root)
            $registry = [hashtable](New-TtDefaultRegistry $root)
            $registry.services.demo = New-TtServiceDefinition -Id demo -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'} -TunnelId tunnel_demo -SourceWatch $false -Defaults $registry.settings.defaults -Host @{
                enabled=$true;file=(Get-Process -Id $PID).Path;arguments=@();workingDirectory=$root;environment=@{};stopTimeoutSeconds=1
            }
            Save-TtRegistry $registry $root
            $registry
        } $script:StateRoot
        $script:Runtime = & $script:Module {
            param($root)
            $runtime = [hashtable](New-TtDefaultRuntimeStore)
            Get-TtRuntimeServiceRecord $runtime demo -Create | Out-Null
            Save-TtRuntimeStore $runtime $root
            $runtime
        } $script:StateRoot
        Mock Start-TtDetachedProcess -ModuleName TunnelTend { @{pid=77777;executable_path='fixture-host.exe';start_time_utc='2026-10-16T00:00:00Z'} }
        Mock Test-TtOwnedProcess -ModuleName TunnelTend { $true }
        Mock Stop-TtOwnedProcess -ModuleName TunnelTend {}
        Mock Start-TtOfficialRuntime -ModuleName TunnelTend {}
        Mock Stop-TtOfficialRuntime -ModuleName TunnelTend {}
        Mock Write-TtLog -ModuleName TunnelTend {}
        Mock Test-TtServiceConfigurationReady -ModuleName TunnelTend { @{ready=$true;issues=@()} }
        Mock Get-TtOfficialRuntimeStatus -ModuleName TunnelTend { @{running=$true;healthy=$true;ready=$true;error=$null} }
        Mock Wait-TtServiceHealth -ModuleName TunnelTend {
            @{serviceId='demo';observedAt='2026-10-16T00:00:00Z';state='ready';healthy=$true;ready=$true;tunnel=@{running=$true;healthy=$true;ready=$true;error=$null};host=@{configured=$true;running=$true;owned=$true};health=@{ok=$true;error=$null};readiness=@{ok=$true;error=$null}}
        }
    }

    It 'persists an acquired host identity through reload and clears it after an owned stop' {
        & $script:Module { param($r,$s,$root) Start-TtManagedService $r.services.demo $r $s $root | Out-Null; Save-TtRuntimeStore $s $root } $script:Registry $script:Runtime $script:StateRoot
        $loaded = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $loaded.services.demo.hostProcess | Should -Not -BeNullOrEmpty
        $loaded.services.demo.hostProcess.pid | Should -Be 77777

        & $script:Module { param($r,$s,$root) Stop-TtManagedService $r.services.demo $r $s $root | Out-Null; Save-TtRuntimeStore $s $root } $script:Registry $loaded $script:StateRoot

        $stopped = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $stopped.services.demo.hostProcess | Should -BeNullOrEmpty
        $stopped.services.demo.state | Should -Be 'stopped'
        Should -Invoke Stop-TtOwnedProcess -ModuleName TunnelTend -Exactly 1
    }

    It 'observes a missing required host as unhealthy even when the tunnel is healthy' {
        $observation = & $script:Module { param($r,$s,$root) Get-TtServiceObservation $r.services.demo $r $s $root } $script:Registry $script:Runtime $script:StateRoot
        $observation.host.configured | Should -BeTrue
        $observation.host.running | Should -BeFalse
        $observation.healthy | Should -BeFalse
    }

    It 'saves acquired ownership before a later tunnel launch failure' {
        Mock Start-TtOfficialRuntime -ModuleName TunnelTend { throw 'Synthetic tunnel launch failure' }

        { & $script:Module { param($r,$s,$root) Start-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $script:StateRoot } | Should -Throw '*Synthetic tunnel launch failure*'

        $loaded = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $loaded.services.demo.hostProcess | Should -Not -BeNullOrEmpty
        $loaded.services.demo.hostProcess.pid | Should -Be 77777
    }

    It 'retains a manual start request when startup fails' {
        $script:Runtime.session.suppressedServices = @('demo')
        & $script:Module { param($s,$root) Save-TtRuntimeStore $s $root } $script:Runtime $script:StateRoot
        Mock Start-TtManagedService -ModuleName TunnelTend { throw 'Synthetic start failure' }

        { Start-TtService -Id demo -StateRoot $script:StateRoot } | Should -Throw '*Synthetic start failure*'

        $loaded = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $loaded.session.activeServices | Should -Contain 'demo'
        $loaded.session.suppressedServices | Should -Not -Contain 'demo'
    }

    It 'retains session suppression when the requested stop fails' {
        $script:Runtime.session.activeServices = @('demo')
        & $script:Module { param($s,$root) Save-TtRuntimeStore $s $root } $script:Runtime $script:StateRoot
        Mock Stop-TtManagedService -ModuleName TunnelTend { throw 'Synthetic stop failure' }

        { Stop-TtService -Id demo -SessionOnly -StateRoot $script:StateRoot } | Should -Throw '*Synthetic stop failure*'

        $loaded = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $loaded.session.activeServices | Should -Not -Contain 'demo'
        $loaded.session.suppressedServices | Should -Contain 'demo'
    }

    It 'makes an explicit restart active even after a deliberate stop' {
        $script:Registry.services.demo.desiredState = 'stopped'
        $script:Runtime.session.suppressedServices = @('demo')
        & $script:Module { param($r,$s,$root) Save-TtRegistry $r $root; Save-TtRuntimeStore $s $root } $script:Registry $script:Runtime $script:StateRoot
        Mock Restart-TtManagedService -ModuleName TunnelTend { @{healthy=$true;state='ready'} }

        Restart-TtService -Id demo -StateRoot $script:StateRoot | Out-Null

        (Get-TtService -Id demo -StateRoot $script:StateRoot).desiredState | Should -Be 'running'
        $loaded = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $loaded.session.activeServices | Should -Contain 'demo'
        $loaded.session.suppressedServices | Should -Not -Contain 'demo'
    }

    It 'keeps registration and ownership available when ordinary unregister cannot stop' {
        $script:Runtime.services.demo.hostProcess = @{pid=77777;executable_path='fixture-host.exe';start_time_utc='2026-10-16T00:00:00Z'}
        & $script:Module { param($s,$root) Save-TtRuntimeStore $s $root } $script:Runtime $script:StateRoot
        Mock Stop-TtManagedService -ModuleName TunnelTend { throw 'Synthetic stop failure' }

        { Unregister-TtService -Id demo -StateRoot $script:StateRoot -Confirm:$false } | Should -Throw '*Synthetic stop failure*'

        (Get-TtService -Id demo -StateRoot $script:StateRoot).id | Should -Be 'demo'
        $loaded = & $script:Module { param($root) Get-TtRuntimeStore $root } $script:StateRoot
        $loaded.services.demo.hostProcess.pid | Should -Be 77777
    }

    It 'refuses a live mismatched host without clearing its management record' {
        $script:Runtime.services.demo.hostProcess = @{pid=77777;executable_path='fixture-host.exe';start_time_utc='2026-10-16T00:00:00Z'}
        Mock Test-TtOwnedProcess -ModuleName TunnelTend { $false }
        Mock Get-TtProcessInfo -ModuleName TunnelTend { @{running=$true} }

        { & $script:Module { param($r,$s,$root) Stop-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $script:StateRoot } | Should -Throw '*Refusing*'

        $script:Runtime.services.demo.hostProcess.pid | Should -Be 77777
        Should -Invoke Stop-TtOwnedProcess -ModuleName TunnelTend -Exactly 0
    }

    It 'retains explicit keep-running detach without attempting a stop' {
        Mock Stop-TtManagedService -ModuleName TunnelTend { throw 'A detach must not stop the service' }

        $result = Unregister-TtService -Id demo -KeepRunning -StateRoot $script:StateRoot -Confirm:$false

        $result.removed | Should -BeTrue
        $result.keptRunning | Should -BeTrue
        { Get-TtService -Id demo -StateRoot $script:StateRoot } | Should -Throw '*not registered*'
        Should -Invoke Stop-TtManagedService -ModuleName TunnelTend -Exactly 0
    }

    It 'clears a dead host record without signalling any process' {
        $script:Runtime.services.demo.hostProcess = [ordered]@{pid=77777;executable_path='fixture-host.exe';start_time_utc='2026-10-16T00:00:00Z'}
        Mock Test-TtOwnedProcess -ModuleName TunnelTend { $false }
        Mock Get-TtProcessInfo -ModuleName TunnelTend { @{running=$false} }

        $result = & $script:Module { param($r,$s,$root) Stop-TtManagedService $r.services.demo $r $s $root } $script:Registry $script:Runtime $script:StateRoot

        $result.stopped | Should -BeTrue
        $script:Runtime.services.demo.hostProcess | Should -BeNullOrEmpty
        Should -Invoke Stop-TtOwnedProcess -ModuleName TunnelTend -Exactly 0
    }

    It 'does not turn watchdog opt-out into a stop request' {
        $script:Registry.services.demo.watchdog = $false
        $script:Runtime.session.activeServices = @('demo')
        Mock Get-TtServiceObservation -ModuleName TunnelTend { @{serviceId='demo';healthy=$true;tunnel=@{running=$true};host=@{configured=$true;running=$true}} }

        $plan = & $script:Module { param($r,$s,$root) Get-TtReconcilePlanInternal $r $s watchdog -StateRoot $root } $script:Registry $script:Runtime $script:StateRoot

        $plan.actions.Count | Should -Be 1
        $plan.actions[0].action | Should -Be 'noop'
        $plan.actions[0].reason | Should -Be 'watchdog-disabled'
        $plan.actions[0].disruptive | Should -BeFalse
    }

    It 'still plans a genuine desired stop for a participating watchdog service' {
        $script:Registry.services.demo.desiredState = 'stopped'
        Mock Get-TtServiceObservation -ModuleName TunnelTend { @{serviceId='demo';healthy=$true;tunnel=@{running=$true};host=@{configured=$true;running=$true}} }

        $plan = & $script:Module { param($r,$s,$root) Get-TtReconcilePlanInternal $r $s watchdog -StateRoot $root } $script:Registry $script:Runtime $script:StateRoot

        $plan.actions[0].action | Should -Be 'stop'
    }

    It 'records success for an ordinary start without source metadata' {
        Mock Get-TtReconcilePlanInternal -ModuleName TunnelTend { @{actions=@(@{serviceId='demo';action='start';reason='desired-service-not-running'});observations=@()} }
        Mock Start-TtManagedService -ModuleName TunnelTend { @{healthy=$true;state='ready'} }

        $result = & $script:Module { param($r,$s,$root) Invoke-TtReconcileInternal $r $s -StateRoot $root } $script:Registry $script:Runtime $script:StateRoot

        $result.results[0].ok | Should -BeTrue
        $result.changed | Should -BeTrue
    }

    It 'keeps one observation failure visible while continuing another service' {
        $script:Registry.services.other = & $script:Module { param($r) $service=Copy-TtObject $r.services.demo; $service.id='other'; $service.tunnel.alias='other'; $service } $script:Registry
        Mock Get-TtServiceObservation -ModuleName TunnelTend {
            param($Service)
            if ($Service.id -eq 'demo') { throw 'Synthetic process query failure' }
            @{serviceId='other';healthy=$false;tunnel=@{running=$false};host=@{configured=$false;running=$true}}
        }
        Mock Start-TtManagedService -ModuleName TunnelTend { @{healthy=$true;state='ready'} }

        $result = & $script:Module { param($r,$s,$root) Invoke-TtReconcileInternal $r $s -StateRoot $root } $script:Registry $script:Runtime $script:StateRoot

        $failed = @($result.results | Where-Object serviceId -eq 'demo')
        $failed[0].ok | Should -BeFalse
        $failed[0].error | Should -Match 'Synthetic process query failure'
        @($result.results | Where-Object { $_.serviceId -eq 'other' -and $_.ok }).Count | Should -Be 1
        $result.changed | Should -BeTrue
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $Service.id -eq 'other' }
    }

    It 'records success for a health restart without source metadata' {
        Mock Get-TtReconcilePlanInternal -ModuleName TunnelTend { @{actions=@(@{serviceId='demo';action='restart';reason='health-threshold-exceeded'});observations=@()} }
        Mock Restart-TtManagedService -ModuleName TunnelTend { @{healthy=$true;state='ready'} }

        $result = & $script:Module { param($r,$s,$root) Invoke-TtReconcileInternal $r $s -StateRoot $root } $script:Registry $script:Runtime $script:StateRoot

        $result.results[0].ok | Should -BeTrue
        $result.changed | Should -BeTrue
    }

    It 'retains the applied fingerprint for a successful source restart' {
        Mock Get-TtReconcilePlanInternal -ModuleName TunnelTend { @{actions=@(@{serviceId='demo';action='restart';reason='stable-source-change';fingerprint='new-source'});observations=@()} }
        Mock Restart-TtManagedService -ModuleName TunnelTend { @{healthy=$true;state='ready'} }

        $result = & $script:Module { param($r,$s,$root) Invoke-TtReconcileInternal $r $s -StateRoot $root } $script:Registry $script:Runtime $script:StateRoot

        $result.results[0].ok | Should -BeTrue
        $script:Runtime.services.demo.source.appliedFingerprint | Should -Be 'new-source'
    }
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
