@echo off
setlocal
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo TunnelTend requires PowerShell 7. Install it with:
  echo   winget install --id Microsoft.PowerShell --source winget
  exit /b 10
)
pwsh.exe -NoLogo -NoProfile -File "%~dp0tunneltend.ps1" %*
exit /b %errorlevel%
