BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $seed=Join-Path $TestDrive 'source'
    New-Item -ItemType Directory -Path $seed | Out-Null
    Get-ChildItem (Join-Path $PSScriptRoot '..') -Force | Where-Object Name -NotIn @('.git','artifacts','.validation','website') | Copy-Item -Destination $seed -Recurse -Force
    & (Join-Path $seed 'scripts/Build-WindowsLauncher.ps1') -OutputPath (Join-Path $seed 'bin/TunnelTend.TaskHost.exe') | Out-Null
    $script:Installer=Join-Path $seed 'scripts/Install-TunnelTend.ps1'
}

Describe 'Installer upgrade continuity' {
    BeforeEach {
        $case=Join-Path $TestDrive ([Guid]::NewGuid().ToString('N'))
        $script:Install=Join-Path $case 'program'
        $script:State=Join-Path $case 'state'
        $script:Client=Join-Path $case 'external/custom-client.exe'
        New-Item -ItemType Directory -Path (Split-Path $script:Client),$script:Install -Force | Out-Null
        Set-Content $script:Client 'external binary fixture'
        Set-Content (Join-Path $script:Install 'old.txt') 'previous payload'
        & (Get-Module TunnelTend) {
            param($state,$client)
            $registry=Get-TtRegistry $state
            foreach ($key in @('autostart','autoUpdate','watchdog')) { $registry.settings.automation[$key]=$false }
            $registry.settings.defaults.organizationIds=@('org_saved')
            $registry.settings.defaults.runtimeKeyRef='env:SAVED_KEY'
            $registry.settings.officialClient.executablePath=$client
            $registry.settings.officialClient.installDirectory=Split-Path $client
            Save-TtRegistry $registry $state
        } $script:State $script:Client
        Register-TtService -Id saved-service -Url 'http://localhost:12345/mcp' -NoStart -StateRoot $script:State | Out-Null
        $script:Before=Get-TtConfiguration -StateRoot $script:State | ConvertTo-Json -Depth 100 -Compress
        $script:Services=Get-TtService -StateRoot $script:State | ConvertTo-Json -Depth 100 -Compress
        $script:Runtime=Get-Content -Raw (Join-Path $script:State 'runtime.json')
        Mock Import-Module { Get-Module TunnelTend | Select-Object -First 1 }
        Mock Install-TtAutomation {}
        Mock Get-TtAutomationStatus { @{tasks=@()} }
        Mock Invoke-TtDoctor { @{status='ok'} }
        Mock Get-TtStatus { @{} }
        Mock Update-TtClient {}
    }

    It 'preserves omitted preferences, external client, registrations and runtime intent' {
        Mock Install-TtAutomation {
            param($StateRoot)
            $settings=Get-TtConfiguration -StateRoot $StateRoot
            $settings.automation.autostart | Should -BeFalse
            $settings.automation.autoUpdate | Should -BeFalse
            $settings.automation.watchdog | Should -BeFalse
        }
        & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -NonInteractive -SkipClientInstall -SkipPath
        (Get-TtConfiguration -StateRoot $script:State | ConvertTo-Json -Depth 100 -Compress) | Should -Be $script:Before
        (Get-TtService -StateRoot $script:State | ConvertTo-Json -Depth 100 -Compress) | Should -Be $script:Services
        (Get-Content -Raw (Join-Path $script:State 'runtime.json')) | Should -Be $script:Runtime
    }

    It 'preserves retained state without any program files or receipt' {
        Remove-Item -LiteralPath $script:Install -Recurse -Force
        & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -NonInteractive -SkipClientInstall -SkipPath
        (Get-TtConfiguration -StateRoot $script:State | ConvertTo-Json -Depth 100 -Compress) | Should -Be $script:Before
    }

    It 'preserves nested state resolved through its receipt' {
        $nested=Join-Path $script:Install 'data/state'
        New-Item -ItemType Directory -Path (Split-Path $nested) -Force | Out-Null
        Move-Item $script:State $nested
        @{product='tunneltend';stateRoot=$nested} | ConvertTo-Json | Set-Content (Join-Path $script:Install 'install.json')
        & $script:Installer -InstallRoot $script:Install -NonInteractive -SkipClientInstall -SkipPath
        (Get-TtConfiguration -StateRoot $nested | ConvertTo-Json -Depth 100 -Compress) | Should -Be $script:Before
        (Get-Content -Raw (Join-Path $nested 'runtime.json')) | Should -Be $script:Runtime
    }

    It 'honors false disable switches and empty scopes and forwards effective defaults for registration' {
        Mock Register-TtService {}
        & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -OrganizationId @() -RegisterPath 'fixture-project' -NonInteractive -SkipClientInstall -SkipPath
        $settings=Get-TtConfiguration -StateRoot $script:State
        $settings.automation.autostart | Should -BeTrue
        $settings.automation.watchdog | Should -BeFalse
        @($settings.defaults.organizationIds).Count | Should -Be 0
        $settings.defaults.runtimeKeyRef | Should -Be 'env:SAVED_KEY'
        Should -Invoke Register-TtService -Exactly 1 -ParameterFilter { @($OrganizationId).Count -eq 0 -and $RuntimeKeyRef -eq 'env:SAVED_KEY' }
    }

    It 'uses saved interactive defaults and does not prompt over explicit choices' {
        Mock Read-Host { '' }
        & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -SkipClientInstall -SkipPath
        Should -Invoke Read-Host -Exactly 2 -ParameterFilter { ($Prompt -join ' ').Contains('[y/N]') }
        $settings=Get-TtConfiguration -StateRoot $script:State
        $settings.automation.autostart | Should -BeTrue
        $settings.automation.watchdog | Should -BeFalse
        $settings.automation.autoUpdate | Should -BeFalse
    }

    It 'retains autonomous defaults for genuinely new state' {
        $state=Join-Path $TestDrive 'new-state'
        & $script:Installer -InstallRoot $script:Install -StateRoot $state -NonInteractive -SkipClientInstall -SkipPath
        $settings=Get-TtConfiguration -StateRoot $state
        $settings.automation.autostart | Should -BeTrue
        $settings.automation.watchdog | Should -BeTrue
        $settings.automation.autoUpdate | Should -BeTrue
        $settings.defaults.runtimeKeyRef | Should -Be 'env:CONTROL_PLANE_API_KEY'
        $settings.officialClient.executablePath | Should -Be (Join-Path $script:Install 'official-client/tunnel-client.exe')
    }

    It 'refuses a missing explicit client before replacing payload or publishing settings' {
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -TunnelClientPath (Join-Path $TestDrive 'missing.exe') -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*does not exist*'
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
        (Get-TtConfiguration -StateRoot $script:State | ConvertTo-Json -Depth 100 -Compress) | Should -Be $script:Before
        Should -Invoke Install-TtAutomation -Exactly 0
    }

    It 'refuses invalid retained state before replacement' {
        Set-Content (Join-Path $script:State 'registry.json') '{invalid'
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*not valid JSON*'
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
    }

    It 'rejects inline credential material before a client-path error could echo it' {
        $synthetic='sk-installerfixture1234567890'
        $caught=$null
        try { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -TunnelClientPath $synthetic -NonInteractive -SkipClientInstall -SkipPath }
        catch { $caught=$_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -Not -Match ([regex]::Escape($synthetic))
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
    }

    It 'validates an explicit replacement client and applies its coordinate' {
        $replacement=Join-Path (Split-Path $script:Client) 'replacement.exe'
        Set-Content $replacement 'replacement fixture'
        & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -TunnelClientPath $replacement -NonInteractive -SkipClientInstall -SkipPath
        $settings=Get-TtConfiguration -StateRoot $script:State
        $settings.officialClient.executablePath | Should -Be $replacement
        $settings.officialClient.installDirectory | Should -Be (Split-Path $replacement)
    }

    It 'restores originally absent settings without rewinding registrations' {
        & (Get-Module TunnelTend) {
            param($state)
            $registry=Get-TtRegistry $state
            $registry.settings.defaults.Remove('organizationIds')
            $registry.settings.automation.Remove('autostart')
            Write-TtJsonAtomic (Get-TtPaths $state).Registry $registry
        } $script:State
        Mock Install-TtAutomation { throw 'absence recovery specimen' }
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -OrganizationId @('org_explicit') -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*absence recovery specimen*'
        $raw=Get-Content -Raw (Join-Path $script:State 'registry.json') | ConvertFrom-Json -AsHashtable
        $raw.settings.defaults.Contains('organizationIds') | Should -BeFalse
        $raw.settings.automation.Contains('autostart') | Should -BeFalse
        $raw.services.Contains('saved-service') | Should -BeTrue
    }

    It 'restores settings after a late failure with nested state <Nested> while retaining unrelated writes' -ForEach @(@{Nested=$false},@{Nested=$true}) {
        if ($Nested) {
            $nestedState=Join-Path $script:Install 'data/state'
            New-Item -ItemType Directory -Path (Split-Path $nestedState) -Force | Out-Null
            Move-Item $script:State $nestedState
            $script:State=$nestedState
            @{product='tunneltend';stateRoot=$nestedState} | ConvertTo-Json | Set-Content (Join-Path $script:Install 'install.json')
        }
        Mock Install-TtAutomation {
            param($StateRoot)
            (Get-TtConfiguration -StateRoot $StateRoot).automation.autostart | Should -BeTrue
            Set-TtConfiguration -Path settings.automation.maintenanceHour -Value 7 -StateRoot $StateRoot | Out-Null
            throw 'late automation failure'
        }
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*late automation failure*'
        $settings=Get-TtConfiguration -StateRoot $script:State
        $settings.automation.autostart | Should -BeFalse
        $settings.automation.maintenanceHour | Should -Be 7
        (Get-Content -Raw (Join-Path $script:State 'runtime.json')) | Should -Be $script:Runtime
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
        @(Get-ChildItem $script:State -Filter 'installer-recovery-*.json').Count | Should -Be 0
    }

    It 'keeps a successful installation usable when previous-payload cleanup fails' {
        $held=@{stream=$null}
        $holdBackup={
            param($StateRoot)
            $previous=Get-ChildItem (Split-Path $StateRoot) -Directory -Filter 'program.previous-*' | Select-Object -First 1
            $held.stream=[IO.File]::Open((Join-Path $previous.FullName 'old.txt'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        }.GetNewClosure()
        Mock Install-TtAutomation -MockWith $holdBackup
        try {
            & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -NonInteractive -SkipClientInstall -SkipPath -WarningAction SilentlyContinue
        }
        finally { if ($held.stream) { $held.stream.Dispose() } }
        (Get-TtConfiguration -StateRoot $script:State).automation.autostart | Should -BeTrue
        Test-Path (Join-Path $script:Install 'tunneltend.ps1') | Should -BeTrue
        @(Get-ChildItem (Split-Path $script:Install) -Filter 'program.previous-*').Count | Should -Be 1
    }

    It 'preserves conflicting intent and reports a retained scoped recovery record' {
        Mock Install-TtAutomation {
            param($StateRoot)
            Set-TtConfiguration -Path settings.defaults.organizationIds -Value @('org_concurrent') -StateRoot $StateRoot | Out-Null
            throw 'late automation conflict'
        }
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -OrganizationId @('org_requested') -DisableAutostart:$false -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*late automation conflict*Recovery incomplete*defaults.organizationIds*'
        $settings=Get-TtConfiguration -StateRoot $script:State
        $settings.defaults.organizationIds | Should -Be @('org_concurrent')
        $settings.automation.autostart | Should -BeFalse
        $records=@(Get-ChildItem $script:State -Filter 'installer-recovery-*.json')
        $records.Count | Should -Be 1
        $record=Get-Content -Raw $records[0].FullName | ConvertFrom-Json -AsHashtable
        $record.settings['defaults.organizationIds'].before.value | Should -Be @('org_saved')
        $record.settings.Contains('services') | Should -BeFalse
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
    }

    It 'keeps settings recovery material and restores payload even when settings recovery itself fails' {
        Mock Install-TtAutomation { throw 'late failure before recovery' }
        Mock Undo-TtInstallerSettings -ModuleName TunnelTend { throw 'settings storage unavailable' }
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*late failure before recovery*Recovery incomplete*settings storage unavailable*'
        @(Get-ChildItem $script:State -Filter 'installer-recovery-*.json').Count | Should -Be 1
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
    }

    It 'can retry a failed first installation using the selected custom managed-client location' {
        $state=Join-Path (Split-Path $script:State) 'failed-first-state'
        Mock Install-TtAutomation { throw 'first installation failure' }
        { & $script:Installer -InstallRoot $script:Install -StateRoot $state -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*first installation failure*'
        Mock Install-TtAutomation {}
        & $script:Installer -InstallRoot $script:Install -StateRoot $state -NonInteractive -SkipClientInstall -SkipPath
        $settings=Get-TtConfiguration -StateRoot $state
        $settings.officialClient.executablePath | Should -Be (Join-Path $script:Install 'official-client/tunnel-client.exe')
        $settings.officialClient.installDirectory | Should -Be (Join-Path $script:Install 'official-client')
        $settings.automation.autostart | Should -BeTrue
    }

    It 'leaves the real installed CLI usable after reinstall and after a later failed settings change' {
        $powerShell=(Get-Process -Id $PID).Path
        $state=Join-Path (Split-Path $script:State) 'cli-state'
        & $script:Installer -InstallRoot $script:Install -StateRoot $state -PowerShellPath $powerShell -DisableAutostart -DisableAutoUpdate -DisableWatchdog -NonInteractive -SkipClientInstall -SkipPath
        & $script:Installer -InstallRoot $script:Install -NonInteractive -SkipClientInstall -SkipPath
        $receiptBefore=Get-Content -Raw (Join-Path $script:Install 'install.json')
        Mock Install-TtAutomation { throw 'installed package recovery specimen' }
        { & $script:Installer -InstallRoot $script:Install -DisableAutostart:$false -RuntimeKeyRef 'env:REQUESTED_KEY' -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*installed package recovery specimen*'
        (Get-Content -Raw (Join-Path $script:Install 'install.json')) | Should -Be $receiptBefore
        $start=[Diagnostics.ProcessStartInfo]::new($powerShell)
        $start.UseShellExecute=$false
        $start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true
        $start.RedirectStandardError=$true
        foreach ($argument in @('-NoProfile','-NonInteractive','-File',(Join-Path $script:Install 'tunneltend.ps1'),'config','show','--json','--state-root',$state)) { $start.ArgumentList.Add($argument) }
        $process=[Diagnostics.Process]::Start($start)
        try {
            $stdout=$process.StandardOutput.ReadToEndAsync()
            $stderr=$process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Installed CLI qualification timed out.' }
            $process.ExitCode | Should -Be 0 -Because $stderr.GetAwaiter().GetResult()
            $output=$stdout.GetAwaiter().GetResult() | ConvertFrom-Json -AsHashtable
            $output.status | Should -Be 'ok'
            $output.data.automation.autostart | Should -BeFalse
            $output.data.defaults.runtimeKeyRef | Should -Be 'env:CONTROL_PLANE_API_KEY'
        }
        finally { $process.Dispose() }
    }
}
