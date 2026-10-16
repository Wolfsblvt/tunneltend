[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [string]$InstallRoot,
    [string]$StateRoot,
    [switch]$KeepRunning,
    [switch]$PurgeState,
    [switch]$RemoveOfficialClient,
    [switch]$SkipPath,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if (-not $InstallRoot) { $InstallRoot=Join-Path $env:LOCALAPPDATA 'Programs/TunnelTend' }
$InstallRoot=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($InstallRoot))
. (Join-Path $PSScriptRoot 'InstallationPaths.ps1')
$StateRoot=Resolve-TtInstallationStateRoot $InstallRoot $StateRoot
Assert-TtInstallationRoots $InstallRoot $StateRoot
if (-not $PSCmdlet.ShouldProcess($InstallRoot,'Uninstall TunnelTend, including automation, services, PATH entry, and program files')) { return }
$module=Join-Path $InstallRoot 'src/TunnelTend/TunnelTend.psd1'
$loadedModule=$null
if (Test-Path -LiteralPath $module) {
    $env:TUNNELTEND_CLI_PATH=Join-Path $InstallRoot 'tunneltend.ps1'
    $loadedModule=Import-Module $module -Force -PassThru
    try { Uninstall-TtAutomation | Out-Null } catch { Write-Warning $_.Exception.Message }
    if (-not $KeepRunning) {
        foreach ($service in @(Get-TtService -StateRoot $StateRoot)) { try { Stop-TtService -Id $service.id -SessionOnly -StateRoot $StateRoot | Out-Null } catch { Write-Warning $_.Exception.Message } }
    }
    if ($RemoveOfficialClient) {
        $settings=Get-TtConfiguration $StateRoot
        $clientPath=[IO.Path]::GetFullPath([string]$settings.officialClient.executablePath)
        if ((Test-TtInstallationPathWithin $clientPath $InstallRoot) -and -not (Test-TtInstallationPathWithin $clientPath $StateRoot) -and [IO.File]::Exists($clientPath)) { Remove-Item -LiteralPath $clientPath -Force }
    }
}
if (-not $SkipPath) { Remove-TtInstallationPathEntry $InstallRoot }
if (Test-Path -LiteralPath $InstallRoot) {
    $self=[IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
    if (Test-TtInstallationPathWithin $self $InstallRoot) {
        if (-not $loadedModule) { throw 'The installed module is required for quiet self-uninstall cleanup.' }
        $escaped=$InstallRoot.Replace("'","''")
        $escapedState=$StateRoot.Replace("'","''")
        $cleanup = "Start-Sleep -Seconds 2; $(${function:Test-TtInstallationPathWithin}.ToString().Insert(0,'function Test-TtInstallationPathWithin {') + '}'); $(${function:Remove-TtInstallationFiles}.ToString().Insert(0,'function Remove-TtInstallationFiles {') + '}'); Remove-TtInstallationFiles '$escaped' '$escapedState'"
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanup))
        & $loadedModule { param($command) Start-TtDetachedProcess -FilePath (Get-TtPowerShellExecutable) -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-EncodedCommand',$command) } $encoded | Out-Null
    } else { Remove-TtInstallationFiles $InstallRoot $StateRoot }
}
if ($PurgeState -and $PSCmdlet.ShouldProcess($StateRoot,'Permanently remove TunnelTend registry, logs, and backups')) { Remove-Item -LiteralPath $StateRoot -Recurse -Force -ErrorAction SilentlyContinue }
[Console]::WriteLine('TunnelTend uninstalled. State was ' + $(if ($PurgeState) {'removed.'} else {"preserved at $StateRoot."}))
