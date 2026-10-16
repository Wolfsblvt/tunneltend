Set-StrictMode -Version Latest

function Test-TtServiceDesiredRunning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Service,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [ValidateSet('manual','startup','watchdog','maintenance')][string]$Context = 'manual'
    )
    if (-not [bool]$Service.enabled) { return $false }
    if ([string]$Service.desiredState -ne 'running') { return $false }
    if ($Context -eq 'startup') { return @($Runtime.session.activeServices) -contains [string]$Service.id }
    if ($Context -in @('watchdog','maintenance')) {
        if (@($Runtime.session.suppressedServices) -contains [string]$Service.id) { return $false }
        if (@($Runtime.session.activeServices) -notcontains [string]$Service.id) { return $false }
    }
    return $true
}

function Start-TtHostProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service, [Parameter(Mandatory)][hashtable]$RuntimeRecord)
    if (-not $Service.host -or -not [bool]$Service.host.enabled) { return $null }
    if ($RuntimeRecord.hostProcess -and (Test-TtOwnedProcess $RuntimeRecord.hostProcess)) { return $RuntimeRecord.hostProcess }
    $environment = Get-TtResolvedEnvironment $Service.host.environment
    $processRecord = Start-TtDetachedProcess -FilePath ([string]$Service.host.file) -ArgumentList @($Service.host.arguments) -WorkingDirectory ([string]$Service.host.workingDirectory) -Environment $environment
    $RuntimeRecord.hostProcess = $processRecord
    return $processRecord
}

function Stop-TtHostProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service, [Parameter(Mandatory)][hashtable]$RuntimeRecord)
    if (-not $RuntimeRecord.hostProcess) { return }
    if (-not $RuntimeRecord.hostProcess.pid) { throw "Refusing to stop host for '$($Service.id)' without a recorded PID." }
    if (Test-TtOwnedProcess $RuntimeRecord.hostProcess) {
        $timeout = if ($Service.host -and $Service.host.stopTimeoutSeconds) { [int]$Service.host.stopTimeoutSeconds } else { 15 }
        Stop-TtOwnedProcess $RuntimeRecord.hostProcess $timeout
    }
    elseif ((Get-TtProcessInfo ([int]$RuntimeRecord.hostProcess.pid)).running) {
        throw "Refusing to stop host for '$($Service.id)': the live PID does not match its recorded process identity."
    }
    $RuntimeRecord.hostProcess = $null
}

function Wait-TtServiceHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Service,
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [string]$StateRoot,
        [int]$TimeoutSeconds = 60
    )
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    $last = $null
    do {
        $last = Get-TtServiceObservation $Service $Registry $Runtime $StateRoot
        if ($last.healthy) { return $last }
        Start-Sleep -Milliseconds 500
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    return $last
}

function Start-TtManagedService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Service,
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [string]$StateRoot
    )
    $record = Get-TtRuntimeServiceRecord $Runtime $Service.id -Create
    Start-TtHostProcess $Service $record | Out-Null
    if ($record.hostProcess) { Save-TtRuntimeStore $Runtime $StateRoot }
    if ($Service.host -and $Service.host.enabled -and $Service.health -and $Service.health.url) {
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds($(if ($Service.health.startupTimeoutSeconds) { [int]$Service.health.startupTimeoutSeconds } else { 45 }))
        do {
            $probe = Invoke-TtHttpProbe ([string]$Service.health.url) $(if ($Service.health.timeoutSeconds) { [int]$Service.health.timeoutSeconds } else { 5 })
            if ($probe.ok) { break }
            Start-Sleep -Milliseconds 500
        } while ([DateTimeOffset]::UtcNow -lt $deadline)
        if (-not $probe.ok) { throw "Host process for '$($Service.id)' started, but its health endpoint did not become healthy: $($probe.error)" }
    }
    Start-TtOfficialRuntime $Service $Registry $StateRoot | Out-Null
    $timeout = if ($Service.health -and $Service.health.startupTimeoutSeconds) { [int]$Service.health.startupTimeoutSeconds } else { 60 }
    $observation = Wait-TtServiceHealth $Service $Registry $Runtime $StateRoot $timeout
    $runtimeRecord = Update-TtRuntimeObservation $Runtime $observation
    if (-not $observation.healthy) { throw "Service '$($Service.id)' did not become healthy after startup." }
    Reset-TtRecoveryBudget $runtimeRecord
    $fingerprint = Get-TtSourceFingerprint $Service.source
    if ($fingerprint) {
        $runtimeRecord.source.appliedFingerprint = $fingerprint
        $runtimeRecord.source.pendingFingerprint = $null
        $runtimeRecord.source.pendingSince = $null
    }
    Write-TtLog -StateRoot $StateRoot -Event 'service.started' -Message "Started service '$($Service.id)'." -Data @{ service_id=$Service.id; alias=$Service.tunnel.alias }
    return $observation
}

function Stop-TtManagedService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Service,
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [string]$StateRoot
    )
    $record = Get-TtRuntimeServiceRecord $Runtime $Service.id -Create
    Stop-TtOfficialRuntime ([string]$Service.tunnel.alias) $Registry $StateRoot | Out-Null
    Stop-TtHostProcess $Service $record
    $record.state = 'stopped'
    $record.healthy = $false
    $record.ready = $false
    $record.lastObservedAt = Get-TtUtcNow
    $record.lastError = $null
    Write-TtLog -StateRoot $StateRoot -Event 'service.stopped' -Message "Stopped service '$($Service.id)'." -Data @{ service_id=$Service.id; alias=$Service.tunnel.alias }
    return [ordered]@{ serviceId=$Service.id; stopped=$true }
}

function Restart-TtManagedService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Service,
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [string]$StateRoot
    )
    Stop-TtManagedService $Service $Registry $Runtime $StateRoot | Out-Null
    Start-Sleep -Milliseconds 500
    return Start-TtManagedService $Service $Registry $Runtime $StateRoot
}


function Test-TtServiceConfigurationReady {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service)
    $issues = @()
    if (-not $Service.tunnel.tunnelId -and @($Service.tunnel.organizationIds).Count -eq 0 -and @($Service.tunnel.workspaceIds).Count -eq 0) {
        $issues += 'missing tunnel id, organization id, or workspace id'
    }
    if ($Service.tunnel.runtimeKeyRef) {
        try { Resolve-TtSecretReference ([string]$Service.tunnel.runtimeKeyRef) | Out-Null }
        catch { $issues += $_.Exception.Message }
    }
    if ($Service.mcp.kind -eq 'command') {
        try { Resolve-TtExecutable ([string]$Service.mcp.command.file) ([string]$Service.mcp.command.workingDirectory) | Out-Null }
        catch { $issues += $_.Exception.Message }
    }
    if ($Service.host -and $Service.host.enabled) {
        try { Resolve-TtExecutable ([string]$Service.host.file) ([string]$Service.host.workingDirectory) | Out-Null }
        catch { $issues += $_.Exception.Message }
    }
    return [ordered]@{ ready=($issues.Count -eq 0); issues=$issues }
}

function Get-TtReconcilePlanInternal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [ValidateSet('manual','startup','watchdog','maintenance')][string]$Context = 'manual',
        [string[]]$ServiceId,
        [string]$StateRoot,
        [switch]$Force
    )
    $ids = @(Resolve-TtServiceSelection -ServiceId $ServiceId -Services $Registry.services)
    $actions = @()
    $observations = @()
    foreach ($id in $ids) {
        if (-not $Registry.services.Contains($id)) {
            $actions += [ordered]@{ serviceId=$id; action='error'; reason='service-not-registered'; disruptive=$false }
            continue
        }
        $service = $Registry.services[$id]
        $runtimeRecord = Get-TtRuntimeServiceRecord $Runtime $id -Create
        try { $observation = Get-TtServiceObservation $service $Registry $Runtime $StateRoot }
        catch {
            $actions += [ordered]@{ serviceId=$id; action='error'; reason='observation-failed'; disruptive=$false; issues=@(Protect-TtLogText $_.Exception.Message) }
            continue
        }
        $observations += $observation
        if ($Context -eq 'watchdog' -and -not [bool]$service.watchdog) {
            $actions += [ordered]@{ serviceId=$id; action='noop'; reason='watchdog-disabled'; disruptive=$false }
            continue
        }
        $desiredRunning = Test-TtServiceDesiredRunning $service $Runtime $Context
        if (-not $desiredRunning) {
            if ($observation.tunnel.running -or ($observation.host.configured -and $observation.host.running)) {
                $actions += [ordered]@{ serviceId=$id; action='stop'; reason='desired-state-stopped'; disruptive=$true }
            }
            else { $actions += [ordered]@{ serviceId=$id; action='noop'; reason='already-stopped'; disruptive=$false } }
            continue
        }
        $configuration = Test-TtServiceConfigurationReady $service
        if (-not $configuration.ready) {
            $actions += [ordered]@{ serviceId=$id; action='error'; reason='configuration-invalid'; disruptive=$false; issues=$configuration.issues }
            continue
        }
        $sourceDecision = Get-TtSourceDecision $service $runtimeRecord
        switch ($sourceDecision.action) {
            'baseline' {
                $actions += [ordered]@{ serviceId=$id; action='record-source-baseline'; reason='first-source-observation'; disruptive=$false; fingerprint=$sourceDecision.fingerprint }
            }
            'record-pending' {
                $actions += [ordered]@{ serviceId=$id; action='record-source-pending'; reason='source-change-detected'; disruptive=$false; fingerprint=$sourceDecision.fingerprint; pendingSince=$sourceDecision.pendingSince }
            }
            'clear-pending' {
                if ($runtimeRecord.source.pendingFingerprint) { $actions += [ordered]@{ serviceId=$id; action='clear-source-pending'; reason='source-returned-to-baseline'; disruptive=$false; fingerprint=$sourceDecision.fingerprint } }
            }
            'restart' {
                $actions += [ordered]@{ serviceId=$id; action='restart'; reason='stable-source-change'; disruptive=$true; fingerprint=$sourceDecision.fingerprint }
                continue
            }
        }
        if (-not $observation.tunnel.running -or ($observation.host.configured -and -not $observation.host.running)) {
            $actions += [ordered]@{ serviceId=$id; action='start'; reason='desired-service-not-running'; disruptive=$true }
            continue
        }
        $threshold = if ($service.recovery.unhealthyThreshold) { [int]$service.recovery.unhealthyThreshold } else { 2 }
        $projectedFailures = if ($observation.healthy) { 0 } else { [int]$runtimeRecord.consecutiveFailures + 1 }
        if (-not $observation.healthy -and ($Force -or $projectedFailures -ge $threshold)) {
            $actions += [ordered]@{ serviceId=$id; action='restart'; reason='health-threshold-exceeded'; disruptive=$true; projectedFailures=$projectedFailures }
            continue
        }
        $actions += [ordered]@{ serviceId=$id; action='noop'; reason=$(if ($observation.healthy) {'healthy'} else {'waiting-for-health-threshold'}); disruptive=$false }
    }
    return [ordered]@{ context=$Context; actions=$actions; observations=$observations }
}

function Invoke-TtReconcileInternal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [ValidateSet('manual','startup','watchdog','maintenance')][string]$Context = 'manual',
        [string[]]$ServiceId,
        [string]$StateRoot,
        [switch]$PlanOnly,
        [switch]$Force
    )
    $plan = Get-TtReconcilePlanInternal $Registry $Runtime $Context $ServiceId $StateRoot -Force:$Force
    if ($PlanOnly) { return [ordered]@{ plan=$plan; results=@(); changed=$false } }
    $results = @()
    $changed = $false
    foreach ($action in $plan.actions) {
        $id = [string]$action.serviceId
        if (-not $Registry.services.Contains($id)) { $results += [ordered]@{ serviceId=$id; action='error'; ok=$false; error='service-not-registered' }; continue }
        $service = $Registry.services[$id]
        $record = Get-TtRuntimeServiceRecord $Runtime $id -Create
        try {
            switch ([string]$action.action) {
                'error' {
                    $issues = @(Get-TtMapValue $action 'issues' @()) -join '; '
                    $record.lastError = Protect-TtLogText $(if ($issues) { $issues } else { [string]$action.reason })
                    $results += [ordered]@{ serviceId=$id; action='error'; ok=$false; reason=$action.reason; error=$record.lastError }
                }
                'record-source-baseline' {
                    $record.source.appliedFingerprint = $action.fingerprint
                    $record.source.pendingFingerprint = $null
                    $record.source.pendingSince = $null
                    $results += [ordered]@{ serviceId=$id; action=$action.action; ok=$true }
                }
                'record-source-pending' {
                    $record.source.pendingFingerprint = $action.fingerprint
                    $record.source.pendingSince = $action.pendingSince
                    $results += [ordered]@{ serviceId=$id; action=$action.action; ok=$true }
                }
                'clear-source-pending' {
                    $record.source.pendingFingerprint = $null
                    $record.source.pendingSince = $null
                    $results += [ordered]@{ serviceId=$id; action=$action.action; ok=$true }
                }
                'noop' {
                    $observation = @($plan.observations | Where-Object serviceId -eq $id | Select-Object -First 1)
                    if ($observation) {
                        $updated = Update-TtRuntimeObservation $Runtime $observation[0]
                        if ($observation[0].healthy) { Reset-TtRecoveryBudget $updated }
                    }
                    $results += [ordered]@{ serviceId=$id; action='noop'; ok=$true; reason=$action.reason }
                }
                'stop' {
                    Stop-TtManagedService $service $Registry $Runtime $StateRoot | Out-Null
                    $changed = $true
                    $results += [ordered]@{ serviceId=$id; action='stop'; ok=$true; reason=$action.reason }
                }
                { $_ -in @('start','restart') } {
                    $automatic = $Context -in @('watchdog','maintenance','startup')
                    if ($automatic -and $Context -eq 'watchdog') {
                        $permission = Test-TtRecoveryAllowed $record $service.recovery -Force:$Force
                        if (-not $permission.allowed) {
                            $results += [ordered]@{ serviceId=$id; action=$action.action; ok=$false; skipped=$true; reason=$permission.reason; delaySeconds=$permission.delaySeconds }
                            continue
                        }
                        Register-TtRecoveryAttempt $record $service.recovery $action.reason | Out-Null
                        Save-TtRuntimeStore $Runtime $StateRoot
                    }
                    $observation = if ($action.action -eq 'restart') { Restart-TtManagedService $service $Registry $Runtime $StateRoot } else { Start-TtManagedService $service $Registry $Runtime $StateRoot }
                    $record.recovery.lastResult = if ($observation.healthy) { 'healthy' } else { 'unhealthy' }
                    $fingerprint = Get-TtMapValue $action 'fingerprint' $null
                    if ($fingerprint -and $observation.healthy) {
                        $record.source.appliedFingerprint = $fingerprint
                        $record.source.pendingFingerprint = $null
                        $record.source.pendingSince = $null
                    }
                    $changed = $true
                    $results += [ordered]@{ serviceId=$id; action=$action.action; ok=[bool]$observation.healthy; reason=$action.reason; state=$observation.state }
                }
                default {
                    $results += [ordered]@{ serviceId=$id; action=$action.action; ok=$false; error='unsupported-action' }
                }
            }
        }
        catch {
            $record.lastError = Protect-TtLogText $_.Exception.Message
            $record.recovery.lastResult = 'failed'
            $results += [ordered]@{ serviceId=$id; action=$action.action; ok=$false; error=$record.lastError }
            Write-TtLog -StateRoot $StateRoot -Level error -Event 'reconcile.action.failed' -Message $record.lastError -Data @{ service_id=$id; action=$action.action; context=$Context }
        }
        Save-TtRuntimeStore $Runtime $StateRoot
    }
    return [ordered]@{ plan=$plan; results=$results; changed=$changed }
}
