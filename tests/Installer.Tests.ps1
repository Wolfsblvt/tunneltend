BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Installer = Join-Path $PSScriptRoot '../scripts/Install-TunnelTend.ps1'
    $script:Uninstaller = Join-Path $PSScriptRoot '../scripts/Uninstall-TunnelTend.ps1'
}

Describe 'Uninstall preview' {
    It 'does not remove automation or stop services under WhatIf' {
        $install = Join-Path $TestDrive 'preview-program'
        $modulePath = Join-Path $install 'src/TunnelTend/TunnelTend.psd1'
        New-Item -ItemType Directory -Path (Split-Path $modulePath) -Force | Out-Null
        Set-Content -LiteralPath $modulePath -Value ''
        Mock Import-Module {}
        Mock Uninstall-TtAutomation {}
        Mock Get-TtService { @(@{id='preview-service'}) }
        Mock Stop-TtService {}

        & $script:Uninstaller -InstallRoot $install -StateRoot (Join-Path $TestDrive 'preview-state') -PurgeState -WhatIf

        Should -Invoke Uninstall-TtAutomation -Exactly 0
        Should -Invoke Stop-TtService -Exactly 0
        Test-Path -LiteralPath $modulePath | Should -BeTrue
    }
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
