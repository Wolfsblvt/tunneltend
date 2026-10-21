BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    # Share one immutable compiled payload. Installer cases exercise real staging
    # and replacement without recompiling identical C# for every scenario.
    $seed = Join-Path $TestDrive 'installer-source'
    New-Item -ItemType Directory -Path $seed | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Force | Where-Object { $_.Name -notin @('.git','artifacts','.validation') } | Copy-Item -Destination $seed -Recurse -Force
    & (Join-Path $seed 'scripts/Build-WindowsLauncher.ps1') -OutputPath (Join-Path $seed 'bin/TunnelTend.TaskHost.exe') | Out-Null
    $script:Installer = Join-Path $seed 'scripts/Install-TunnelTend.ps1'
    $script:Uninstaller = Join-Path $seed 'scripts/Uninstall-TunnelTend.ps1'
}

Describe 'Uninstall preview' {
    It 'does not remove automation or stop services under WhatIf' {
        $install = Join-Path $TestDrive 'preview-program'
        $modulePath = Join-Path $install 'src/TunnelTend/TunnelTend.psd1'
        New-Item -ItemType Directory -Path (Split-Path $modulePath) -Force | Out-Null
        Set-Content -LiteralPath $modulePath -Value ''
        Mock Import-Module { Get-Module TunnelTend | Select-Object -First 1 }
        Mock Uninstall-TtAutomation {}
        Mock Get-TtService { @(@{id='preview-service'}) }
        Mock Stop-TtService {}

        & $script:Uninstaller -InstallRoot $install -StateRoot (Join-Path $TestDrive 'preview-state') -PurgeState -Force -WhatIf

        Should -Invoke Uninstall-TtAutomation -Exactly 0
        Should -Invoke Stop-TtService -Exactly 0
        Test-Path -LiteralPath $modulePath | Should -BeTrue
    }
    It 'removes selected program files with Force in non-interactive PowerShell and preserves state' {
        $install = Join-Path $TestDrive 'forced-program'
        $state = Join-Path $TestDrive 'forced-state'
        New-Item -ItemType Directory -Path $install,$state -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $install 'payload.txt') -Value 'disposable program'
        Set-Content -LiteralPath (Join-Path $state 'registry.json') -Value 'retained state'
        $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.Environment['NO_COLOR'] = '1'
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        foreach ($argument in @('-NoProfile','-NonInteractive','-File',$script:Uninstaller,'-InstallRoot',$install,'-StateRoot',$state,'-SkipPath','-Force')) { $start.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::Start($start)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Forced uninstall specimen timed out.' }
            $process.ExitCode | Should -Be 0 -Because $stderr.GetAwaiter().GetResult()
            $stdout.GetAwaiter().GetResult() | Should -Match 'TunnelTend uninstalled'
        }
        finally { $process.Dispose() }
        Test-Path -LiteralPath $install | Should -BeFalse
        Get-Content -LiteralPath (Join-Path $state 'registry.json') | Should -Be 'retained state'
    }

}

Describe 'Installer optional service selection' {
    It 'does not import every alias or register an empty path when selectors are omitted' {
        Mock Import-Module { Get-Module TunnelTend | Select-Object -First 1 }
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

Describe 'Installer replacement rollback' {
    BeforeEach {
        $script:ExistingInstall = Join-Path $TestDrive 'existing-program'
        New-Item -ItemType Directory -Path $script:ExistingInstall -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:ExistingInstall 'original.txt') -Value 'existing installation'
        Mock Import-Module { Get-Module TunnelTend | Select-Object -First 1 }
        Mock Install-TtAutomation { throw 'Automation must not be reached' }
    }

    It 'preserves an untouched installation when staging fails before backup' {
        Mock Copy-Item { throw 'Simulated staging failure' }

        { & $script:Installer -InstallRoot $script:ExistingInstall -StateRoot (Join-Path $TestDrive 'state') -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*Simulated staging failure*'

        Get-Content -LiteralPath (Join-Path $script:ExistingInstall 'original.txt') | Should -Be 'existing installation'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'existing-program.previous-*').Count | Should -Be 0
        Should -Invoke Install-TtAutomation -Exactly 0
    }

    It 'restores the original installation after replacement configuration fails' {
        Mock Set-TtConfiguration { throw 'Simulated configuration failure' }

        { & $script:Installer -InstallRoot $script:ExistingInstall -StateRoot (Join-Path $TestDrive 'state') -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*Simulated configuration failure*'

        Get-Content -LiteralPath (Join-Path $script:ExistingInstall 'original.txt') | Should -Be 'existing installation'
        Test-Path -LiteralPath (Join-Path $script:ExistingInstall 'tunneltend.ps1') | Should -BeFalse
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'existing-program.previous-*').Count | Should -Be 0
        Should -Invoke Install-TtAutomation -Exactly 0
    }
}

Describe 'Installation state custody' {
    BeforeEach {
        $script:CustodyInstall = Join-Path $TestDrive 'custody-program'
        $script:CustodyState = Join-Path $script:CustodyInstall 'data/state'
        New-Item -ItemType Directory -Path $script:CustodyState -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') -Value 'valued registry'
        Set-Content -LiteralPath (Join-Path $script:CustodyState 'runtime.json') -Value 'valued session'
        Set-Content -LiteralPath (Join-Path (Split-Path $script:CustodyState) 'sibling.txt') -Value 'sibling state'
        Set-Content -LiteralPath (Join-Path $script:CustodyInstall 'old-program.txt') -Value 'old program'
        @{product='tunneltend';installRoot=$script:CustodyInstall;stateRoot=$script:CustodyState} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:CustodyInstall 'install.json')
        Mock Import-Module { Get-Module TunnelTend | Select-Object -First 1 }
        Mock Set-TtConfiguration {}
        Mock Install-TtAutomation {}
        Mock Get-TtAutomationStatus { @{tasks=@()} }
        Mock Uninstall-TtAutomation {}
        Mock Get-TtService { @() }
        Mock Stop-TtService {}
        Mock Invoke-TtDoctor { @{status='ok'} }
        Mock Get-TtStatus { @{} }
    }

    It 'preserves a nested state root at its selected path during reinstall using the receipt' {
        & $script:Installer -InstallRoot $script:CustodyInstall -NonInteractive -SkipClientInstall -SkipPath
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'runtime.json') | Should -Be 'valued session'
        Get-Content -LiteralPath (Join-Path (Split-Path $script:CustodyState) 'sibling.txt') | Should -Be 'sibling state'
        (Get-Content -Raw (Join-Path $script:CustodyInstall 'install.json') | ConvertFrom-Json).stateRoot | Should -Be $script:CustodyState
        Should -Invoke Set-TtConfiguration -ParameterFilter { $StateRoot -eq $script:CustodyState }
        Test-Path -LiteralPath (Join-Path $script:CustodyInstall 'old-program.txt') | Should -BeFalse
    }

    It 'restores program files and nested state after replacement configuration fails' {
        Mock Set-TtConfiguration { throw 'configuration refused' }
        { & $script:Installer -InstallRoot $script:CustodyInstall -StateRoot $script:CustodyState -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*configuration refused*'
        Get-Content -LiteralPath (Join-Path $script:CustodyInstall 'old-program.txt') | Should -Be 'old program'
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'runtime.json') | Should -Be 'valued session'
    }

    It 'preserves the selected public PowerShell and native launcher payload through reinstall' {
        $powerShell = & (Get-Module TunnelTend | Select-Object -First 1) { Get-TtPowerShellExecutable }
        Mock Install-TtAutomation { param($StateRoot,$PowerShellPath) @{powerShellPath=$PowerShellPath} }
        Mock Update-TtClient {
            param($StateRoot)
            $receiptPath = [IO.Path]::GetFullPath((Join-Path $StateRoot '../../install.json'))
            $selected = (Get-Content -Raw $receiptPath | ConvertFrom-Json).powerShellPath
            $selected | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $selected | Should -BeTrue
        }
        & $script:Installer -InstallRoot $script:CustodyInstall -StateRoot $script:CustodyState -PowerShellPath $powerShell -NonInteractive -SkipPath | Out-Null
        & $script:Installer -InstallRoot $script:CustodyInstall -NonInteractive -SkipPath | Out-Null
        (Get-Content -Raw (Join-Path $script:CustodyInstall 'install.json') | ConvertFrom-Json).powerShellPath | Should -Be $powerShell
        Test-Path -LiteralPath (Join-Path $script:CustodyInstall 'bin/TunnelTend.TaskHost.exe') | Should -BeTrue
        Should -Invoke Install-TtAutomation -Exactly 2 -ParameterFilter { $PowerShellPath -eq $powerShell }
        Should -Invoke Update-TtClient -Exactly 2
    }

    It 'uninstalls program files while retaining nested state resolved from the receipt' {
        & $script:Uninstaller -InstallRoot $script:CustodyInstall -SkipPath -Confirm:$false
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'runtime.json') | Should -Be 'valued session'
        Test-Path -LiteralPath (Join-Path $script:CustodyInstall 'old-program.txt') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:CustodyInstall 'install.json') | Should -BeFalse
        Get-Content -LiteralPath (Join-Path (Split-Path $script:CustodyState) 'sibling.txt') | Should -Be 'sibling state'
    }

    It 'resolves a separate custom state root for service shutdown without deleting it' {
        $customState = Join-Path $TestDrive 'separate-custom-state'
        New-Item -ItemType Directory -Path $customState -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $customState 'registry.json') -Value 'separate registry'
        @{product='tunneltend';installRoot=$script:CustodyInstall;stateRoot=$customState} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:CustodyInstall 'install.json')
        $modulePath = Join-Path $script:CustodyInstall 'src/TunnelTend/TunnelTend.psd1'
        New-Item -ItemType Directory -Path (Split-Path $modulePath) -Force | Out-Null
        Set-Content -LiteralPath $modulePath -Value ''
        & $script:Uninstaller -InstallRoot $script:CustodyInstall -SkipPath -Confirm:$false
        Should -Invoke Get-TtService -Exactly 1 -ParameterFilter { $StateRoot -eq $customState }
        Get-Content -LiteralPath (Join-Path $customState 'registry.json') | Should -Be 'separate registry'
    }

    It 'removes nested state only with an explicit purge' {
        & $script:Uninstaller -InstallRoot $script:CustodyInstall -PurgeState -SkipPath -Confirm:$false
        Test-Path -LiteralPath $script:CustodyState | Should -BeFalse
    }

    It 'emits self-uninstall cleanup that also preserves nested state' {
        $scripts = Join-Path $script:CustodyInstall 'scripts'
        New-Item -ItemType Directory -Path $scripts -Force | Out-Null
        Copy-Item -LiteralPath $script:Uninstaller -Destination $scripts
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../scripts/InstallationPaths.ps1') -Destination $scripts
        $modulePath = Join-Path $script:CustodyInstall 'src/TunnelTend/TunnelTend.psd1'
        New-Item -ItemType Directory -Path (Split-Path $modulePath) -Force | Out-Null
        Set-Content -LiteralPath $modulePath -Value ''
        Mock Start-TtDetachedProcess -ModuleName TunnelTend {
            param($ArgumentList)
            $encodedIndex = [Array]::IndexOf($ArgumentList, '-EncodedCommand')
            $encodedIndex | Should -BeGreaterOrEqual 0
            $cleanup = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($ArgumentList[$encodedIndex + 1]))
            & ([scriptblock]::Create($cleanup))
        }
        & (Join-Path $scripts 'Uninstall-TunnelTend.ps1') -InstallRoot $script:CustodyInstall -SkipPath -Confirm:$false
        Should -Invoke Start-TtDetachedProcess -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $ArgumentList -contains '-NoProfile' -and $ArgumentList -contains '-NonInteractive' }
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
        Test-Path -LiteralPath $scripts | Should -BeFalse
    }

    It 'preserves a nested state container junction and its external sibling files' {
        $target = Join-Path $TestDrive 'junction-target'
        $linkedState = Join-Path $script:CustodyInstall 'linked-data/state'
        New-Item -ItemType Directory -Path (Join-Path $target 'state') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $target 'state/registry.json') -Value 'linked registry'
        Set-Content -LiteralPath (Join-Path $target 'unrelated.txt') -Value 'external sibling'
        New-Item -ItemType Junction -Path (Join-Path $script:CustodyInstall 'linked-data') -Target $target | Out-Null
        & $script:Installer -InstallRoot $script:CustodyInstall -StateRoot $linkedState -NonInteractive -SkipClientInstall -SkipPath
        (Get-Item -LiteralPath (Join-Path $script:CustodyInstall 'linked-data')).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $target 'state/registry.json') | Should -Be 'linked registry'
        & $script:Uninstaller -InstallRoot $script:CustodyInstall -SkipPath -Confirm:$false
        Get-Content -LiteralPath (Join-Path $target 'unrelated.txt') | Should -Be 'external sibling'
        Get-Content -LiteralPath (Join-Path $linkedState 'registry.json') | Should -Be 'linked registry'
    }

    It 'rejects identical roots before configuration, automation, or filesystem mutation' {
        { & $script:Installer -InstallRoot $script:CustodyInstall -StateRoot $script:CustodyInstall -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*must differ*'
        { & $script:Uninstaller -InstallRoot $script:CustodyInstall -StateRoot $script:CustodyInstall -SkipPath -Confirm:$false } | Should -Throw '*must differ*'
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
        Should -Invoke Set-TtConfiguration -Exactly 0
        Should -Invoke Uninstall-TtAutomation -Exactly 0
    }

    It 'refuses a nested state collision with staged program payload before replacement' {
        $collisionState = Join-Path $script:CustodyInstall 'assets/state'
        New-Item -ItemType Directory -Path $collisionState -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $collisionState 'registry.json') -Value 'collision state'
        { & $script:Installer -InstallRoot $script:CustodyInstall -StateRoot $collisionState -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*own directory*'
        Get-Content -LiteralPath (Join-Path $collisionState 'registry.json') | Should -Be 'collision state'
        Get-Content -LiteralPath (Join-Path $script:CustodyInstall 'old-program.txt') | Should -Be 'old program'
        Should -Invoke Set-TtConfiguration -Exactly 0
    }

    It 'refuses payload overlap when reinstalling through the installed script itself' {
        & $script:Installer -InstallRoot $script:CustodyInstall -NonInteractive -SkipClientInstall -SkipPath
        $collisionState = Join-Path $script:CustodyInstall 'docs/state'
        New-Item -ItemType Directory -Path $collisionState -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $collisionState 'registry.json') -Value 'installed payload state'
        { & (Join-Path $script:CustodyInstall 'scripts/Install-TunnelTend.ps1') -InstallRoot $script:CustodyInstall -StateRoot $collisionState -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*own directory*'
        Get-Content -LiteralPath (Join-Path $collisionState 'registry.json') | Should -Be 'installed payload state'
        Test-Path -LiteralPath (Join-Path $script:CustodyInstall 'src/TunnelTend/TunnelTend.psd1') | Should -BeTrue
    }

    It 'refuses a malformed receipt before effects and accepts an explicit state override' {
        Set-Content -LiteralPath (Join-Path $script:CustodyInstall 'install.json') -Value '{bad json'
        { & $script:Uninstaller -InstallRoot $script:CustodyInstall -SkipPath -Confirm:$false } | Should -Throw
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
        & $script:Uninstaller -InstallRoot $script:CustodyInstall -StateRoot $script:CustodyState -SkipPath -Confirm:$false
        Get-Content -LiteralPath (Join-Path $script:CustodyState 'registry.json') | Should -Be 'valued registry'
    }
}
