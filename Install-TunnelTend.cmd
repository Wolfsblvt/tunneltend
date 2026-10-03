@echo off
setlocal
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo TunnelTend requires PowerShell 7.
  echo Install it with: winget install --id Microsoft.PowerShell --source winget
  pause
  exit /b 10
)
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\Install-TunnelTend.ps1" %*
if errorlevel 1 pause
exit /b %errorlevel%
