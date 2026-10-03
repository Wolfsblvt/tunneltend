[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [string]$InstallRoot,
    [string]$StateRoot,
    [switch]$KeepRunning,
    [switch]$PurgeState,
    [switch]$RemoveOfficialClient,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if (-not $InstallRoot) { $InstallRoot=Join-Path $env:LOCALAPPDATA 'Programs/TunnelTend' }
if (-not $StateRoot) { $StateRoot=Join-Path $env:LOCALAPPDATA 'TunnelTend/state' }
$InstallRoot=[IO.Path]::GetFullPath($InstallRoot); $StateRoot=[IO.Path]::GetFullPath($StateRoot)
$module=Join-Path $InstallRoot 'src/TunnelTend/TunnelTend.psd1'
if (Test-Path -LiteralPath $module) {
    $env:TUNNELTEND_CLI_PATH=Join-Path $InstallRoot 'tunneltend.ps1'
    Import-Module $module -Force
    try { Uninstall-TtAutomation | Out-Null } catch { Write-Warning $_.Exception.Message }
    if (-not $KeepRunning) {
        foreach ($service in @(Get-TtService -StateRoot $StateRoot)) { try { Stop-TtService -Id $service.id -SessionOnly -StateRoot $StateRoot | Out-Null } catch { Write-Warning $_.Exception.Message } }
    }
    if ($RemoveOfficialClient) {
        $settings=Get-TtConfiguration $StateRoot
        $clientRoot=[IO.Path]::GetFullPath([string]$settings.officialClient.installDirectory)
        if ($clientRoot.StartsWith($InstallRoot,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $clientRoot)) { Remove-Item -LiteralPath $clientRoot -Recurse -Force }
    }
}
$userPath=[Environment]::GetEnvironmentVariable('Path','User')
$parts=@($userPath -split ';' | Where-Object { $_ -and -not [string]::Equals([IO.Path]::GetFullPath($_),$InstallRoot,[StringComparison]::OrdinalIgnoreCase) })
[Environment]::SetEnvironmentVariable('Path',($parts -join ';'),'User')
if ($PSCmdlet.ShouldProcess($InstallRoot,'Remove TunnelTend program files')) {
    if (Test-Path -LiteralPath $InstallRoot) {
        $self=[IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
        if ($self.StartsWith($InstallRoot,[StringComparison]::OrdinalIgnoreCase)) {
            $pwsh=(Get-Process -Id $PID).Path
            $escaped=$InstallRoot.Replace("'","''")
            Start-Process -FilePath $pwsh -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-Command',"Start-Sleep -Seconds 2; Remove-Item -LiteralPath '$escaped' -Recurse -Force") -WindowStyle Hidden
        } else { Remove-Item -LiteralPath $InstallRoot -Recurse -Force }
    }
}
if ($PurgeState -and $PSCmdlet.ShouldProcess($StateRoot,'Permanently remove TunnelTend registry, logs, and backups')) { Remove-Item -LiteralPath $StateRoot -Recurse -Force -ErrorAction SilentlyContinue }
[Console]::WriteLine('TunnelTend uninstalled. State was ' + $(if ($PurgeState) {'removed.'} else {"preserved at $StateRoot."}))
