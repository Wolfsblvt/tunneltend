Set-StrictMode -Version Latest

function Invoke-TtHttpProbe {
    [CmdletBinding()]
    param([AllowNull()][string]$Url, [int]$TimeoutSeconds = 5)
    if ([string]::IsNullOrWhiteSpace($Url)) { return [ordered]@{ configured=$false; ok=$true; status=$null; error=$null; url=$null } }
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSeconds -MaximumRedirection 3 -SkipHttpErrorCheck
        $ok = [int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400
        return [ordered]@{ configured=$true; ok=$ok; status=[int]$response.StatusCode; error=$null; url=$Url }
    }
    catch { return [ordered]@{ configured=$true; ok=$false; status=$null; error=Protect-TtLogText $_.Exception.Message; url=$Url } }
}

function Get-TtHostObservation {
    [CmdletBinding()]
    param([AllowNull()][hashtable]$HostProcess)
    if (-not $HostProcess) { return [ordered]@{ configured=$false; running=$true; owned=$true; process=$null } }
    if (-not $HostProcess.pid) { return [ordered]@{ configured=$true; running=$false; owned=$false; process=$HostProcess } }
    $info = Get-TtProcessInfo ([int]$HostProcess.pid)
    $owned = if ($info.running) { Test-TtOwnedProcess $HostProcess } else { $false }
    return [ordered]@{ configured=$true; running=[bool]$info.running; owned=$owned; process=$info }
}

function Get-TtServiceObservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Service,
        [Parameter(Mandatory)][hashtable]$Registry,
        [Parameter(Mandatory)][hashtable]$Runtime,
        [string]$StateRoot
    )
    $record = Get-TtRuntimeServiceRecord $Runtime $Service.id -Create
    $tunnel = Get-TtOfficialRuntimeStatus -Alias ([string]$Service.tunnel.alias) -Registry $Registry -StateRoot $StateRoot
    $host = Get-TtHostObservation $record.hostProcess
    $healthUrl = if ($Service.health -and $Service.health.url) { [string]$Service.health.url } else { $null }
    $readyUrl = if ($Service.health -and $Service.health.readyUrl) { [string]$Service.health.readyUrl } else { $null }
    $timeout = if ($Service.health -and $Service.health.timeoutSeconds) { [int]$Service.health.timeoutSeconds } else { 5 }
    $health = Invoke-TtHttpProbe $healthUrl $timeout
    $ready = Invoke-TtHttpProbe $readyUrl $timeout
    $healthy = [bool]$tunnel.healthy -and [bool]$host.running -and [bool]$host.owned -and [bool]$health.ok
    $isReady = [bool]$tunnel.ready -and [bool]$host.running -and [bool]$host.owned -and [bool]$ready.ok
    $state = if ($isReady) { 'ready' } elseif ($healthy) { 'healthy' } elseif ($tunnel.running -or ($host.configured -and $host.running)) { 'degraded' } else { 'stopped' }
    return [ordered]@{
        serviceId = $Service.id
        observedAt = Get-TtUtcNow
        state = $state
        healthy = $healthy
        ready = $isReady
        tunnel = $tunnel
        host = $host
        health = $health
        readiness = $ready
    }
}

function Update-TtRuntimeObservation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Runtime, [Parameter(Mandatory)][hashtable]$Observation)
    $record = Get-TtRuntimeServiceRecord $Runtime $Observation.serviceId -Create
    $record.lastObservedAt = $Observation.observedAt
    $record.state = $Observation.state
    $record.healthy = $Observation.healthy
    $record.ready = $Observation.ready
    $record.tunnel = $Observation.tunnel
    if ($Observation.healthy) { $record.consecutiveFailures = 0; $record.lastError = $null }
    else {
        $record.consecutiveFailures = [int]$record.consecutiveFailures + 1
        $errors = @()
        if ($Observation.tunnel.error) { $errors += [string]$Observation.tunnel.error }
        if ($Observation.health.error) { $errors += [string]$Observation.health.error }
        if ($Observation.readiness.error) { $errors += [string]$Observation.readiness.error }
        if ($Observation.host.configured -and -not $Observation.host.owned) { $errors += 'host process is not running with the recorded identity' }
        $record.lastError = Protect-TtLogText ($errors -join '; ')
    }
    return $record
}

function Get-TtRecoveryPolicy {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service)
    return $Service.recovery
}

function Get-TtRecentRecoveryAttempts {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$RuntimeRecord, [Parameter(Mandatory)][hashtable]$Policy)
    $cutoff = [DateTimeOffset]::UtcNow.AddMinutes(-[int]$Policy.windowMinutes)
    return @($RuntimeRecord.recovery.attempts | Where-Object {
        try { [DateTimeOffset]::Parse([string]$_) -ge $cutoff } catch { $false }
    })
}

function Test-TtRecoveryAllowed {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$RuntimeRecord, [Parameter(Mandatory)][hashtable]$Policy, [switch]$Force)
    if ($Force) { return [ordered]@{ allowed=$true; reason='forced'; delaySeconds=0 } }
    if (-not $Policy.enabled) { return [ordered]@{ allowed=$false; reason='recovery-disabled'; delaySeconds=0 } }
    $attempts = @(Get-TtRecentRecoveryAttempts $RuntimeRecord $Policy)
    if ($attempts.Count -ge [int]$Policy.maxAttempts) { return [ordered]@{ allowed=$false; reason='budget-exhausted'; delaySeconds=0 } }
    if ($RuntimeRecord.recovery.nextAllowedAt) {
        $next = [DateTimeOffset]::Parse([string]$RuntimeRecord.recovery.nextAllowedAt)
        if ($next -gt [DateTimeOffset]::UtcNow) {
            return [ordered]@{ allowed=$false; reason='backoff'; delaySeconds=[Math]::Ceiling(($next - [DateTimeOffset]::UtcNow).TotalSeconds) }
        }
    }
    return [ordered]@{ allowed=$true; reason='within-budget'; delaySeconds=0 }
}

function Register-TtRecoveryAttempt {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$RuntimeRecord, [Parameter(Mandatory)][hashtable]$Policy, [string]$Reason)
    $attempts = @(Get-TtRecentRecoveryAttempts $RuntimeRecord $Policy)
    $now = [DateTimeOffset]::UtcNow
    $attempts += $now.ToString('o')
    $RuntimeRecord.recovery.attempts = $attempts
    $RuntimeRecord.recovery.lastReason = $Reason
    $count = $attempts.Count
    $delay = [Math]::Min([int]$Policy.maximumBackoffSeconds, [int]$Policy.initialBackoffSeconds * [Math]::Pow(2, [Math]::Max(0, $count - 1)))
    $RuntimeRecord.recovery.nextAllowedAt = $now.AddSeconds($delay).ToString('o')
    if ($count -ge [int]$Policy.maxAttempts) { $RuntimeRecord.recovery.exhaustedAt = $now.ToString('o') }
    return [int]$delay
}

function Reset-TtRecoveryBudget {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$RuntimeRecord)
    $RuntimeRecord.recovery.attempts = @()
    $RuntimeRecord.recovery.nextAllowedAt = $null
    $RuntimeRecord.recovery.exhaustedAt = $null
    $RuntimeRecord.recovery.lastReason = $null
    $RuntimeRecord.recovery.lastResult = 'healthy'
}

function Get-TtSourceDecision {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service, [Parameter(Mandatory)][hashtable]$RuntimeRecord)
    $fingerprint = Get-TtSourceFingerprint $Service.source
    if ($null -eq $fingerprint) { return [ordered]@{ action='none'; fingerprint=$null } }
    if (-not $RuntimeRecord.source.appliedFingerprint) { return [ordered]@{ action='baseline'; fingerprint=$fingerprint } }
    if ($fingerprint -eq $RuntimeRecord.source.appliedFingerprint) { return [ordered]@{ action='clear-pending'; fingerprint=$fingerprint } }
    if ($fingerprint -ne $RuntimeRecord.source.pendingFingerprint) { return [ordered]@{ action='record-pending'; fingerprint=$fingerprint; pendingSince=Get-TtUtcNow } }
    $since = if ($RuntimeRecord.source.pendingSince) { [DateTimeOffset]::Parse([string]$RuntimeRecord.source.pendingSince) } else { [DateTimeOffset]::UtcNow }
    $debounce = if ($Service.source.debounceSeconds) { [int]$Service.source.debounceSeconds } else { 10 }
    if ([DateTimeOffset]::UtcNow -ge $since.AddSeconds($debounce)) { return [ordered]@{ action='restart'; fingerprint=$fingerprint; pendingSince=$RuntimeRecord.source.pendingSince } }
    return [ordered]@{ action='wait'; fingerprint=$fingerprint; pendingSince=$RuntimeRecord.source.pendingSince }
}
