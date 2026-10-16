BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:DiscoveryModule = Get-Module TunnelTend
    $script:ProgramRoot = Join-Path $TestDrive 'program files'
    $script:LocalRoot = Join-Path $TestDrive 'local app data'
    $script:ProgramExecutable = Join-Path $script:ProgramRoot 'PowerShell/7/pwsh.exe'
    $script:AliasExecutable = Join-Path $script:LocalRoot 'Microsoft/WindowsApps/pwsh.exe'
    foreach ($path in @($script:ProgramExecutable,$script:AliasExecutable)) {
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        New-Item -ItemType File -Path $path | Out-Null
    }
}

Describe 'PowerShell discovery with optional environment roots' {
    BeforeEach {
        $script:OriginalProgramFiles = $env:ProgramFiles
        $script:OriginalLocalAppData = $env:LOCALAPPDATA
        $script:OriginalModuleRoot = & $script:DiscoveryModule { $script:TtModuleRoot }
        & $script:DiscoveryModule { param($root) $script:TtModuleRoot = $root } (Join-Path $TestDrive 'source/src/TunnelTend')
        $env:ProgramFiles = $null
        $env:LOCALAPPDATA = $null
    }

    AfterEach {
        $env:ProgramFiles = $script:OriginalProgramFiles
        $env:LOCALAPPDATA = $script:OriginalLocalAppData
        & $script:DiscoveryModule { param($root) $script:TtModuleRoot = $root } $script:OriginalModuleRoot
    }

    It 'uses the user alias when ProgramFiles is absent or blank' -ForEach @(@{root=$null},@{root='   '}) {
        $env:ProgramFiles = $root
        $env:LOCALAPPDATA = $script:LocalRoot
        & $script:DiscoveryModule { Get-TtPowerShellExecutable } | Should -Be $script:AliasExecutable
    }

    It 'uses the normal installation when LOCALAPPDATA is absent' {
        $env:ProgramFiles = $script:ProgramRoot
        & $script:DiscoveryModule { Get-TtPowerShellExecutable } | Should -Be $script:ProgramExecutable
        & $script:DiscoveryModule { param($path) Resolve-TtPowerShellProcessPath $path } $script:ProgramExecutable | Should -Be $script:ProgramExecutable
    }

    It 'falls through an unavailable installation to the user alias' {
        $env:ProgramFiles = Join-Path $TestDrive 'unavailable program files'
        $env:LOCALAPPDATA = $script:LocalRoot
        & $script:DiscoveryModule { Get-TtPowerShellExecutable } | Should -Be $script:AliasExecutable
    }

    It 'preserves normal-installation precedence when both candidates exist' {
        $env:ProgramFiles = $script:ProgramRoot
        $env:LOCALAPPDATA = $script:LocalRoot
        & $script:DiscoveryModule { Get-TtPowerShellExecutable } | Should -Be $script:ProgramExecutable
    }

    It 'keeps explicit portable selection independent of either environment root' {
        & $script:DiscoveryModule { param($path) Get-TtPowerShellExecutable $path } $script:ProgramExecutable | Should -Be $script:ProgramExecutable
        & $script:DiscoveryModule { param($path) Resolve-TtPowerShellProcessPath $path } $script:ProgramExecutable | Should -Be $script:ProgramExecutable
    }

    It 'reports the actionable absence when neither root is available' {
        { & $script:DiscoveryModule { Get-TtPowerShellExecutable } } | Should -Throw '*Install PowerShell 7.4*PowerShellPath*'
    }
}
