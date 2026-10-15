Set-StrictMode -Version Latest

function Get-TtUpdaterScriptPath {
    [CmdletBinding()]
    param()
    $path = [IO.Path]::Combine($script:TtModuleRoot, 'Tools', 'Update-OfficialTunnelClient.ps1')
    if (-not [IO.File]::Exists($path)) { throw "Bundled official-client updater is missing at '$path'." }
    return $path
}

function Get-TtLatestOfficialRelease {
    [CmdletBinding()]
    param([hashtable]$Registry, [string]$StateRoot)
    if (-not $Registry) { $Registry = Get-TtRegistry $StateRoot }
    $headers = @{ Accept='application/vnd.github+json'; 'User-Agent'='tunneltend' }
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/openai/tunnel-client/releases/latest' -Headers $headers -TimeoutSec 30
    return ConvertTo-TtHashtable $release
}

function Test-TtOfficialClientUpdateDue {
    [CmdletBinding()]
    param([hashtable]$Registry, [hashtable]$Runtime, [string]$StateRoot, [switch]$Force)
    if ($Force) { return $true }
    if (-not $Registry) { $Registry = Get-TtRegistry $StateRoot }
    if (-not $Runtime) { $Runtime = Get-TtRuntimeStore $StateRoot }
    if (-not $Runtime.officialClient.lastUpdateCheckAt) { return $true }
    $last = [DateTimeOffset]::Parse([string]$Runtime.officialClient.lastUpdateCheckAt)
    return [DateTimeOffset]::UtcNow -ge $last.AddHours([int]$Registry.settings.officialClient.updateCheckHours)
}

function Test-TtOfficialClientNeedsUpdate {
    [CmdletBinding()]
    param([hashtable]$Registry, [string]$StateRoot)
    if (-not $Registry) { $Registry = Get-TtRegistry $StateRoot }
    $installed = Get-TtOfficialClientVersion $Registry $StateRoot
    $latest = Get-TtLatestOfficialRelease $Registry $StateRoot
    $latestVersion = ([string]$latest.tag_name).TrimStart('v')
    $needed = (-not $installed.installed) -or [string]::IsNullOrWhiteSpace([string]$installed.version)
    if ($installed.installed -and $installed.version -and $latestVersion) { $needed = (Compare-TtVersion $installed.version $latestVersion) -lt 0 }
    return [ordered]@{ needed=$needed; installed=$installed; latestTag=$latest.tag_name; latestVersion=$latestVersion; release=$latest }
}

function New-TtOfficialClientBackup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    $install = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$Registry.settings.officialClient.installDirectory))
    if (-not [IO.Directory]::Exists($install)) { return $null }
    $paths = Initialize-TtStateDirectories $StateRoot
    $root = [IO.Path]::Combine($paths.Backups, 'official-client')
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $stamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ')
    $destination = [IO.Path]::Combine($root, $stamp)
    Copy-Item -LiteralPath $install -Destination $destination -Recurse -Force
    $manifest = [ordered]@{ createdAt=Get-TtUtcNow; installDirectory=$install; version=(Get-TtOfficialClientVersion $Registry $StateRoot).version }
    Write-TtJsonAtomic ([IO.Path]::Combine($destination, 'tunneltend-backup.json')) $manifest
    $backups = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)
    foreach ($old in @($backups | Select-Object -Skip 3)) { Remove-Item -LiteralPath $old.FullName -Recurse -Force }
    return $destination
}

function Get-TtOfficialClientUpdaterConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    $paths = Initialize-TtStateDirectories $StateRoot
    return [ordered]@{
        installDirectory = [string]$Registry.settings.officialClient.installDirectory
        executableRelativePath = 'tunnel-client.exe'
        assetName = ''
        runningProcessPolicy = 'Defer'
        clientScheduledTaskName = ''
        clientServiceName = ''
        restartArguments = $null
        restartWorkingDirectory = ''
        backupRetention = 3
        stopTimeoutSeconds = 30
        restartObservationSeconds = 15
        maximumArchiveBytes = 536870912
        maximumExtractedBytes = 1073741824
        maximumArchiveEntries = 2048
        stateDirectory = [IO.Path]::Combine($paths.Root, 'official-client-updater')
        allowUnverifiedAsset = [bool]$Registry.settings.officialClient.allowUnverifiedAsset
        verboseLogging = $false
    }
}

function Invoke-TtBundledUpdater {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot, [switch]$CheckOnly, [switch]$Force)
    $paths = Initialize-TtStateDirectories $StateRoot
    $config = Get-TtOfficialClientUpdaterConfig $Registry $StateRoot
    Write-TtJsonAtomic $paths.ClientUpdater $config
    $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-File',(Get-TtUpdaterScriptPath),'-ConfigPath',$paths.ClientUpdater)
    if ($CheckOnly) { $arguments += '-CheckOnly' }
    if ($Force) { $arguments += '-Force' }
    if ($config.allowUnverifiedAsset) { $arguments += '-AllowUnverifiedAsset' }
    $pwsh = (Get-Process -Id $PID).Path
    return Invoke-TtProcess -FilePath $pwsh -ArgumentList $arguments -TimeoutSeconds 600 -AllowFailure
}

function Invoke-TtOfficialClientUpdateInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [Parameter(Mandatory)][hashtable]$Runtime, [string]$StateRoot, [switch]$Force, [switch]$CheckOnly)
    $check = Test-TtOfficialClientNeedsUpdate $Registry $StateRoot
    $Runtime.officialClient.lastUpdateCheckAt = Get-TtUtcNow
    if ($CheckOnly -or (-not $check.needed -and -not $Force)) {
        $Runtime.officialClient.lastUpdateResult = [ordered]@{ checkedAt=Get-TtUtcNow; changed=$false; installed=$check.installed.version; latest=$check.latestVersion }
        return [ordered]@{ changed=$false; check=$check; stoppedServices=@(); restoredServices=@() }
    }
    if ($check.installed.version -and (Compare-TtVersion $check.installed.version $check.latestVersion) -gt 0) { throw 'Refusing automatic official-client downgrade, including with force.' }
    $install = [IO.Path]::GetFullPath([string]$Registry.settings.officialClient.installDirectory)
    $transactionId = [Guid]::NewGuid().ToString('N')
    $stage = "$install.staged-$transactionId"
    $previous = "$install.previous-$transactionId"
    $stagedRegistry = Copy-TtObject $Registry
    $stagedRegistry.settings.officialClient.installDirectory = $stage
    $stagedRegistry.settings.officialClient.executablePath = Join-Path $stage 'tunnel-client.exe'
    try {
        # The existing hardened updater acquires and verifies into an isolated
        # sibling installation. No active fleet is disturbed during this work.
        $updaterResult = Invoke-TtBundledUpdater $stagedRegistry $StateRoot -Force:$Force
        if ($updaterResult.exit_code -ne 0) { throw "Bundled updater failed: $(Protect-TtLogText (($updaterResult.stderr + $updaterResult.stdout).Trim()))" }
        $version = Get-TtOfficialClientVersion $stagedRegistry $StateRoot
        if (-not $version.installed -or $version.version -ne $check.latestVersion) { throw 'Staged official-client version does not match the selected release.' }
        $capabilities = Test-TtOfficialClientCapabilities $stagedRegistry $StateRoot
        if (-not $capabilities.compatible) { throw 'Staged official client does not provide the capabilities required by tunneltend.' }
        $active = @()
        foreach ($id in @($Registry.services.Keys | Sort-Object)) {
            $observation = Get-TtServiceObservation $Registry.services[$id] $Registry $Runtime $StateRoot
            if ($observation.tunnel.running -or ($observation.host.configured -and $observation.host.running)) { $active += $id }
        }
        $backup = New-TtOfficialClientBackup $Registry $StateRoot
        $stopped = @()
        $restored = @()
        $replacementInstalled = $false
        try {
            foreach ($id in $active) {
                Stop-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null
                $stopped += $id
                Save-TtRuntimeStore $Runtime $StateRoot
            }
            if ([IO.Directory]::Exists($install)) { [IO.Directory]::Move($install, $previous) }
            [IO.Directory]::Move($stage, $install)
            $replacementInstalled = $true
            if (-not (Test-TtOfficialClientCapabilities $Registry $StateRoot).compatible) { throw 'Installed official client does not provide the required capabilities.' }
            foreach ($id in $stopped) {
                $service = $Registry.services[$id]
                if ([bool]$service.enabled -and [string]$service.desiredState -eq 'running') {
                    Start-TtManagedService $service $Registry $Runtime $StateRoot | Out-Null
                    $restored += $id
                }
            }
        }
        catch {
            $updateFailure = $_
            try {
                if ($replacementInstalled) {
                    foreach ($id in $stopped) { Stop-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null }
                    Remove-Item -LiteralPath $install -Recurse -Force
                }
                if ([IO.Directory]::Exists($previous)) { [IO.Directory]::Move($previous, $install) }
                foreach ($id in $stopped) { Start-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null }
                Save-TtRuntimeStore $Runtime $StateRoot
            }
            catch { throw "Official-client update failed and rollback was incomplete. Update: $($updateFailure.Exception.Message) Rollback: $($_.Exception.Message) Previous files: $previous" }
            throw $updateFailure
        }
        if ([IO.Directory]::Exists($previous)) { Remove-Item -LiteralPath $previous -Recurse -Force }
        $Runtime.officialClient.lastUpdateResult = [ordered]@{ checkedAt=Get-TtUtcNow; changed=$true; installed=(Get-TtOfficialClientVersion $Registry $StateRoot).version; latest=$check.latestVersion; backup=$backup }
        return [ordered]@{ changed=$true; check=$check; stoppedServices=$active; restoredServices=$restored; backup=$backup; updater=$updaterResult }
    }
    finally { if ([IO.Directory]::Exists($stage)) { Remove-Item -LiteralPath $stage -Recurse -Force } }
}

function Restore-TtOfficialClientBackupInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [Parameter(Mandatory)][hashtable]$Runtime, [string]$StateRoot, [string]$BackupPath)
    $paths = Initialize-TtStateDirectories $StateRoot
    $backupRoot = [IO.Path]::Combine($paths.Backups, 'official-client')
    if (-not $BackupPath) { $BackupPath = (Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).FullName }
    if (-not $BackupPath -or -not [IO.Directory]::Exists($BackupPath)) { throw 'No official-client backup is available.' }
    $manifestPath = [IO.Path]::Combine($BackupPath, 'tunneltend-backup.json')
    if (-not [IO.File]::Exists($manifestPath)) { throw "Backup '$BackupPath' does not contain a tunneltend manifest." }
    $active = @()
    foreach ($id in $Registry.services.Keys) {
        $observation = Get-TtServiceObservation $Registry.services[$id] $Registry $Runtime $StateRoot
        if ($observation.tunnel.running) { $active += $id; Stop-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null }
    }
    $install = [IO.Path]::GetFullPath([string]$Registry.settings.officialClient.installDirectory)
    $failedCopy = "$install.failed-$([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss'))"
    if ([IO.Directory]::Exists($install)) { [IO.Directory]::Move($install, $failedCopy) }
    try {
        Copy-Item -LiteralPath $BackupPath -Destination $install -Recurse -Force
        Remove-Item -LiteralPath ([IO.Path]::Combine($install, 'tunneltend-backup.json')) -Force -ErrorAction SilentlyContinue
        $capabilities = Test-TtOfficialClientCapabilities $Registry $StateRoot
        if (-not $capabilities.compatible) { throw 'Restored client does not meet tunneltend capability requirements.' }
    }
    catch {
        if ([IO.Directory]::Exists($install)) { Remove-Item -LiteralPath $install -Recurse -Force }
        if ([IO.Directory]::Exists($failedCopy)) { [IO.Directory]::Move($failedCopy, $install) }
        throw
    }
    if ([IO.Directory]::Exists($failedCopy)) { Remove-Item -LiteralPath $failedCopy -Recurse -Force }
    foreach ($id in $active) { Start-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null }
    return [ordered]@{ restored=$true; backup=$BackupPath; version=(Get-TtOfficialClientVersion $Registry $StateRoot).version; services=$active }
}
