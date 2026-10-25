BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $seed=Join-Path $TestDrive 'source'
    New-Item -ItemType Directory -Path $seed | Out-Null
    Get-ChildItem (Join-Path $PSScriptRoot '..') -Force | Where-Object Name -NotIn @('.git','artifacts','.validation','website') | Copy-Item -Destination $seed -Recurse -Force
    & (Join-Path $seed 'scripts/Build-WindowsLauncher.ps1') -OutputPath (Join-Path $seed 'bin/TunnelTend.TaskHost.exe') | Out-Null
    $script:Installer=Join-Path $seed 'scripts/Install-TunnelTend.ps1'

    function Enable-ContainedInstallerPath {
        $fixture=@{user='C:\fixture\one;;C:\fixture\two';userWrites=0;processWrites=0;failAfterUserWrite=$false}
        $read={
            param($Target)
            if ($Target -eq 'User') { return $fixture.user }
            return [Environment]::GetEnvironmentVariable('Path','Process')
        }.GetNewClosure()
        $write={
            param($Target,$Value)
            if ($Target -eq 'User') {
                $fixture.user=$Value
                $fixture.userWrites++
                if ($fixture.failAfterUserWrite -and $fixture.userWrites -eq 1) { throw 'fixture notification failed after user PATH write' }
                return
            }
            $fixture.processWrites++
            [Environment]::SetEnvironmentVariable('Path',$Value,'Process')
        }.GetNewClosure()
        Mock Get-TtInstallationPathValue -ModuleName TunnelTend -MockWith $read
        Mock Set-TtInstallationPathValue -ModuleName TunnelTend -MockWith $write
        return $fixture
    }
}

Describe 'Installer upgrade continuity' {
    BeforeEach {
        $script:ProcessPathBefore=$env:Path
        $script:RealUserPathBefore=[Environment]::GetEnvironmentVariable('Path','User')
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
        Mock Uninstall-TtAutomation {}
        Mock Get-TtAutomationStatus { @{tasks=@()} }
        Mock Invoke-TtDoctor { @{status='ok'} }
        Mock Get-TtStatus { @{} }
        Mock Update-TtClient {}
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('Path',$script:ProcessPathBefore,'Process')
        [string]::Equals([Environment]::GetEnvironmentVariable('Path','User'),$script:RealUserPathBefore,[StringComparison]::Ordinal) | Should -BeTrue -Because 'fixture PATH qualification must not change the real user PATH'
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

    It 'review regression: keeps a committed installation usable with a locked backup and WarningAction Stop' {
        $path=Enable-ContainedInstallerPath
        $held=@{stream=$null}
        $holdBackup={
            param($StateRoot)
            $previous=Get-ChildItem (Split-Path $StateRoot) -Directory -Filter 'program.previous-*' | Select-Object -First 1
            $held.stream=[IO.File]::Open((Join-Path $previous.FullName 'old.txt'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        }.GetNewClosure()
        Mock Install-TtAutomation -MockWith $holdBackup
        try {
            & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -NonInteractive -SkipClientInstall -WarningAction Stop
        }
        finally { if ($held.stream) { $held.stream.Dispose() } }
        (Get-TtConfiguration -StateRoot $script:State).automation.autostart | Should -BeTrue
        Test-Path (Join-Path $script:Install 'tunneltend.ps1') | Should -BeTrue
        ($path.user -split ';') | Should -Contain $script:Install
        ($env:Path -split ';')[0] | Should -Be $script:Install
        $path.userWrites | Should -Be 1
        Should -Invoke Uninstall-TtAutomation -Exactly 0
        @(Get-ChildItem (Split-Path $script:Install) -Filter 'program.previous-*').Count | Should -Be 1
    }

    It 'review PATH: rolls back a locked recovery record with preexisting entries <ExistingPath>' -ForEach @(@{ExistingPath=$false},@{ExistingPath=$true}) {
        $path=Enable-ContainedInstallerPath
        if ($ExistingPath) { $path.user += ";$script:Install"; $env:Path="$script:Install;$env:Path" }
        $userBefore=$path.user
        $processBefore=$env:Path
        $held=@{stream=$null}
        $lockRecord={
            param($StateRoot)
            $record=Get-ChildItem $StateRoot -Filter 'installer-recovery-*.json' | Select-Object -First 1
            $held.stream=[IO.File]::Open($record.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        }.GetNewClosure()
        Mock Install-TtAutomation -MockWith $lockRecord
        $capture=[IO.StringWriter]::new()
        $originalOut=[Console]::Out
        try {
            [Console]::SetOut($capture)
            { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -NonInteractive -SkipClientInstall } | Should -Throw '*Recovery incomplete*Recovery record*'
        }
        finally { [Console]::SetOut($originalOut); if ($held.stream) { $held.stream.Dispose() } }
        $capture.ToString() | Should -Not -Match 'TunnelTend installed at'
        $capture.Dispose()
        $path.user | Should -Be $userBefore
        [string]::Equals($env:Path,$processBefore,[StringComparison]::Ordinal) | Should -BeTrue
        $path.userWrites | Should -Be $(if ($ExistingPath) { 0 } else { 2 })
        $path.processWrites | Should -Be $(if ($ExistingPath) { 0 } else { 2 })
        (Get-TtConfiguration -StateRoot $script:State).automation.autostart | Should -BeFalse
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
        @(Get-ChildItem $script:State -Filter 'installer-recovery-*.json').Count | Should -Be 1
        (Get-Content -Raw (Join-Path $script:State 'runtime.json')) | Should -Be $script:Runtime
    }

    It 'review PATH: reverses its user entry if publication takes effect before throwing' {
        $path=Enable-ContainedInstallerPath
        $userBefore=$path.user
        $path.failAfterUserWrite=$true
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -DisableAutostart:$false -NonInteractive -SkipClientInstall } | Should -Throw '*fixture notification failed*'
        $path.user | Should -Be $userBefore
        $path.userWrites | Should -Be 2
        $path.processWrites | Should -Be 0
        [string]::Equals($env:Path,$script:ProcessPathBefore,[StringComparison]::Ordinal) | Should -BeTrue
        (Get-TtConfiguration -StateRoot $script:State).automation.autostart | Should -BeFalse
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
    }

    It 'review PATH: preserves unrelated current entries during rollback' {
        $path=Enable-ContainedInstallerPath
        $userBefore=$path.user
        $changes=@{}
        & (Get-Module TunnelTend) { param($root,$changes) Add-TtInstallationPath $root $changes } $script:Install $changes
        $path.user += ';C:\concurrent\user'
        $env:Path += ';C:\concurrent\process'
        & (Get-Module TunnelTend) { param($root,$changes) Undo-TtInstallationPath $root $changes } $script:Install $changes
        $path.user | Should -Be "$userBefore;C:\concurrent\user"
        [string]::Equals($env:Path,($script:ProcessPathBefore+';C:\concurrent\process'),[StringComparison]::Ordinal) | Should -BeTrue
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

    It 'review regression: refuses an explicit no-op choice changed before publication: <Kind>' -ForEach @(
        @{Kind='autostart-disabled';Setting='automation.autostart';Parameter='DisableAutostart';Before=$false;Explicit=$true;Concurrent=$true},
        @{Kind='autostart-enabled';Setting='automation.autostart';Parameter='DisableAutostart';Before=$true;Explicit=$false;Concurrent=$false},
        @{Kind='update-disabled';Setting='automation.autoUpdate';Parameter='DisableAutoUpdate';Before=$false;Explicit=$true;Concurrent=$true},
        @{Kind='update-enabled';Setting='automation.autoUpdate';Parameter='DisableAutoUpdate';Before=$true;Explicit=$false;Concurrent=$false},
        @{Kind='watchdog-disabled';Setting='automation.watchdog';Parameter='DisableWatchdog';Before=$false;Explicit=$true;Concurrent=$true},
        @{Kind='watchdog-enabled';Setting='automation.watchdog';Parameter='DisableWatchdog';Before=$true;Explicit=$false;Concurrent=$false},
        @{Kind='empty-organizations';Setting='defaults.organizationIds';Parameter='OrganizationId';Before=@();Explicit=@();Concurrent=@('org_concurrent')},
        @{Kind='empty-workspaces';Setting='defaults.workspaceIds';Parameter='WorkspaceId';Before=@();Explicit=@();Concurrent=@('ws_concurrent')},
        @{Kind='reference';Setting='defaults.runtimeKeyRef';Parameter='RuntimeKeyRef';Before='env:SAVED_KEY';Explicit='env:SAVED_KEY';Concurrent='env:OTHER_KEY'},
        @{Kind='client-executable';Setting='officialClient.executablePath';Parameter='TunnelClientPath'},
        @{Kind='client-directory';Setting='officialClient.installDirectory';Parameter='TunnelClientPath'}
    ) {
        $parameters=@{}
        if ($Kind -like 'client-*') {
            $parameters.TunnelClientPath=$script:Client
            $concurrentValue=Join-Path (Split-Path $script:Client) 'other'
            if ($Kind -eq 'client-executable') { $concurrentValue += '.exe'; Set-Content $concurrentValue 'other fixture' }
        }
        else {
            & (Get-Module TunnelTend) {
                param($state,$setting,$before)
                $registry=Get-TtRegistry $state
                if ($setting -like 'defaults.*Ids') { $registry.settings.defaults.organizationIds=@(); $registry.settings.defaults.workspaceIds=@() }
                $group,$key=$setting.Split('.')
                $registry.settings[$group][$key]=$before
                Save-TtRegistry $registry $state
            } $script:State $Setting $Before
            $parameters[$Parameter]=$Explicit
            $concurrentValue=$Concurrent
        }
        $plan=& (Get-Module TunnelTend) { param($state,$install,$parameters) New-TtInstallerSettingsPlan $state $install $parameters } $script:State $script:Install $parameters
        Set-TtConfiguration -Path "settings.$Setting" -Value $concurrentValue -StateRoot $script:State | Out-Null
        $beforePublish=Get-Content -Raw (Join-Path $script:State 'registry.json')
        { & (Get-Module TunnelTend) { param($plan,$state) Set-TtInstallerSettings $plan $state (Join-Path $state 'review-recovery.json') } $plan $script:State } | Should -Throw "*$Setting*changed during preparation*"
        Get-Content -Raw (Join-Path $script:State 'registry.json') | Should -Be $beforePublish
    }

    It 'review regression: refuses a changed interactively confirmed no-op choice' {
        $state=$script:State
        $answer={
            param($Prompt)
            if (($Prompt -join ' ') -like '*autostart*') { Set-TtConfiguration -Path settings.automation.autostart -Value $true -StateRoot $state | Out-Null }
            return ''
        }.GetNewClosure()
        Mock Read-Host -MockWith $answer
        { & $script:Installer -InstallRoot $script:Install -StateRoot $script:State -SkipClientInstall -SkipPath } | Should -Throw '*automation.autostart*changed during preparation*'
        (Get-TtConfiguration -StateRoot $script:State).automation.autostart | Should -BeTrue
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
        Should -Invoke Install-TtAutomation -Exactly 0
    }

    It 'review omission: retains newer omitted intent between planning and publication' {
        $plan=& (Get-Module TunnelTend) { param($state,$install) New-TtInstallerSettingsPlan $state $install @{} } $script:State $script:Install
        Set-TtConfiguration -Path settings.automation.autostart -Value $true -StateRoot $script:State | Out-Null
        $beforePublish=Get-Content -Raw (Join-Path $script:State 'registry.json')
        $settings=& (Get-Module TunnelTend) { param($plan,$state) Set-TtInstallerSettings $plan $state (Join-Path $state 'review-recovery.json') } $plan $script:State
        $settings.automation.autostart | Should -BeTrue
        Get-Content -Raw (Join-Path $script:State 'registry.json') | Should -Be $beforePublish
    }

    It 'review regression: refuses state in the generated bin container before moving it' {
        # Source installs build bin after staging, so exercise that supported
        # route without the immutable seed's already-compiled package launcher.
        $sourceOnly=Join-Path (Split-Path $script:Install) 'source-without-launcher'
        New-Item -ItemType Directory -Path $sourceOnly | Out-Null
        Get-ChildItem (Split-Path (Split-Path $script:Installer)) -Force | Where-Object Name -NE 'bin' | Copy-Item -Destination $sourceOnly -Recurse -Force
        $sourceInstaller=Join-Path $sourceOnly 'scripts/Install-TunnelTend.ps1'
        $nested=Join-Path $script:Install 'bin/state'
        New-Item -ItemType Directory -Path (Split-Path $nested) -Force | Out-Null
        Move-Item $script:State $nested
        $registryBefore=Get-Content -Raw (Join-Path $nested 'registry.json')
        { & $sourceInstaller -InstallRoot $script:Install -StateRoot $nested -NonInteractive -SkipClientInstall -SkipPath } | Should -Throw '*own directory*'
        Get-Content -Raw (Join-Path $nested 'registry.json') | Should -Be $registryBefore
        Get-Content (Join-Path $script:Install 'old.txt') | Should -Be 'previous payload'
        @(Get-ChildItem (Split-Path $script:Install) -Filter 'program.state-*').Count | Should -Be 0
    }

    It 'review managed client: preserves nested state during install and binary-only replacement' {
        $directory=Join-Path $script:Install 'official-client'
        $nested=Join-Path $directory 'state'
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Move-Item $script:State $nested
        $client=Join-Path $directory 'tunnel-client.exe'
        Set-Content $client 'old managed fixture'
        Set-TtConfiguration -Path settings.officialClient.executablePath -Value $client -StateRoot $nested | Out-Null
        Set-TtConfiguration -Path settings.officialClient.installDirectory -Value $directory -StateRoot $nested | Out-Null
        $beforeRegistry=Get-Content -Raw (Join-Path $nested 'registry.json')
        & $script:Installer -InstallRoot $script:Install -StateRoot $nested -NonInteractive -SkipClientInstall -SkipPath
        $payload=Join-Path (Split-Path $script:Install) 'replacement.exe'
        Set-Content $payload 'new managed fixture'
        Mock Test-TtOfficialClientCapabilities -ModuleName TunnelTend { @{compatible=$true} }
        Mock Get-TtServiceObservation -ModuleName TunnelTend { @{tunnel=@{running=$false};host=@{configured=$false;running=$false}} }
        & (Get-Module TunnelTend) { param($state,$payload) Invoke-TtClientFileTransaction (Get-TtRegistry $state) (Get-TtRuntimeStore $state) $state $payload } $nested $payload | Out-Null
        Get-Content $client | Should -Be 'new managed fixture'
        Get-Content -Raw (Join-Path $nested 'registry.json') | Should -Be $beforeRegistry
        Get-Content -Raw (Join-Path $nested 'runtime.json') | Should -Be $script:Runtime
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
