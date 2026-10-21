[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot,
    [string]$StateRoot,
    [switch]$NonInteractive,
    [switch]$DisableAutostart,
    [switch]$DisableAutoUpdate,
    [switch]$DisableWatchdog,
    [string[]]$AutostartAliases,
    [switch]$AllManagedAliases,
    [string[]]$OrganizationId,
    [string[]]$WorkspaceId,
    [string]$RuntimeKeyRef = 'env:CONTROL_PLANE_API_KEY',
    [string]$TunnelClientPath,
    [string]$PowerShellPath,
    [string[]]$RegisterPath,
    [switch]$SkipClientInstall,
    [switch]$SkipPath,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'TunnelTend installation currently targets Windows.' }
if ($PSVersionTable.PSVersion -lt [version]'7.4.0') { throw 'TunnelTend requires PowerShell 7.4 or newer.' }
if ($null -eq $OrganizationId) { $OrganizationId = @() }
if ($null -eq $WorkspaceId) { $WorkspaceId = @() }

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $InstallRoot) { $InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs/TunnelTend' }
$InstallRoot = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($InstallRoot))
. (Join-Path $PSScriptRoot 'InstallationPaths.ps1')
$StateRoot = Resolve-TtInstallationStateRoot $InstallRoot $StateRoot
Assert-TtInstallationRoots $InstallRoot $StateRoot
if (-not $PowerShellPath -and [IO.File]::Exists((Join-Path $InstallRoot 'install.json'))) {
    $previousReceipt = Get-Content -Raw -LiteralPath (Join-Path $InstallRoot 'install.json') | ConvertFrom-Json -AsHashtable
    if ($previousReceipt.Contains('powerShellPath')) { $PowerShellPath = [string]$previousReceipt.powerShellPath }
}

function Read-Choice([string]$Prompt,[bool]$Default) {
    if ($NonInteractive) { return $Default }
    $suffix = if ($Default) {'[Y/n]'} else {'[y/N]'}
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer -match '^(?i)y(?:es)?$'
}

if (-not $NonInteractive) {
    [Console]::WriteLine('TunnelTend will install a local desired-state manager for MCP tunnel services.')
    [Console]::WriteLine('Recommended defaults: start registered services at logon, verify official-client updates daily, and recover unhealthy services every two minutes.')
    $DisableAutostart = -not (Read-Choice 'Enable service autostart at Windows logon?' $true)
    $DisableAutoUpdate = -not (Read-Choice 'Enable verified official tunnel-client updates?' $true)
    $DisableWatchdog = -not (Read-Choice 'Enable autonomous health recovery?' $true)
}

if (-not $PSCmdlet.ShouldProcess($InstallRoot, 'Install TunnelTend')) { return }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tunneltend-install-' + [Guid]::NewGuid().ToString('N'))
$backup = $null
$replacementStarted = $false
$automationInstalled = $false
$automationSnapshot = @{}
$nestedState = Test-TtInstallationPathWithin $StateRoot $InstallRoot
$stateDirectory = if ($nestedState) { ([IO.Path]::GetRelativePath($InstallRoot, $StateRoot) -split '[\\/]')[0] } else { $null }
$stateContainer = if ($nestedState) { Join-Path $InstallRoot $stateDirectory } else { $null }
$preservedState = "$InstallRoot.state-$([Guid]::NewGuid().ToString('N'))"
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $exclude = @('.git','artifacts','.validation')
    foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Force) {
        if ($item.Name -in $exclude) { continue }
        if ($nestedState -and (Test-TtInstallationPathWithin $StateRoot $item.FullName)) {
            if ($item.Name -in @('src','scripts','schemas','tests','docs','brand','carriers','examples')) {
                throw 'A nested StateRoot must use its own directory, separate from TunnelTend program payload paths (for example InstallRoot/data/state).'
            }
            continue
        }
        Copy-Item -LiteralPath $item.FullName -Destination $temp -Recurse -Force
    }
    if ($nestedState) {
        if (Test-Path -LiteralPath (Join-Path $temp $stateDirectory)) {
            throw 'A nested StateRoot must use its own directory, separate from TunnelTend program payload paths (for example InstallRoot/data/state).'
        }
    }
    $nativeHost = Join-Path $temp 'bin/TunnelTend.TaskHost.exe'
    if (-not [IO.File]::Exists($nativeHost)) { & (Join-Path $temp 'scripts/Build-WindowsLauncher.ps1') -OutputPath $nativeHost | Out-Null }
    if ($nestedState -and [IO.Directory]::Exists($stateContainer)) { [IO.Directory]::Move($stateContainer, $preservedState) }
    if (Test-Path -LiteralPath $InstallRoot) {
        $backup = "$InstallRoot.previous-$([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss'))"
        Move-Item -LiteralPath $InstallRoot -Destination $backup -Force
    }
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($InstallRoot)) -Force | Out-Null
    $replacementStarted = $true
    Move-Item -LiteralPath $temp -Destination $InstallRoot
    if ([IO.Directory]::Exists($preservedState)) {
        [IO.Directory]::Move($preservedState, $stateContainer)
    }

    $env:TUNNELTEND_CLI_PATH = Join-Path $InstallRoot 'tunneltend.ps1'
    Import-Module (Join-Path $InstallRoot 'src/TunnelTend/TunnelTend.psd1') -Force
    $PowerShellPath = & (Get-Module TunnelTend | Select-Object -First 1) { param($path) Get-TtPowerShellExecutable $path } $PowerShellPath
    # Acquisition and optional service registration also launch PowerShell. Make
    # the selected runtime available to them inside this rollback transaction.
    $manifest = [ordered]@{ product='tunneltend'; version='1.0.0'; installedAt=[DateTimeOffset]::UtcNow.ToString('o'); installRoot=$InstallRoot; stateRoot=$StateRoot; powerShellPath=$PowerShellPath }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $InstallRoot 'install.json') -Encoding utf8NoBOM
    Set-TtConfiguration -Path 'settings.automation.autostart' -Value (-not $DisableAutostart) -StateRoot $StateRoot | Out-Null
    Set-TtConfiguration -Path 'settings.automation.autoUpdate' -Value (-not $DisableAutoUpdate) -StateRoot $StateRoot | Out-Null
    Set-TtConfiguration -Path 'settings.automation.watchdog' -Value (-not $DisableWatchdog) -StateRoot $StateRoot | Out-Null
    Set-TtConfiguration -Path 'settings.defaults.organizationIds' -Value @($OrganizationId) -StateRoot $StateRoot | Out-Null
    Set-TtConfiguration -Path 'settings.defaults.workspaceIds' -Value @($WorkspaceId) -StateRoot $StateRoot | Out-Null
    Set-TtConfiguration -Path 'settings.defaults.runtimeKeyRef' -Value $RuntimeKeyRef -StateRoot $StateRoot | Out-Null
    if ($TunnelClientPath) {
        $resolvedClient = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($TunnelClientPath))
        if (-not (Test-Path -LiteralPath $resolvedClient -PathType Leaf)) { throw "Tunnel client '$resolvedClient' does not exist." }
        Set-TtConfiguration -Path 'settings.officialClient.executablePath' -Value $resolvedClient -StateRoot $StateRoot | Out-Null
        Set-TtConfiguration -Path 'settings.officialClient.installDirectory' -Value ([IO.Path]::GetDirectoryName($resolvedClient)) -StateRoot $StateRoot | Out-Null
    }
    else {
        Set-TtConfiguration -Path 'settings.officialClient.installDirectory' -Value (Join-Path $InstallRoot 'official-client') -StateRoot $StateRoot | Out-Null
        Set-TtConfiguration -Path 'settings.officialClient.executablePath' -Value (Join-Path $InstallRoot 'official-client/tunnel-client.exe') -StateRoot $StateRoot | Out-Null
    }

    if (-not $SkipClientInstall -and -not $TunnelClientPath) { Update-TtClient -Force -StateRoot $StateRoot | Out-Null }
    $selectedAliases = @($AutostartAliases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($AllManagedAliases -or $selectedAliases.Count -gt 0) {
        Import-TtOfficialRuntime -Alias $(if ($AllManagedAliases) {@()} else {$selectedAliases}) -Force:$Force -StateRoot $StateRoot | Out-Null
    }
    foreach ($path in @($RegisterPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        Register-TtService -Path $path -OrganizationId $OrganizationId -WorkspaceId $WorkspaceId -RuntimeKeyRef $RuntimeKeyRef -Force:$Force -StateRoot $StateRoot | Out-Null
    }
    foreach ($task in (Get-TtAutomationStatus -StateRoot $StateRoot).tasks) {
        if ($task.installed) { $automationSnapshot[$task.name] = Export-ScheduledTask -TaskName $task.name -TaskPath '\TunnelTend\' }
    }
    Install-TtAutomation -StateRoot $StateRoot -PowerShellPath $PowerShellPath | Out-Null
    $automationInstalled = $true
    $doctor = Invoke-TtDoctor -StateRoot $StateRoot
    $status = Get-TtStatus -StateRoot $StateRoot
    # Publish the command only after acquisition, task registration, and the
    # installation receipt succeed. A failed install must not leave a dead PATH.
    if (-not $SkipPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path','User')
        $parts = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($parts -notcontains $InstallRoot) {
            [Environment]::SetEnvironmentVariable('Path', (($parts + $InstallRoot) -join ';'), 'User')
        }
        if (($env:Path -split ';') -notcontains $InstallRoot) { $env:Path = "$InstallRoot;$env:Path" }
    }
    [Console]::WriteLine("TunnelTend installed at $InstallRoot")
    [Console]::WriteLine("State is stored at $StateRoot")
    [Console]::WriteLine("Doctor status: $($doctor.status)")
    [Console]::WriteLine('Open a new terminal, then run: tunneltend status')
    if ($backup -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Recurse -Force }
}
catch {
    $installError = $_
    if ($automationInstalled) {
        Uninstall-TtAutomation | Out-Null
        foreach ($name in $automationSnapshot.Keys) { Register-ScheduledTask -TaskName $name -TaskPath '\TunnelTend\' -Xml $automationSnapshot[$name] -Force | Out-Null }
    }
    if ($replacementStarted -and $nestedState -and [IO.Directory]::Exists($stateContainer)) { [IO.Directory]::Move($stateContainer, $preservedState) }
    if ($replacementStarted -and (Test-Path -LiteralPath $InstallRoot)) { Remove-Item -LiteralPath $InstallRoot -Recurse -Force }
    if ($backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $InstallRoot)) { Move-Item -LiteralPath $backup -Destination $InstallRoot }
    if ([IO.Directory]::Exists($preservedState)) {
        [IO.Directory]::CreateDirectory($InstallRoot) | Out-Null
        [IO.Directory]::Move($preservedState, $stateContainer)
    }
    throw $installError
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
