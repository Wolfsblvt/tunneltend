BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Installer = Join-Path $PSScriptRoot '../scripts/Install-TunnelTend.ps1'
}

Describe 'Installer optional service selection' {
    It 'does not import every alias or register an empty path when selectors are omitted' {
        Mock Import-Module {}
        Mock Set-TtConfiguration {}
        Mock Install-TtAutomation {}
        Mock Get-TtAutomationStatus { @{ tasks = @() } }
        Mock Invoke-TtDoctor { @{ status = 'ok' } }
        Mock Get-TtStatus { @{} }
        Mock Import-TtOfficialRuntime { throw 'Unexpected runtime import' }
        Mock Register-TtService { throw 'Unexpected service registration' }

        & $script:Installer -InstallRoot (Join-Path $TestDrive 'program') -StateRoot (Join-Path $TestDrive 'state') -NonInteractive -SkipClientInstall -SkipPath

        Should -Invoke Install-TtAutomation -Exactly 1
        Should -Invoke Import-TtOfficialRuntime -Exactly 0
        Should -Invoke Register-TtService -Exactly 0
        Test-Path -LiteralPath (Join-Path $TestDrive 'program/install.json') | Should -BeTrue
    }
}
