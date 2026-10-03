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
    [string[]]$RegisterPath,
    [switch]$SkipClientInstall,
    [switch]$SkipPath,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'TunnelTend installation currently targets Windows.' }
if ($PSVersionTable.PSVersion -lt [version]'7.4.0') { throw 'TunnelTend requires PowerShell 7.4 or newer.' }

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $InstallRoot) { $InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs/TunnelTend' }
if (-not $StateRoot) { $StateRoot = Join-Path $env:LOCALAPPDATA 'TunnelTend/state' }
$InstallRoot = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($InstallRoot))
$StateRoot = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($StateRoot))

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
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $exclude = @('.git','artifacts','.validation')
    foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Force) {
        if ($item.Name -in $exclude) { continue }
        Copy-Item -LiteralPath $item.FullName -Destination $temp -Recurse -Force
    }
    if (Test-Path -LiteralPath $InstallRoot) {
        $backup = "$InstallRoot.previous-$([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss'))"
        Move-Item -LiteralPath $InstallRoot -Destination $backup -Force
    }
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($InstallRoot)) -Force | Out-Null
    Move-Item -LiteralPath $temp -Destination $InstallRoot

    $env:TUNNELTEND_CLI_PATH = Join-Path $InstallRoot 'tunneltend.ps1'
    Import-Module (Join-Path $InstallRoot 'src/TunnelTend/TunnelTend.psd1') -Force
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

    if (-not $SkipPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path','User')
        $parts = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($parts -notcontains $InstallRoot) {
            [Environment]::SetEnvironmentVariable('Path', (($parts + $InstallRoot) -join ';'), 'User')
        }
        if (($env:Path -split ';') -notcontains $InstallRoot) { $env:Path = "$InstallRoot;$env:Path" }
    }

    if (-not $SkipClientInstall -and -not $TunnelClientPath) { Update-TtClient -Force -StateRoot $StateRoot | Out-Null }
    if ($AllManagedAliases -or @($AutostartAliases).Count -gt 0) {
        Import-TtOfficialRuntime -Alias $(if ($AllManagedAliases) {@()} else {@($AutostartAliases)}) -Force:$Force -StateRoot $StateRoot | Out-Null
    }
    foreach ($path in @($RegisterPath)) {
        Register-TtService -Path $path -OrganizationId $OrganizationId -WorkspaceId $WorkspaceId -RuntimeKeyRef $RuntimeKeyRef -Force:$Force -StateRoot $StateRoot | Out-Null
    }
    Install-TtAutomation -StateRoot $StateRoot | Out-Null
    $manifest = [ordered]@{ product='tunneltend'; version='0.1.0-preview.1'; installedAt=[DateTimeOffset]::UtcNow.ToString('o'); installRoot=$InstallRoot; stateRoot=$StateRoot }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $InstallRoot 'install.json') -Encoding utf8NoBOM
    $doctor = Invoke-TtDoctor -StateRoot $StateRoot
    $status = Get-TtStatus -StateRoot $StateRoot
    [Console]::WriteLine("TunnelTend installed at $InstallRoot")
    [Console]::WriteLine("State is stored at $StateRoot")
    [Console]::WriteLine("Doctor status: $($doctor.status)")
    [Console]::WriteLine('Open a new terminal, then run: tunneltend status')
    if ($backup -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Recurse -Force }
}
catch {
    if (Test-Path -LiteralPath $InstallRoot) { Remove-Item -LiteralPath $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if ($backup -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $InstallRoot -Force }
    throw
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
