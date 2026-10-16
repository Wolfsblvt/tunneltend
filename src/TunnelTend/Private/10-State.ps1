Set-StrictMode -Version Latest

function New-TtDefaultRegistry {
    [CmdletBinding()]
    param([string]$StateRoot)
    $installRoot = Get-TtDefaultInstallRoot
    return [ordered]@{
        schemaVersion = 1
        product = [ordered]@{ name = 'tunneltend'; createdAt = Get-TtUtcNow; updatedAt = Get-TtUtcNow }
        settings = [ordered]@{
            automation = [ordered]@{
                autostart = $true
                watchdog = $true
                autoUpdate = $true
                watchdogIntervalMinutes = 2
                maintenanceHour = 5
                maintenanceMinute = 15
                maintenanceRandomDelayMinutes = 20
                startupDelaySeconds = 20
            }
            officialClient = [ordered]@{
                repository = 'openai/tunnel-client'
                channel = 'stable'
                installDirectory = [IO.Path]::Combine($installRoot, 'official-client')
                executablePath = [IO.Path]::Combine($installRoot, 'official-client', 'tunnel-client.exe')
                updateCheckHours = 24
                allowUnverifiedAsset = $false
            }
            defaults = [ordered]@{
                autostart = $true
                watchdog = $true
                sourceWatch = $true
                desiredState = 'running'
                runtimeKeyRef = 'env:CONTROL_PLANE_API_KEY'
                organizationIds = @()
                workspaceIds = @()
                recovery = [ordered]@{
                    enabled = $true
                    maxAttempts = 4
                    windowMinutes = 20
                    initialBackoffSeconds = 10
                    maximumBackoffSeconds = 300
                    unhealthyThreshold = 2
                }
            }
        }
        services = [ordered]@{}
    }
}

function New-TtDefaultRuntimeStore {
    [CmdletBinding()]
    param()
    return [ordered]@{
        schemaVersion = 1
        session = [ordered]@{
            id = [Guid]::NewGuid().ToString('N')
            startedAt = Get-TtUtcNow
            startupAppliedAt = $null
            activeServices = @()
            suppressedServices = @()
        }
        officialClient = [ordered]@{
            lastUpdateCheckAt = $null
            lastUpdateResult = $null
        }
        services = [ordered]@{}
    }
}

function Repair-TtRegistryShape {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    if (-not $Registry.Contains('schemaVersion')) { $Registry.schemaVersion = 1 }
    if ([int]$Registry.schemaVersion -ne 1) { throw "Unsupported registry schema version '$($Registry.schemaVersion)'." }
    $defaults = New-TtDefaultRegistry $StateRoot
    foreach ($key in @('product','settings','services')) {
        if (-not $Registry.Contains($key) -or $null -eq $Registry[$key]) { $Registry[$key] = Copy-TtObject $defaults[$key] }
    }
    foreach ($group in @('automation','officialClient','defaults')) {
        if (-not $Registry.settings.Contains($group)) { $Registry.settings[$group] = Copy-TtObject $defaults.settings[$group] }
        foreach ($key in $defaults.settings[$group].Keys) {
            if (-not $Registry.settings[$group].Contains($key)) { $Registry.settings[$group][$key] = Copy-TtObject $defaults.settings[$group][$key] }
        }
    }
    if (-not $Registry.settings.defaults.Contains('recovery')) { $Registry.settings.defaults.recovery = Copy-TtObject $defaults.settings.defaults.recovery }
    foreach ($key in $defaults.settings.defaults.recovery.Keys) {
        if (-not $Registry.settings.defaults.recovery.Contains($key)) { $Registry.settings.defaults.recovery[$key] = $defaults.settings.defaults.recovery[$key] }
    }
    return $Registry
}

function Repair-TtRuntimeShape {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Runtime)
    if (-not $Runtime.Contains('schemaVersion')) { $Runtime.schemaVersion = 1 }
    if ([int]$Runtime.schemaVersion -ne 1) { throw "Unsupported runtime schema version '$($Runtime.schemaVersion)'." }
    $defaults = New-TtDefaultRuntimeStore
    foreach ($key in @('session','officialClient','services')) {
        if (-not $Runtime.Contains($key) -or $null -eq $Runtime[$key]) { $Runtime[$key] = Copy-TtObject $defaults[$key] }
    }
    foreach ($key in $defaults.session.Keys) { if (-not $Runtime.session.Contains($key)) { $Runtime.session[$key] = Copy-TtObject $defaults.session[$key] } }
    foreach ($key in $defaults.officialClient.Keys) { if (-not $Runtime.officialClient.Contains($key)) { $Runtime.officialClient[$key] = $defaults.officialClient[$key] } }
    return $Runtime
}

function Get-TtRegistry {
    [CmdletBinding()]
    param([string]$StateRoot)
    # Reads remain side-effect free. Persistence paths are created only by the
    # corresponding Save functions or another explicit mutating operation.
    $paths = Get-TtPaths $StateRoot
    $registry = Read-TtJsonFile $paths.Registry (New-TtDefaultRegistry $StateRoot)
    return Repair-TtRegistryShape $registry $StateRoot
}

function Save-TtRegistry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    Assert-TtRegistry $Registry
    $Registry.product.updatedAt = Get-TtUtcNow
    $paths = Initialize-TtStateDirectories $StateRoot
    Write-TtJsonAtomic $paths.Registry $Registry
}

function Get-TtRuntimeStore {
    [CmdletBinding()]
    param([string]$StateRoot)
    $paths = Get-TtPaths $StateRoot
    $runtime = Read-TtJsonFile $paths.Runtime (New-TtDefaultRuntimeStore)
    return Repair-TtRuntimeShape $runtime
}

function Save-TtRuntimeStore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Runtime, [string]$StateRoot)
    $paths = Initialize-TtStateDirectories $StateRoot
    Write-TtJsonAtomic $paths.Runtime $Runtime
}

function Get-TtRuntimeServiceRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Runtime, [Parameter(Mandatory)][string]$ServiceId, [switch]$Create)
    if (-not $Runtime.services.Contains($ServiceId)) {
        if (-not $Create) { return $null }
        # Mutators accept hashtables. OrderedDictionary would be converted to a
        # copy at that boundary, losing top-level ownership/state assignments.
        $Runtime.services[$ServiceId] = @{
            serviceId = $ServiceId
            lastObservedAt = $null
            state = 'unknown'
            healthy = $false
            ready = $false
            consecutiveFailures = 0
            lastError = $null
            tunnel = $null
            officialAlias = $null
            hostProcess = $null
            source = [ordered]@{
                appliedFingerprint = $null
                pendingFingerprint = $null
                pendingSince = $null
            }
            recovery = [ordered]@{
                attempts = @()
                nextAllowedAt = $null
                exhaustedAt = $null
                lastReason = $null
                lastResult = $null
            }
        }
    }
    return $Runtime.services[$ServiceId]
}

function Set-TtRunningServiceIntent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [Parameter(Mandatory)][hashtable]$Runtime, [Parameter(Mandatory)][string]$ServiceId, [string]$StateRoot)
    if (-not $Registry.services.Contains($ServiceId)) { throw "Service '$ServiceId' is not registered." }
    $service = $Registry.services[$ServiceId]
    $service.enabled = $true
    $service.desiredState = 'running'
    $service.updatedAt = Get-TtUtcNow
    Save-TtRegistry $Registry $StateRoot
    $Runtime.session.suppressedServices = @($Runtime.session.suppressedServices | Where-Object { $_ -ne $ServiceId })
    if (@($Runtime.session.activeServices) -notcontains $ServiceId) { $Runtime.session.activeServices += $ServiceId }
    Save-TtRuntimeStore $Runtime $StateRoot
}

function Assert-TtServiceDefinition {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service)
    Assert-TtNoInlineSecrets $Service 'service'
    foreach ($key in @('id','enabled','desiredState','autostart','watchdog','mcp','tunnel','recovery')) {
        if (-not $Service.Contains($key)) { throw "Service definition is missing '$key'." }
    }
    $normalized = ConvertTo-TtServiceId ([string]$Service.id)
    if ($normalized -ne [string]$Service.id) { throw "Service id '$($Service.id)' is not normalized; expected '$normalized'." }
    if ([string]$Service.desiredState -notin @('running','stopped')) { throw "Service '$($Service.id)' has invalid desiredState '$($Service.desiredState)'." }
    if ([string]$Service.mcp.kind -notin @('command','commandString','url')) { throw "Service '$($Service.id)' has unsupported mcp.kind '$($Service.mcp.kind)'." }
    if ($Service.mcp.kind -eq 'command') {
        if (-not $Service.mcp.command -or [string]::IsNullOrWhiteSpace([string]$Service.mcp.command.file)) { throw "Command service '$($Service.id)' requires mcp.command.file." }
    }
    if ($Service.mcp.kind -eq 'commandString') {
        if ([string]::IsNullOrWhiteSpace([string]$Service.mcp.commandString)) { throw "Command-string service '$($Service.id)' requires mcp.commandString." }
    }
    if ($Service.mcp.kind -eq 'url') {
        $uri = $null
        if (-not [Uri]::TryCreate([string]$Service.mcp.url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @('http','https')) {
            throw "URL service '$($Service.id)' requires an absolute HTTP or HTTPS mcp.url."
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Service.tunnel.alias)) { throw "Service '$($Service.id)' requires tunnel.alias." }
    foreach ($scopeName in @('organizationIds', 'workspaceIds')) {
        $scopeValues = @($Service.tunnel[$scopeName])
        foreach ($scopeValue in $scopeValues) {
            if ([string]::IsNullOrWhiteSpace([string]$scopeValue)) {
                throw "Service '$($Service.id)' tunnel.$scopeName must not contain empty values."
            }
        }
        if (@($scopeValues | Select-Object -Unique).Count -ne $scopeValues.Count) {
            throw "Service '$($Service.id)' tunnel.$scopeName must not contain duplicate values."
        }
    }
    if (@($Service.tunnel.organizationIds).Count -gt 0 -and @($Service.tunnel.workspaceIds).Count -gt 0) {
        throw "Service '$($Service.id)' may use organizationIds or workspaceIds, not both."
    }
    if ($Service.tunnel.runtimeKeyRef -and -not (Test-TtSecretReference ([string]$Service.tunnel.runtimeKeyRef))) {
        throw "Service '$($Service.id)' tunnel.runtimeKeyRef must use env:NAME or file:/path."
    }
    $mcpCommand = if ($Service.mcp.Contains('command')) { $Service.mcp.command } else { $null }
    $updateCommand = if ($Service.update -and $Service.update.Contains('command')) { $Service.update.command } else { $null }
    foreach ($commandContainer in @($mcpCommand, $Service.host, $updateCommand)) {
        if ($commandContainer -and $commandContainer.Contains('environment') -and $commandContainer.environment) {
            foreach ($name in $commandContainer.environment.Keys) {
                if (-not (Test-TtSecretReference ([string]$commandContainer.environment[$name]))) {
                    throw "Service '$($Service.id)' environment '$name' must use env:NAME or file:/path."
                }
            }
        }
    }
}

function Assert-TtRegistry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry)
    if ([int]$Registry.schemaVersion -ne 1) { throw "Unsupported registry schema version '$($Registry.schemaVersion)'." }
    if ($Registry.settings.officialClient.allowUnverifiedAsset -isnot [bool] -or $Registry.settings.officialClient.allowUnverifiedAsset) {
        throw 'Automatic official-client acquisition requires published digest/checksum verification; allowUnverifiedAsset must be false.'
    }
    $aliases = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $Registry.services.Keys) {
        $service = $Registry.services[$id]
        if ([string]$service.id -ne [string]$id) { throw "Registry key '$id' does not match service id '$($service.id)'." }
        Assert-TtServiceDefinition $service
        if (-not $aliases.Add([string]$service.tunnel.alias)) { throw "Official alias '$($service.tunnel.alias)' is already controlled by another registration." }
    }
}

function Set-TtConfigurationValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value,
        [string]$StateRoot
    )
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot
        $segments = $Path.Split('.', [StringSplitOptions]::RemoveEmptyEntries)
        if ($segments.Count -lt 1) { throw 'Configuration path is empty.' }
        $cursor = $registry
        for ($index = 0; $index -lt ($segments.Count - 1); $index++) {
            $segment = $segments[$index]
            if (-not $cursor.Contains($segment) -or $cursor[$segment] -isnot [System.Collections.IDictionary]) { $cursor[$segment] = [ordered]@{} }
            $cursor = $cursor[$segment]
        }
        $cursor[$segments[-1]] = $Value
        Save-TtRegistry $registry $StateRoot
        return $registry
    }
}
