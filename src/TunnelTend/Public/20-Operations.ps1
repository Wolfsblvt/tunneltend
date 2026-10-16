Set-StrictMode -Version Latest

function Get-TtStatus {
    [CmdletBinding()]
    param([string[]]$ServiceId, [string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    $runtime = Get-TtRuntimeStore $StateRoot
    $ids = @(Resolve-TtServiceSelection -ServiceId $ServiceId -Services $registry.services)
    $services = @()
    foreach ($id in $ids) {
        if (-not $registry.services.Contains($id)) { $services += [ordered]@{ id=$id; registered=$false; state='missing' }; continue }
        $service = $registry.services[$id]
        $observation = Get-TtServiceObservation $service $registry $runtime $StateRoot
        $services += [ordered]@{
            id=$id
            displayName=$service.displayName
            registered=$true
            enabled=[bool]$service.enabled
            desiredState=$service.desiredState
            autostart=[bool]$service.autostart
            watchdog=[bool]$service.watchdog
            suppressedThisSession=(@($runtime.session.suppressedServices) -contains $id)
            observedState=$observation.state
            healthy=$observation.healthy
            ready=$observation.ready
            alias=$service.tunnel.alias
            tunnelId=(Get-TtMapValue $observation.tunnel 'tunnel_id' $null)
            healthUrl=(Get-TtMapValue $observation.tunnel 'health_url' $null)
            uiUrl=(Get-TtMapValue $observation.tunnel 'ui_url' $null)
            lastObservedAt=(Get-TtRuntimeServiceRecord $runtime $id -Create).lastObservedAt
        }
    }
    return [ordered]@{
        stateRoot=(Resolve-TtStateRoot $StateRoot)
        client=(Get-TtOfficialClientVersion $registry $StateRoot)
        automation=(Get-TtAutomationStatusInternal $registry $StateRoot)
        session=$runtime.session
        services=$services
    }
}

function Get-TtHealth {
    [CmdletBinding()]
    param([string[]]$ServiceId, [string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    $runtime = Get-TtRuntimeStore $StateRoot
    $ids = @(Resolve-TtServiceSelection -ServiceId $ServiceId -Services $registry.services)
    $observations = @()
    foreach ($id in $ids) {
        if (-not $registry.services.Contains($id)) { $observations += [ordered]@{ serviceId=$id; state='missing'; healthy=$false; ready=$false }; continue }
        $observations += Get-TtServiceObservation $registry.services[$id] $registry $runtime $StateRoot
    }
    return [ordered]@{
        healthy=(@($observations | Where-Object { -not $_.healthy }).Count -eq 0)
        ready=(@($observations | Where-Object { -not $_.ready }).Count -eq 0)
        services=$observations
    }
}

function Invoke-TtDoctor {
    [CmdletBinding()]
    param([string[]]$ServiceId, [string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    $runtime = Get-TtRuntimeStore $StateRoot
    $diagnostics = @()
    $client = Get-TtOfficialClientVersion $registry $StateRoot
    if (-not $client.installed) {
        $diagnostics += [ordered]@{ severity='error'; code='client.missing'; message=$client.error; repair='tunneltend client update --force' }
    }
    else {
        $capabilities = Test-TtOfficialClientCapabilities $registry $StateRoot
        if (-not $capabilities.compatible) { $diagnostics += [ordered]@{ severity='error'; code='client.incompatible'; message='The installed official client lacks required runtime commands or flags.'; detail=$capabilities }
        }
    }
    $ids = @(Resolve-TtServiceSelection -ServiceId $ServiceId -Services $registry.services)
    foreach ($id in $ids) {
        if (-not $registry.services.Contains($id)) { $diagnostics += [ordered]@{ severity='error'; code='service.missing'; serviceId=$id; message="Service '$id' is not registered." }; continue }
        $service = $registry.services[$id]
        if (-not $service.tunnel.tunnelId -and @($service.tunnel.organizationIds).Count -eq 0 -and @($service.tunnel.workspaceIds).Count -eq 0) {
            $diagnostics += [ordered]@{ severity='error'; code='service.scope-missing'; serviceId=$id; message='A tunnel id, organization id, or workspace id is required before this service can start.' }
        }
        if ($service.tunnel.runtimeKeyRef) {
            try { Resolve-TtSecretReference ([string]$service.tunnel.runtimeKeyRef) | Out-Null }
            catch { $diagnostics += [ordered]@{ severity='error'; code='service.runtime-key-unavailable'; serviceId=$id; message=$_.Exception.Message } }
        }
        if ($service.source.watch -and $service.source.path -and -not [IO.Directory]::Exists([string]$service.source.path) -and -not [IO.File]::Exists([string]$service.source.path)) {
            $diagnostics += [ordered]@{ severity='warning'; code='service.source-missing'; serviceId=$id; message="Source path '$($service.source.path)' does not exist." }
        }
        if ($service.mcp.kind -eq 'command') {
            try { Resolve-TtExecutable ([string]$service.mcp.command.file) ([string]$service.mcp.command.workingDirectory) | Out-Null }
            catch { $diagnostics += [ordered]@{ severity='error'; code='service.command-missing'; serviceId=$id; message=$_.Exception.Message } }
        }
        if ($service.host -and $service.host.enabled) {
            try { Resolve-TtExecutable ([string]$service.host.file) ([string]$service.host.workingDirectory) | Out-Null }
            catch { $diagnostics += [ordered]@{ severity='error'; code='service.host-command-missing'; serviceId=$id; message=$_.Exception.Message } }
        }
        $observation = Get-TtServiceObservation $service $registry $runtime $StateRoot
        if ($service.enabled -and $service.desiredState -eq 'running' -and -not $observation.healthy) {
            $diagnostics += [ordered]@{ severity='warning'; code='service.unhealthy'; serviceId=$id; message="Service '$id' is desired running but is '$($observation.state)'."; repair="tunneltend repair $id --apply" }
        }
        $record = Get-TtRuntimeServiceRecord $runtime $id -Create
        $permission = Test-TtRecoveryAllowed $record $service.recovery
        if (-not $permission.allowed -and $permission.reason -eq 'budget-exhausted') {
            $diagnostics += [ordered]@{ severity='error'; code='service.recovery-budget-exhausted'; serviceId=$id; message='Automatic recovery budget is exhausted. Inspect the underlying failure before forcing another attempt.' }
        }
    }
    $automation = Get-TtAutomationStatusInternal $registry $StateRoot
    if ($automation.supported) {
        foreach ($task in $automation.tasks) {
            if ($task.desired -and -not $task.installed) { $diagnostics += [ordered]@{ severity='warning'; code='automation.task-missing'; message="Scheduled task '$($task.name)' is configured but not installed."; repair='tunneltend automation install' } }
            # SCHED_S_TASK_RUNNING and SCHED_S_TASK_HAS_NOT_RUN describe normal
            # scheduler states; a new logon task has no failed execution.
            if ($task.installed -and $task.lastTaskResult -notin @($null,0,0x00041301,0x00041303)) { $diagnostics += [ordered]@{ severity='warning'; code='automation.last-run-failed'; message="Scheduled task '$($task.name)' last returned $($task.lastTaskResult)." } }
        }
    }
    elseif ($IsWindows) { $diagnostics += [ordered]@{ severity='warning'; code='automation.unsupported'; message='Windows Scheduled Task automation could not be inspected.' } }
    $status = if (@($diagnostics | Where-Object severity -eq 'error').Count -gt 0) { 'error' } elseif ($diagnostics.Count -gt 0) { 'degraded' } else { 'ok' }
    return [ordered]@{ status=$status; diagnostics=$diagnostics; client=$client; automation=$automation }
}

function Get-TtRepairPlan {
    [CmdletBinding()]
    param([string[]]$ServiceId, [switch]$Force, [string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    $runtime = Get-TtRuntimeStore $StateRoot
    $reconcile = Get-TtReconcilePlanInternal $registry $runtime manual $ServiceId $StateRoot -Force:$Force
    $actions = @($reconcile.actions | Where-Object action -ne 'noop')
    return [ordered]@{ actions=$actions; observations=$reconcile.observations; safeToApply=(@($actions | Where-Object action -eq 'error').Count -eq 0) }
}

function Invoke-TtRepair {
    [CmdletBinding()]
    param([string[]]$ServiceId, [switch]$Apply, [switch]$Force, [string]$StateRoot)
    if (-not $Apply) { return Get-TtRepairPlan $ServiceId -Force:$Force -StateRoot $StateRoot }
    return Invoke-TtReconcile -ServiceId $ServiceId -Context manual -Force:$Force -StateRoot $StateRoot
}

function Invoke-TtReconcile {
    [CmdletBinding()]
    param(
        [string[]]$ServiceId,
        [ValidateSet('manual','startup','watchdog','maintenance')][string]$Context = 'manual',
        [switch]$Plan,
        [switch]$Force,
        [string]$StateRoot
    )
    if ($Plan) {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        return Invoke-TtReconcileInternal $registry $runtime $Context $ServiceId $StateRoot -PlanOnly -Force:$Force
    }
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        $result = Invoke-TtReconcileInternal $registry $runtime $Context $ServiceId $StateRoot -Force:$Force
        Save-TtRuntimeStore $runtime $StateRoot
        return $result
    }
}

function Invoke-TtServiceUpdatesInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [Parameter(Mandatory)][hashtable]$Runtime, [string]$StateRoot)
    $results = @()
    foreach ($id in @($Registry.services.Keys | Sort-Object)) {
        $service = $Registry.services[$id]
        if (-not $service.update -or -not $service.update.enabled -or -not $service.update.command) { continue }
        $command = $service.update.command
        try {
            Assert-TtNoInlineSecrets $command.arguments "services.$id.update.command.arguments"
            $wasDesired = $service.enabled -and $service.desiredState -eq 'running' -and @($Runtime.session.suppressedServices) -notcontains $id
            if ($wasDesired) { Stop-TtManagedService $service $Registry $Runtime $StateRoot | Out-Null }
            $environment = Get-TtResolvedEnvironment $command.environment
            $process = Invoke-TtProcess -FilePath ([string]$command.file) -ArgumentList @($command.arguments) -WorkingDirectory ([string]$command.workingDirectory) -Environment $environment -TimeoutSeconds $(if ($command.timeoutSeconds) {[int]$command.timeoutSeconds} else {600})
            if ($wasDesired) { Start-TtManagedService $service $Registry $Runtime $StateRoot | Out-Null }
            $results += [ordered]@{ serviceId=$id; updated=$true; exitCode=$process.exit_code }
        }
        catch {
            $results += [ordered]@{ serviceId=$id; updated=$false; error=Protect-TtLogText $_.Exception.Message }
        }
        Save-TtRuntimeStore $Runtime $StateRoot
    }
    return $results
}

function Invoke-TtStartup {
    [CmdletBinding()]
    param([string]$StateRoot, [switch]$SkipUpdate)
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        $activeAtStartup = if ($registry.settings.automation.autostart) {
            @($registry.services.Values | Where-Object { $_.autostart -and $_.enabled -and $_.desiredState -eq 'running' } | ForEach-Object id)
        } else { @() }
        $runtime.session = [ordered]@{
            id=[Guid]::NewGuid().ToString('N')
            startedAt=Get-TtUtcNow
            startupAppliedAt=Get-TtUtcNow
            activeServices=@($activeAtStartup)
            suppressedServices=@($registry.services.Keys | Where-Object { @($activeAtStartup) -notcontains $_ })
        }
        Save-TtRuntimeStore $runtime $StateRoot
        $update = $null
        if (-not $SkipUpdate -and $registry.settings.automation.autoUpdate -and (Test-TtOfficialClientUpdateDue $registry $runtime $StateRoot)) {
            try { $update = Invoke-TtOfficialClientUpdateInternal $registry $runtime $StateRoot }
            catch { $update = [ordered]@{ changed=$false; error=Protect-TtLogText $_.Exception.Message } }
        }
        $reconcile = Invoke-TtReconcileInternal $registry $runtime startup @() $StateRoot
        Save-TtRuntimeStore $runtime $StateRoot
        return [ordered]@{ mode='startup'; session=$runtime.session; update=$update; reconcile=$reconcile }
    }
}

function Invoke-TtWatchdog {
    [CmdletBinding()]
    param([string]$StateRoot, [switch]$Force)
    return Invoke-WithTtLock -StateRoot $StateRoot -TimeoutSeconds 5 -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        $result = Invoke-TtReconcileInternal $registry $runtime watchdog @() $StateRoot -Force:$Force
        Save-TtRuntimeStore $runtime $StateRoot
        return [ordered]@{ mode='watchdog'; reconcile=$result }
    }
}

function Invoke-TtMaintenance {
    [CmdletBinding()]
    param([string]$StateRoot, [switch]$SkipClientUpdate, [switch]$SkipServiceUpdates, [switch]$Force)
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        $clientUpdate = $null
        if (-not $SkipClientUpdate -and $registry.settings.automation.autoUpdate -and (Test-TtOfficialClientUpdateDue $registry $runtime $StateRoot -Force:$Force)) {
            try { $clientUpdate = Invoke-TtOfficialClientUpdateInternal $registry $runtime $StateRoot -Force:$Force }
            catch { $clientUpdate = [ordered]@{ changed=$false; error=Protect-TtLogText $_.Exception.Message } }
        }
        $serviceUpdates = if ($SkipServiceUpdates) { @() } else { Invoke-TtServiceUpdatesInternal $registry $runtime $StateRoot }
        $reconcile = Invoke-TtReconcileInternal $registry $runtime maintenance @() $StateRoot -Force:$Force
        Save-TtRuntimeStore $runtime $StateRoot
        return [ordered]@{ mode='maintenance'; clientUpdate=$clientUpdate; serviceUpdates=$serviceUpdates; reconcile=$reconcile }
    }
}

function Get-TtClientStatus {
    [CmdletBinding()]
    param([string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    return [ordered]@{ installed=(Get-TtOfficialClientVersion $registry $StateRoot); capabilities=(Test-TtOfficialClientCapabilities $registry $StateRoot); configuration=$registry.settings.officialClient }
}

function Update-TtClient {
    [CmdletBinding()]
    param([switch]$Force, [switch]$CheckOnly, [string]$StateRoot)
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry=Get-TtRegistry $StateRoot; $runtime=Get-TtRuntimeStore $StateRoot
        $result=Invoke-TtOfficialClientUpdateInternal $registry $runtime $StateRoot -Force:$Force -CheckOnly:$CheckOnly
        Save-TtRuntimeStore $runtime $StateRoot
        return $result
    }
}

function Restore-TtClient {
    [CmdletBinding()]
    param([string]$BackupPath, [string]$StateRoot)
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry=Get-TtRegistry $StateRoot; $runtime=Get-TtRuntimeStore $StateRoot
        $result=Restore-TtOfficialClientBackupInternal $registry $runtime $StateRoot $BackupPath
        Save-TtRuntimeStore $runtime $StateRoot
        return $result
    }
}

function Install-TtAutomation {
    [CmdletBinding()]
    param([string]$StateRoot, [string]$PowerShellPath)
    $registry=Get-TtRegistry $StateRoot
    return Install-TtAutomationInternal $registry $StateRoot $PowerShellPath
}
function Uninstall-TtAutomation { [CmdletBinding()] param() return Uninstall-TtAutomationInternal }
function Get-TtAutomationStatus { [CmdletBinding()] param([string]$StateRoot) $registry=Get-TtRegistry $StateRoot; return Get-TtAutomationStatusInternal $registry $StateRoot }

function Get-TtConfiguration {
    [CmdletBinding()]
    param([string]$StateRoot)
    return (Get-TtRegistry $StateRoot).settings
}

function Set-TtConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value, [string]$StateRoot)
    return Set-TtConfigurationValue -Path $Path -Value $Value -StateRoot $StateRoot
}
