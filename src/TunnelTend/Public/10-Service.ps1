Set-StrictMode -Version Latest

function New-TtServiceDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$DisplayName,
        [Parameter(Mandatory)][hashtable]$Mcp,
        [string]$ProjectPath,
        [string]$Alias,
        [string]$TunnelId,
        [string[]]$OrganizationId,
        [string[]]$WorkspaceId,
        [string]$RuntimeKeyRef,
        [string]$AdminProfile,
        [hashtable]$Host,
        [string]$HealthUrl,
        [string]$ReadyUrl,
        [bool]$Autostart = $true,
        [bool]$Watchdog = $true,
        [bool]$SourceWatch = $true,
        [bool]$Enabled = $true,
        [string]$DesiredState = 'running',
        [hashtable]$Defaults
    )
    $serviceId = ConvertTo-TtServiceId $Id
    if (-not $DisplayName) { $DisplayName = $serviceId }
    if (-not $Alias) { $Alias = $serviceId }
    if (-not $RuntimeKeyRef) { $RuntimeKeyRef = if ($Defaults) { [string]$Defaults.runtimeKeyRef } else { 'env:CONTROL_PLANE_API_KEY' } }
    $recovery = if ($Defaults -and $Defaults.recovery) { Copy-TtObject $Defaults.recovery } else { [ordered]@{ enabled=$true; maxAttempts=4; windowMinutes=20; initialBackoffSeconds=10; maximumBackoffSeconds=300; unhealthyThreshold=2 } }
    $sourcePath = if ($ProjectPath) { [IO.Path]::GetFullPath($ProjectPath) } else { $null }
    $service = [ordered]@{
        id = $serviceId
        displayName = $DisplayName
        enabled = $Enabled
        desiredState = $DesiredState
        autostart = $Autostart
        watchdog = $Watchdog
        createdAt = Get-TtUtcNow
        updatedAt = Get-TtUtcNow
        tunnel = [ordered]@{
            alias = (ConvertTo-TtServiceId $Alias)
            tunnelId = $TunnelId
            organizationIds = @(ConvertTo-TtStringArray $OrganizationId | Select-Object -Unique)
            workspaceIds = @(ConvertTo-TtStringArray $WorkspaceId | Select-Object -Unique)
            runtimeKeyRef = $RuntimeKeyRef
            adminProfile = $AdminProfile
            profileName = $serviceId
            profileDirectory = $null
        }
        mcp = $Mcp
        host = $(if ($Host) { $Host } else { $null })
        health = [ordered]@{ url=$HealthUrl; readyUrl=$ReadyUrl; timeoutSeconds=5; startupTimeoutSeconds=60 }
        source = [ordered]@{
            path = $sourcePath
            watch = [bool]($SourceWatch -and $sourcePath)
            include = @('**/*')
            exclude = @('.git/**','.idea/**','.vs/**','.vscode/**','node_modules/**','bin/**','obj/**','dist/**','build/**','coverage/**','*.log')
            debounceSeconds = 10
        }
        recovery = $recovery
        update = [ordered]@{ enabled=$false; command=$null }
    }
    Assert-TtServiceDefinition $service
    return $service
}

function Register-TtService {
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(ParameterSetName='Path',Mandatory)][string]$Path,
        [Parameter(ParameterSetName='Command',Mandatory)][string]$Command,
        [Parameter(ParameterSetName='Command')][string[]]$Argument = @(),
        [Parameter(ParameterSetName='Command')][string]$WorkingDirectory,
        [Parameter(ParameterSetName='Url',Mandatory)][string]$Url,
        [string]$Id,
        [string]$DisplayName,
        [string]$Alias,
        [string]$TunnelId,
        [string[]]$OrganizationId,
        [string[]]$WorkspaceId,
        [string]$RuntimeKeyRef,
        [string]$AdminProfile,
        [string]$HealthUrl,
        [string]$ReadyUrl,
        [switch]$NoAutostart,
        [switch]$NoWatchdog,
        [switch]$NoSourceWatch,
        [switch]$NoStart,
        [switch]$Disabled,
        [switch]$Force,
        [string]$StateRoot
    )
    $parameterSetName = $PSCmdlet.ParameterSetName
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot
        $runtime = Get-TtRuntimeStore $StateRoot
        if (@($OrganizationId).Count -eq 0) { $OrganizationId = @($registry.settings.defaults.organizationIds) }
        if (@($WorkspaceId).Count -eq 0) { $WorkspaceId = @($registry.settings.defaults.workspaceIds) }
        $projectPath = $null
        $mcp = $null
        $descriptor = $null
        switch ($parameterSetName) {
            'Path' {
                $projectPath = [IO.Path]::GetFullPath($Path)
                $candidate = Resolve-TtProjectDiscovery $projectPath
                if ($candidate.kind -eq 'descriptor') { $descriptor = $candidate.descriptor }
                else { $mcp = $candidate.mcp }
                if (-not $Id) { $Id = Split-Path $projectPath -Leaf }
            }
            'Command' {
                if (-not $WorkingDirectory) { $WorkingDirectory = (Get-Location).Path }
                $mcp = [ordered]@{ kind='command'; command=[ordered]@{ file=$Command; arguments=@($Argument); workingDirectory=[IO.Path]::GetFullPath($WorkingDirectory); environment=[ordered]@{} } }
                if (-not $Id) { $Id = [IO.Path]::GetFileNameWithoutExtension($Command) }
            }
            'Url' {
                $mcp = [ordered]@{ kind='url'; url=$Url }
                if (-not $Id) { $Id = ([Uri]$Url).Host }
            }
        }
        $serviceId = ConvertTo-TtServiceId $Id
        if ($registry.services.Contains($serviceId) -and -not $Force) { throw "Service '$serviceId' is already registered. Use --force to replace it." }

        if ($descriptor) {
            $overlay = if ($descriptor.Contains('service')) { ConvertTo-TtHashtable $descriptor.service } else { ConvertTo-TtHashtable $descriptor }
            if (-not $overlay.Contains('mcp')) { throw 'A service descriptor must contain an mcp definition.' }
            $base = New-TtServiceDefinition -Id $serviceId -DisplayName $DisplayName -Mcp (ConvertTo-TtHashtable $overlay.mcp) -ProjectPath $projectPath -Alias $Alias -TunnelId $TunnelId -OrganizationId $OrganizationId -WorkspaceId $WorkspaceId -RuntimeKeyRef $RuntimeKeyRef -AdminProfile $AdminProfile -HealthUrl $HealthUrl -ReadyUrl $ReadyUrl -Autostart:(-not $NoAutostart) -Watchdog:(-not $NoWatchdog) -SourceWatch:(-not $NoSourceWatch) -Enabled:(-not $Disabled) -DesiredState $(if ($Disabled) {'stopped'} else {'running'}) -Defaults $registry.settings.defaults
            $service = Merge-TtHashtable $base ([hashtable]$overlay)
            $service.id = $serviceId
            if ($DisplayName) { $service.displayName = $DisplayName }
            if ($Alias) { $service.tunnel.alias = ConvertTo-TtServiceId $Alias }
            if ($TunnelId) { $service.tunnel.tunnelId = $TunnelId }
            if (@($OrganizationId).Count -gt 0) { $service.tunnel.organizationIds = @($OrganizationId) }
            if (@($WorkspaceId).Count -gt 0) { $service.tunnel.workspaceIds = @($WorkspaceId) }
            if ($RuntimeKeyRef) { $service.tunnel.runtimeKeyRef = $RuntimeKeyRef }
            if ($AdminProfile) { $service.tunnel.adminProfile = $AdminProfile }
            if ($HealthUrl) { $service.health.url = $HealthUrl }
            if ($ReadyUrl) { $service.health.readyUrl = $ReadyUrl }
            if ($NoAutostart) { $service.autostart = $false }
            if ($NoWatchdog) { $service.watchdog = $false }
            if ($NoSourceWatch) { $service.source.watch = $false }
            if ($Disabled) { $service.enabled = $false; $service.desiredState = 'stopped' }
            if ($service.mcp.kind -eq 'command' -and [string]::IsNullOrWhiteSpace([string]$service.mcp.command.workingDirectory)) { $service.mcp.command.workingDirectory = $projectPath }
            if ($service.host -and [string]::IsNullOrWhiteSpace([string]$service.host.workingDirectory)) { $service.host.workingDirectory = $projectPath }
        }
        else {
            $service = New-TtServiceDefinition -Id $serviceId -DisplayName $DisplayName -Mcp $mcp -ProjectPath $projectPath -Alias $Alias -TunnelId $TunnelId -OrganizationId $OrganizationId -WorkspaceId $WorkspaceId -RuntimeKeyRef $RuntimeKeyRef -AdminProfile $AdminProfile -HealthUrl $HealthUrl -ReadyUrl $ReadyUrl -Autostart:(-not $NoAutostart) -Watchdog:(-not $NoWatchdog) -SourceWatch:(-not $NoSourceWatch) -Enabled:(-not $Disabled) -DesiredState $(if ($Disabled) {'stopped'} else {'running'}) -Defaults $registry.settings.defaults
        }
        if (-not $service.createdAt) { $service.createdAt = Get-TtUtcNow }
        $service.updatedAt = Get-TtUtcNow
        Assert-TtServiceDefinition $service
        $registry.services[$serviceId] = $service
        Get-TtRuntimeServiceRecord $runtime $serviceId -Create | Out-Null

        $shouldStart = -not $NoStart -and $service.enabled -and $service.desiredState -eq 'running'
        if ($shouldStart) {
            if (@($runtime.session.activeServices) -notcontains $serviceId) { $runtime.session.activeServices += $serviceId }
            $runtime.session.suppressedServices = @($runtime.session.suppressedServices | Where-Object { $_ -ne $serviceId })
        } else {
            $runtime.session.activeServices = @($runtime.session.activeServices | Where-Object { $_ -ne $serviceId })
            if (@($runtime.session.suppressedServices) -notcontains $serviceId) { $runtime.session.suppressedServices += $serviceId }
        }
        Save-TtRegistry $registry $StateRoot
        Save-TtRuntimeStore $runtime $StateRoot

        $started = $false
        $startError = $null
        $observation = $null
        if ($shouldStart) {
            try {
                $observation = Start-TtManagedService $service $registry $runtime $StateRoot
                $started = [bool]$observation.healthy
            }
            catch {
                $startError = Protect-TtLogText $_.Exception.Message
                Write-TtLog -StateRoot $StateRoot -Level warning -Event 'service.register.start-failed' -Message $startError -Data @{ service_id=$serviceId }
            }
            Save-TtRuntimeStore $runtime $StateRoot
        }
        Write-TtLog -StateRoot $StateRoot -Event 'service.registered' -Message "Registered service '$serviceId'." -Data @{ service_id=$serviceId; alias=$service.tunnel.alias; autostart=$service.autostart; watchdog=$service.watchdog; started=$started }
        return [ordered]@{ service=$service; started=$started; startError=$startError; observation=$observation }
    }
}

function Get-TtService {
    [CmdletBinding()]
    param([string]$Id, [string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    if (-not $Id) { return @($registry.services.Values | Sort-Object id) }
    $serviceId = ConvertTo-TtServiceId $Id
    if (-not $registry.services.Contains($serviceId)) { throw "Service '$serviceId' is not registered." }
    return $registry.services[$serviceId]
}

function Unregister-TtService {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Id, [switch]$KeepRunning, [string]$StateRoot)
    $serviceId = ConvertTo-TtServiceId $Id
    if (-not $PSCmdlet.ShouldProcess($serviceId, 'Unregister tunneltend service')) { return }
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot
        $runtime = Get-TtRuntimeStore $StateRoot
        if (-not $registry.services.Contains($serviceId)) { throw "Service '$serviceId' is not registered." }
        $service = $registry.services[$serviceId]
        if (-not $KeepRunning) {
            try { Stop-TtManagedService $service $registry $runtime $StateRoot | Out-Null }
            catch {
                Write-TtLog -StateRoot $StateRoot -Level warning -Event 'service.unregister.stop-failed' -Message $_.Exception.Message -Data @{service_id=$serviceId}
                throw
            }
            finally { Save-TtRuntimeStore $runtime $StateRoot }
        }
        $registry.services.Remove($serviceId)
        $runtime.services.Remove($serviceId)
        $runtime.session.suppressedServices = @($runtime.session.suppressedServices | Where-Object { $_ -ne $serviceId })
        $runtime.session.activeServices = @($runtime.session.activeServices | Where-Object { $_ -ne $serviceId })
        Save-TtRegistry $registry $StateRoot
        Save-TtRuntimeStore $runtime $StateRoot
        return [ordered]@{ serviceId=$serviceId; removed=$true; keptRunning=[bool]$KeepRunning }
    }
}

function Set-TtServicePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [Nullable[bool]]$Enabled,
        [Nullable[bool]]$Autostart,
        [Nullable[bool]]$Watchdog,
        [ValidateSet('running','stopped')][string]$DesiredState,
        [string]$StateRoot
    )
    $serviceId = ConvertTo-TtServiceId $Id
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot
        if (-not $registry.services.Contains($serviceId)) { throw "Service '$serviceId' is not registered." }
        $service = $registry.services[$serviceId]
        if ($null -ne $Enabled) { $service.enabled = [bool]$Enabled }
        if ($null -ne $Autostart) { $service.autostart = [bool]$Autostart }
        if ($null -ne $Watchdog) { $service.watchdog = [bool]$Watchdog }
        if ($DesiredState) { $service.desiredState = $DesiredState }
        $service.updatedAt = Get-TtUtcNow
        Save-TtRegistry $registry $StateRoot
        return $service
    }
}

function Start-TtService {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [string]$StateRoot)
    $serviceId = ConvertTo-TtServiceId $Id
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        Set-TtRunningServiceIntent $registry $runtime $serviceId $StateRoot
        try { return Start-TtManagedService $registry.services[$serviceId] $registry $runtime $StateRoot }
        finally { Save-TtRuntimeStore $runtime $StateRoot }
    }
}

function Stop-TtService {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [switch]$SessionOnly, [string]$StateRoot)
    $serviceId = ConvertTo-TtServiceId $Id
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        if (-not $registry.services.Contains($serviceId)) { throw "Service '$serviceId' is not registered." }
        if (-not $SessionOnly) {
            $registry.services[$serviceId].desiredState = 'stopped'
            $registry.services[$serviceId].updatedAt = Get-TtUtcNow
            Save-TtRegistry $registry $StateRoot
        }
        $runtime.session.activeServices = @($runtime.session.activeServices | Where-Object { $_ -ne $serviceId })
        if ($SessionOnly -and @($runtime.session.suppressedServices) -notcontains $serviceId) { $runtime.session.suppressedServices += $serviceId }
        Save-TtRuntimeStore $runtime $StateRoot
        try { return Stop-TtManagedService $registry.services[$serviceId] $registry $runtime $StateRoot }
        finally { Save-TtRuntimeStore $runtime $StateRoot }
    }
}

function Restart-TtService {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id, [string]$StateRoot)
    $serviceId = ConvertTo-TtServiceId $Id
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
        Set-TtRunningServiceIntent $registry $runtime $serviceId $StateRoot
        try { return Restart-TtManagedService $registry.services[$serviceId] $registry $runtime $StateRoot }
        finally { Save-TtRuntimeStore $runtime $StateRoot }
    }
}

function Import-TtOfficialRuntime {
    [CmdletBinding()]
    param([string[]]$Alias, [switch]$Force, [string]$StateRoot)
    $registry = Get-TtRegistry $StateRoot
    $list = Get-TtOfficialRuntimeList $registry $StateRoot
    $available = @($list.aliases)
    $selected = if (@($Alias).Count -gt 0) { @($Alias) } else { @($available | ForEach-Object { $_.alias }) }
    $results = @()
    foreach ($name in $selected) {
        $status = Get-TtOfficialRuntimeStatus $name $registry $StateRoot
        if (-not $status.known -or -not $status.process) { $results += [ordered]@{ alias=$name; imported=$false; reason='structured-target-unavailable' }; continue }
        $kind = [string]$status.process.target_kind
        $value = [string]$status.process.target_value
        if ($kind -eq 'server_url') { $mcp = [ordered]@{ kind='url'; url=$value } }
        elseif ($kind -eq 'command' -and -not [string]::IsNullOrWhiteSpace($value)) { $mcp = [ordered]@{ kind='commandString'; commandString=$value } }
        else { $results += [ordered]@{ alias=$name; imported=$false; reason='unsupported-target'; targetKind=$kind }; continue }
        $raw = $status.raw
        $id = ConvertTo-TtServiceId $name
        $service = New-TtServiceDefinition -Id $id -DisplayName $name -Mcp $mcp -Alias $name -TunnelId ([string]$status.tunnel_id) -OrganizationId @((Get-TtMapValue (Get-TtMapValue $raw 'remote' @{}) 'organization_ids' @())) -WorkspaceId @((Get-TtMapValue (Get-TtMapValue $raw 'remote' @{}) 'workspace_ids' @())) -Autostart $true -Watchdog $true -SourceWatch $false -Enabled $true -DesiredState running -Defaults $registry.settings.defaults
        Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
            $current = Get-TtRegistry $StateRoot; $runtime = Get-TtRuntimeStore $StateRoot
            if ($current.services.Contains($id) -and -not $Force) { throw "Service '$id' is already registered." }
            $current.services[$id] = $service
            Get-TtRuntimeServiceRecord $runtime $id -Create | Out-Null
            if ($status.running -and @($runtime.session.activeServices) -notcontains $id) { $runtime.session.activeServices += $id }
            Save-TtRegistry $current $StateRoot; Save-TtRuntimeStore $runtime $StateRoot
        } | Out-Null
        $results += [ordered]@{ alias=$name; imported=$true; serviceId=$id; targetKind=$kind }
    }
    return $results
}
