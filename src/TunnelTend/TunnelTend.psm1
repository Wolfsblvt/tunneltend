Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:TtModuleRoot = $PSScriptRoot

foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File | Sort-Object Name)) {
    . $file.FullName
}
foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File | Sort-Object Name)) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Register-TtService','Get-TtService','Unregister-TtService','Set-TtServicePolicy',
    'Start-TtService','Stop-TtService','Restart-TtService','Import-TtOfficialRuntime',
    'Get-TtStatus','Get-TtHealth','Invoke-TtDoctor','Get-TtRepairPlan','Invoke-TtRepair',
    'Invoke-TtReconcile','Invoke-TtStartup','Invoke-TtWatchdog','Invoke-TtMaintenance',
    'Get-TtClientStatus','Update-TtClient','Restore-TtClient',
    'Install-TtAutomation','Uninstall-TtAutomation','Get-TtAutomationStatus',
    'Get-TtConfiguration','Set-TtConfiguration','Invoke-TtSetup','Invoke-TtCli','Get-TtCliHelp'
)
