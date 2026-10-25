Set-StrictMode -Version Latest

# Only the eight settings owned by the installer participate in its recovery.
function Get-TtInstallerSetting {
    param([System.Collections.IDictionary]$Registry, [string]$Path)
    $group, $key = $Path.Split('.')
    $settings = $Registry['settings']
    if ($settings -and $settings.Contains($group) -and $settings[$group].Contains($key)) {
        return @{ present=$true; value=(Copy-TtObject $settings[$group][$key]) }
    }
    return @{ present=$false; value=$null }
}

function Test-TtInstallerSettingEqual {
    param($Left, $Right)
    return ($Left.present -eq $Right.present -and
        (ConvertTo-Json -InputObject $Left.value -Depth 100 -Compress) -ceq
        (ConvertTo-Json -InputObject $Right.value -Depth 100 -Compress))
}

function New-TtInstallerSettingsPlan {
    param([string]$StateRoot, [string]$InstallRoot, [System.Collections.IDictionary]$Parameters)
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot
        Assert-TtRegistry $registry
        Assert-TtNoInlineSecrets $registry.settings 'settings'
        $raw = Read-TtJsonFile (Get-TtPaths $StateRoot).Registry @{}
        $values = [ordered]@{}
        $bindings = [ordered]@{
            'automation.autostart'='DisableAutostart'
            'automation.autoUpdate'='DisableAutoUpdate'
            'automation.watchdog'='DisableWatchdog'
            'defaults.organizationIds'='OrganizationId'
            'defaults.workspaceIds'='WorkspaceId'
            'defaults.runtimeKeyRef'='RuntimeKeyRef'
        }
        foreach ($path in $bindings.Keys) {
            $group, $key = $path.Split('.')
            $parameter = $bindings[$path]
            $values[$path] = Copy-TtObject $registry.settings[$group][$key]
            if ($Parameters.ContainsKey($parameter)) {
                if ($group -eq 'automation') { $values[$path] = -not $Parameters[$parameter] }
                elseif ($key -in @('organizationIds','workspaceIds')) { $values[$path] = @($Parameters[$parameter]) }
                else { $values[$path] = $Parameters[$parameter] }
            }
        }
        $savedExecutable = Get-TtInstallerSetting $raw 'officialClient.executablePath'
        $savedDirectory = Get-TtInstallerSetting $raw 'officialClient.installDirectory'
        $values['officialClient.executablePath'] = if ($savedExecutable.present) { $savedExecutable.value } else { Join-Path $InstallRoot 'official-client/tunnel-client.exe' }
        $values['officialClient.installDirectory'] = if ($savedDirectory.present) { $savedDirectory.value } else { Join-Path $InstallRoot 'official-client' }
        if ($Parameters.ContainsKey('TunnelClientPath')) {
            Assert-TtNoInlineSecrets $Parameters['TunnelClientPath'] 'TunnelClientPath'
            if ([string]::IsNullOrWhiteSpace($Parameters['TunnelClientPath'])) { throw 'TunnelClientPath must name an existing executable.' }
            $client = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Parameters['TunnelClientPath']))
            if (-not [IO.File]::Exists($client)) { throw "Tunnel client '$client' does not exist." }
            $values['officialClient.executablePath'] = $client
            $values['officialClient.installDirectory'] = [IO.Path]::GetDirectoryName($client)
        }
        Assert-TtNoInlineSecrets $values 'installer settings'
        Assert-TtTunnelScopes @{ organizationIds=$values['defaults.organizationIds']; workspaceIds=$values['defaults.workspaceIds'] } 'Registration defaults'
        if (-not (Test-TtSecretReference $values['defaults.runtimeKeyRef'])) { throw 'RuntimeKeyRef must use env:NAME or file:/path.' }
        $before = [ordered]@{}
        foreach ($path in $values.Keys) { $before[$path] = Get-TtInstallerSetting $raw $path }
        return @{ before=$before; values=$values }
    }
}

function Set-TtInstallerSettings {
    param([hashtable]$Plan, [string]$StateRoot, [string]$RecoveryPath)
    return Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $registry = Get-TtRegistry $StateRoot
        $raw = Read-TtJsonFile (Get-TtPaths $StateRoot).Registry @{}
        $changes = [ordered]@{}
        foreach ($path in $Plan.values.Keys) {
            $after = @{ present=$true; value=$Plan.values[$path] }
            if (Test-TtInstallerSettingEqual $Plan.before[$path] $after) { continue }
            if (-not (Test-TtInstallerSettingEqual (Get-TtInstallerSetting $raw $path) $Plan.before[$path])) {
                throw "Installer setting '$path' changed during preparation; retry with current choices."
            }
            $changes[$path] = @{ before=$Plan.before[$path]; after=$after }
            $group, $key = $path.Split('.')
            $registry.settings[$group][$key] = Copy-TtObject $after.value
        }
        if ($changes.Count -gt 0) {
            Assert-TtRegistry $registry
            Write-TtJsonAtomic $RecoveryPath @{ schemaVersion=1; settings=$changes }
            Save-TtRegistry $registry $StateRoot
        }
        return $registry.settings
    }
}

function Undo-TtInstallerSettings {
    param([string]$StateRoot, [string]$RecoveryPath)
    if (-not [IO.File]::Exists($RecoveryPath)) { return }
    Invoke-WithTtLock -StateRoot $StateRoot -ScriptBlock {
        $recovery = Read-TtJsonFile $RecoveryPath $null
        # Read raw state: restoring an absent key must not silently normalize it.
        $registry = Read-TtJsonFile (Get-TtPaths $StateRoot).Registry @{}
        $conflicts = @()
        $changed = $false
        foreach ($path in $recovery.settings.Keys) {
            $entry = $recovery.settings[$path]
            $current = Get-TtInstallerSetting $registry $path
            if (Test-TtInstallerSettingEqual $current $entry.before) { continue }
            if (-not (Test-TtInstallerSettingEqual $current $entry.after)) { $conflicts += $path; continue }
            $group, $key = $path.Split('.')
            if ($entry.before.present) { $registry.settings[$group][$key] = Copy-TtObject $entry.before.value }
            else { $registry.settings[$group].Remove($key) | Out-Null }
            $changed = $true
        }
        if ($changed) {
            Assert-TtRegistry (Repair-TtRegistryShape (Copy-TtObject $registry) $StateRoot)
            Write-TtJsonAtomic (Get-TtPaths $StateRoot).Registry $registry
        }
        if ($conflicts.Count -gt 0) { throw "Settings recovery conflicts: $($conflicts -join ', '). Recovery record retained at '$RecoveryPath'." }
        Remove-Item -LiteralPath $RecoveryPath -Force
    }
}
