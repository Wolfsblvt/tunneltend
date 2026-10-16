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
    $executable = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$Registry.settings.officialClient.executablePath))
    if (-not [IO.File]::Exists($executable)) { return $null }
    $paths = Initialize-TtStateDirectories $StateRoot
    $root = [IO.Path]::Combine($paths.Backups, 'official-client')
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $stamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ') + '-' + [Guid]::NewGuid().ToString('N')
    $destination = [IO.Path]::Combine($root, $stamp)
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    Copy-Item -LiteralPath $executable -Destination (Join-Path $destination 'tunnel-client.exe')
    $manifest = [ordered]@{ createdAt=Get-TtUtcNow; installDirectory=[IO.Path]::GetDirectoryName($executable); executableRelativePath='tunnel-client.exe'; version=(Get-TtOfficialClientVersion $Registry $StateRoot).version }
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
        allowUnverifiedAsset = $false
        verboseLogging = $false
    }
}

function Invoke-TtBundledUpdater {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot, [switch]$CheckOnly, [switch]$Force)
    Assert-TtRegistry $Registry
    $paths = Initialize-TtStateDirectories $StateRoot
    $config = Get-TtOfficialClientUpdaterConfig $Registry $StateRoot
    Write-TtJsonAtomic $paths.ClientUpdater $config
    $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-File',(Get-TtUpdaterScriptPath),'-ConfigPath',$paths.ClientUpdater,'-RequirePublishedChecksum')
    if ($CheckOnly) { $arguments += '-CheckOnly' }
    if ($Force) { $arguments += '-Force' }
    $pwsh = (Get-Process -Id $PID).Path
    return Invoke-TtProcess -FilePath $pwsh -ArgumentList $arguments -TimeoutSeconds 600 -AllowFailure
}

function Restore-TtClientFleet {
    [CmdletBinding()]
    param([hashtable]$Registry, [hashtable]$Runtime, [string]$StateRoot, [string[]]$ServiceId)
    $results = @()
    foreach ($id in $ServiceId) {
        try {
            Start-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null
            $results += [ordered]@{ serviceId=$id; ok=$true }
        }
        catch { $results += [ordered]@{ serviceId=$id; ok=$false; error=Protect-TtLogText $_.Exception.Message } }
        finally { Save-TtRuntimeStore $Runtime $StateRoot }
    }
    return $results
}

function Invoke-TtClientFileTransaction {
    [CmdletBinding()]
    param([hashtable]$Registry, [hashtable]$Runtime, [string]$StateRoot, [string]$Payload)
    $executable = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$Registry.settings.officialClient.executablePath))
    if (-not [IO.File]::Exists($Payload)) { throw 'The staged official-client executable is missing.' }
    $directory = [IO.Path]::GetDirectoryName($executable)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $transaction = [Guid]::NewGuid().ToString('N')
    $pending = "$executable.pending-$transaction"
    $previous = "$executable.previous-$transaction"
    $stopped = @()
    $restore = @()
    $replaced = $false
    $replacementStarted = @()
    $results = @()
    try {
        # Copy before downtime; both renames then stay on the target volume.
        Copy-Item -LiteralPath $Payload -Destination $pending
        $active = @()
        foreach ($id in @($Registry.services.Keys | Sort-Object)) {
            $observation = Get-TtServiceObservation $Registry.services[$id] $Registry $Runtime $StateRoot
            if ($observation.tunnel.running -or ($observation.host.configured -and $observation.host.running)) { $active += $id }
        }
        foreach ($id in $active) {
            # A stop can partly succeed before throwing. Retain that recovery coordinate.
            $stopped += $id
            if (Test-TtServiceDesiredRunning $Registry.services[$id] $Runtime maintenance) { $restore += $id }
            try { Stop-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null }
            finally { Save-TtRuntimeStore $Runtime $StateRoot }
        }
        if ([IO.File]::Exists($executable)) { [IO.File]::Move($executable, $previous) }
        [IO.File]::Move($pending, $executable)
        $replaced = $true
        if (-not (Test-TtOfficialClientCapabilities $Registry $StateRoot).compatible) { throw 'Installed official client does not provide the required capabilities.' }
        $replacementStarted = @($restore)
        $results = @(Restore-TtClientFleet $Registry $Runtime $StateRoot $restore)
        $failed = @($results | Where-Object { -not $_.ok })
        if ($failed.Count -gt 0) { throw ('Client fleet restoration failed: ' + (($failed | ForEach-Object { "$($_.serviceId): $($_.error)" }) -join '; ')) }
    }
    catch {
        $failure = $_
        $rollbackErrors = @()
        if ($replaced) {
            # Stop every possibly started replacement runtime before restoring its binary.
            foreach ($id in $replacementStarted) {
                try { Stop-TtManagedService $Registry.services[$id] $Registry $Runtime $StateRoot | Out-Null }
                catch { $rollbackErrors += "$id stop: $(Protect-TtLogText $_.Exception.Message)" }
                finally { Save-TtRuntimeStore $Runtime $StateRoot }
            }
        }
        if ($rollbackErrors.Count -eq 0) {
            try {
                if ($replaced -and [IO.File]::Exists($executable)) { [IO.File]::Delete($executable) }
                if ([IO.File]::Exists($previous)) { [IO.File]::Move($previous, $executable) }
            }
            catch { $rollbackErrors += Protect-TtLogText $_.Exception.Message }
        }
        if ($rollbackErrors.Count -eq 0) {
            $recoveryResults = @(Restore-TtClientFleet $Registry $Runtime $StateRoot $restore)
            foreach ($result in $recoveryResults) { if (-not $result.ok) { $rollbackErrors += "$($result.serviceId): $($result.error)" } }
        }
        if ($rollbackErrors.Count -gt 0) {
            throw "Client replacement failed and recovery was incomplete. Failure: $($failure.Exception.Message) Recovery: $($rollbackErrors -join '; ') Fallback file (if replacement occurred): $previous"
        }
        throw $failure
    }
    finally { if ([IO.File]::Exists($pending)) { [IO.File]::Delete($pending) } }
    # Keep the fallback through capability AND fleet verification.
    if ([IO.File]::Exists($previous)) { [IO.File]::Delete($previous) }
    return [ordered]@{ stoppedServices=$stopped; restoredServices=@($results | ForEach-Object serviceId); serviceResults=$results }
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
    $paths = Initialize-TtStateDirectories $StateRoot
    $stage = Join-Path $paths.Work ('client-staged-' + [Guid]::NewGuid().ToString('N'))
    $stagedRegistry = Copy-TtObject $Registry
    $stagedRegistry.settings.officialClient.installDirectory = $stage
    $stagedRegistry.settings.officialClient.executablePath = Join-Path $stage 'tunnel-client.exe'
    try {
        $updaterResult = Invoke-TtBundledUpdater $stagedRegistry $StateRoot -Force:$Force
        if ($updaterResult.exit_code -ne 0) { throw "Bundled updater failed: $(Protect-TtLogText (($updaterResult.stderr + $updaterResult.stdout).Trim()))" }
        $version = Get-TtOfficialClientVersion $stagedRegistry $StateRoot
        if (-not $version.installed -or $version.version -ne $check.latestVersion) { throw 'Staged official-client version does not match the selected release.' }
        if (-not (Test-TtOfficialClientCapabilities $stagedRegistry $StateRoot).compatible) { throw 'Staged official client does not provide the capabilities required by tunneltend.' }
        $backup = New-TtOfficialClientBackup $Registry $StateRoot
        $result = Invoke-TtClientFileTransaction $Registry $Runtime $StateRoot $stagedRegistry.settings.officialClient.executablePath
        $Runtime.officialClient.lastUpdateResult = [ordered]@{ checkedAt=Get-TtUtcNow; changed=$true; installed=(Get-TtOfficialClientVersion $Registry $StateRoot).version; latest=$check.latestVersion; backup=$backup }
        return [ordered]@{ changed=$true; check=$check; stoppedServices=$result.stoppedServices; restoredServices=$result.restoredServices; serviceResults=$result.serviceResults; backup=$backup; updater=$updaterResult }
    }
    finally { if ([IO.Directory]::Exists($stage)) { Remove-Item -LiteralPath $stage -Recurse -Force } }
}

function Restore-TtOfficialClientBackupInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [Parameter(Mandatory)][hashtable]$Runtime, [string]$StateRoot, [string]$BackupPath)
    $paths = Initialize-TtStateDirectories $StateRoot
    $backupRoot = [IO.Path]::Combine($paths.Backups, 'official-client')
    if (-not $BackupPath) {
        $latest = Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) { $BackupPath = $latest.FullName }
    }
    if (-not $BackupPath -or -not [IO.Directory]::Exists($BackupPath)) { throw 'No official-client backup is available.' }
    $manifestPath = Join-Path $BackupPath 'tunneltend-backup.json'
    if (-not [IO.File]::Exists($manifestPath)) { throw "Backup '$BackupPath' does not contain a tunneltend manifest." }
    $manifest = Read-TtJsonFile $manifestPath
    # Older directory snapshots remain usable, but only their selected executable
    # is restored; unrelated files in them never become our replacement payload.
    $name = [string](Get-TtMapValue $manifest 'executableRelativePath' ([IO.Path]::GetFileName([string]$Registry.settings.officialClient.executablePath)))
    if (-not $name -or [IO.Path]::GetFileName($name) -ne $name -or $name -in @('.','..')) { throw 'The backup executable must be a filename within the backup directory.' }
    $payload = Join-Path $BackupPath $name
    if (-not [IO.File]::Exists($payload)) { throw 'The backup does not contain the selected executable.' }
    $stagedRegistry = Copy-TtObject $Registry
    $stagedRegistry.settings.officialClient.executablePath = $payload
    if (-not (Test-TtOfficialClientCapabilities $stagedRegistry $StateRoot).compatible) { throw 'Restored client does not meet tunneltend capability requirements.' }
    $result = Invoke-TtClientFileTransaction $Registry $Runtime $StateRoot $payload
    return [ordered]@{ restored=$true; backup=$BackupPath; version=(Get-TtOfficialClientVersion $Registry $StateRoot).version; services=$result.restoredServices; serviceResults=$result.serviceResults }
}
