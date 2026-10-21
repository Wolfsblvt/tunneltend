@{
    RootModule = 'TunnelTend.psm1'
    ModuleVersion = '1.0.0'
    CompatiblePSEditions = @('Core')
    GUID = '856f4c88-94bf-4d62-b209-352a424489d4'
    Author = 'Wolfsblvt Works'
    CompanyName = 'Wolfsblvt Works'
    Copyright = '(c) 2026 Wolfsblvt Works. Licensed AGPL-3.0-only.'
    Description = 'Desired-state lifecycle manager for registered MCP services using OpenAI tunnel-client.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Register-TtService','Get-TtService','Unregister-TtService','Set-TtServicePolicy',
        'Start-TtService','Stop-TtService','Restart-TtService','Import-TtOfficialRuntime',
        'Get-TtStatus','Get-TtHealth','Invoke-TtDoctor','Get-TtRepairPlan','Invoke-TtRepair',
        'Invoke-TtReconcile','Invoke-TtStartup','Invoke-TtWatchdog','Invoke-TtMaintenance',
        'Get-TtClientStatus','Update-TtClient','Restore-TtClient',
        'Install-TtAutomation','Uninstall-TtAutomation','Get-TtAutomationStatus',
        'Get-TtConfiguration','Set-TtConfiguration','Invoke-TtSetup','Invoke-TtCli','Get-TtCliHelp'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('MCP','OpenAI','tunnel','supervisor','Windows','automation')
            LicenseUri = 'https://www.gnu.org/licenses/agpl-3.0.html'
            ProjectUri = 'https://github.com/Wolfsblvt/tunneltend'
        }
    }
}
