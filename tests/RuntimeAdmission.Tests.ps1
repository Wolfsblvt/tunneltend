BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'Runtime admission and command context' {
    BeforeEach {
        Mock Get-TtOfficialRuntimeList -ModuleName TunnelTend { @{aliases=@()} }
    }
    It 'refuses two registrations controlling the same official alias, including force' {
        $root = Join-Path $TestDrive 'duplicates'
        Register-TtService -Id alpha -Alias shared -Url http://127.0.0.1:1/mcp -TunnelId tunnel_a -NoStart -StateRoot $root | Out-Null
        { Register-TtService -Id beta -Alias shared -Url http://127.0.0.1:2/mcp -TunnelId tunnel_b -NoStart -Force -StateRoot $root } | Should -Throw '*alias*'
        @(Get-TtService -StateRoot $root).Count | Should -Be 1
    }

    It 'refuses unverified automatic update policy before persisting it' {
        $root = Join-Path $TestDrive 'policy'
        { Set-TtConfiguration -Path settings.officialClient.allowUnverifiedAsset -Value $true -StateRoot $root } | Should -Throw '*verification*'
        $registry = & $script:Module { param($r) Get-TtRegistry $r } $root
        $registry.settings.officialClient.allowUnverifiedAsset | Should -BeFalse
    }

    It 'passes the registered command directory and resolved executable to the official process' {
        $directory = Join-Path $TestDrive 'project'
        New-Item -ItemType Directory $directory | Out-Null
        Set-Content -LiteralPath (Join-Path $directory 'fixture.exe') -Value 'synthetic executable; process boundary is mocked'
        Mock Invoke-TtProcess -ModuleName TunnelTend { @{exit_code=0;stdout='{}';stderr=''} }
        $captured = & $script:Module {
            param($directory)
            $registry = New-TtDefaultRegistry
            $registry.settings.officialClient.executablePath = (Get-Process -Id $PID).Path
            $service = New-TtServiceDefinition -Id demo -TunnelId tunnel_demo -Defaults $registry.settings.defaults -Mcp @{kind='command';command=@{file='./fixture.exe';arguments=@('server.js');workingDirectory=$directory;environment=@{}}}
            Start-TtOfficialRuntime $service $registry | Out-Null
            Get-TtConnectArguments $service
        } $directory
        Should -Invoke Invoke-TtProcess -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $WorkingDirectory -eq $directory }
        ($captured -join ' ') | Should -Match ([regex]::Escape((Join-Path $directory 'fixture.exe')))
    }

    It 'refuses start and stop of an unimported alias before touching a host or official runtime' {
        Mock Get-TtOfficialRuntimeList -ModuleName TunnelTend { @{aliases=@(@{alias='demo'})} }
        Mock Start-TtHostProcess -ModuleName TunnelTend {}
        Mock Stop-TtHostProcess -ModuleName TunnelTend {}
        Mock Start-TtOfficialRuntime -ModuleName TunnelTend {}
        Mock Stop-TtOfficialRuntime -ModuleName TunnelTend {}
        & $script:Module {
            param($root)
            $r = New-TtDefaultRegistry
            $r.services.demo = New-TtServiceDefinition -Id demo -TunnelId tunnel_demo -Defaults $r.settings.defaults -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'}
            $s = New-TtDefaultRuntimeStore
            { Start-TtManagedService $r.services.demo $r $s $root } | Should -Throw '*service import demo*'
            { Stop-TtManagedService $r.services.demo $r $s $root } | Should -Throw '*service import demo*'
        } (Join-Path $TestDrive 'foreign')
        Should -Invoke Start-TtHostProcess -ModuleName TunnelTend -Times 0 -Exactly
        Should -Invoke Stop-TtHostProcess -ModuleName TunnelTend -Times 0 -Exactly
        Should -Invoke Start-TtOfficialRuntime -ModuleName TunnelTend -Times 0 -Exactly
        Should -Invoke Stop-TtOfficialRuntime -ModuleName TunnelTend -Times 0 -Exactly
    }

    It 'retains an alias reservation across failed connect and runtime reload for ordinary recovery' {
        Mock Start-TtOfficialRuntime -ModuleName TunnelTend { throw 'synthetic connect failure after alias creation' }
        & $script:Module {
            param($root)
            $r = New-TtDefaultRegistry
            $r.services.demo = New-TtServiceDefinition -Id demo -TunnelId tunnel_demo -Defaults $r.settings.defaults -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'}
            $s = New-TtDefaultRuntimeStore
            { Start-TtManagedService $r.services.demo $r $s $root } | Should -Throw '*synthetic connect*'
            $loaded = Get-TtRuntimeStore $root
            $loaded.services.demo.officialAlias | Should -Be 'demo'
            Confirm-TtOfficialAliasOwnership $r.services.demo $r $loaded $root -Reserve
        } (Join-Path $TestDrive 'acquired')
        Should -Invoke Get-TtOfficialRuntimeList -ModuleName TunnelTend -Times 1 -Exactly
    }

    It 'records deliberate import and prevents another service from taking its alias' {
        Mock Get-TtOfficialRuntimeList -ModuleName TunnelTend { @{aliases=@(@{alias='demo'})} }
        Mock Get-TtOfficialRuntimeStatus -ModuleName TunnelTend { @{known=$true;running=$true;tunnel_id='tunnel_demo';process=@{target_kind='server_url';target_value='http://127.0.0.1:1/mcp'};raw=@{}} }
        $root = Join-Path $TestDrive 'import'
        (Import-TtOfficialRuntime -Alias demo -StateRoot $root).imported | Should -BeTrue
        (& $script:Module { param($root) (Get-TtRuntimeStore $root).services.demo.officialAlias } $root) | Should -Be 'demo'
        { Register-TtService -Id another -Alias demo -Url http://127.0.0.1:2/mcp -NoStart -Force -StateRoot $root } | Should -Throw '*alias*'
    }

    It 'adopts a pre-existing alias into its existing differently named registration when import is explicit' {
        Mock Get-TtOfficialRuntimeList -ModuleName TunnelTend { @{aliases=@(@{alias='upstream'})} }
        Mock Get-TtOfficialRuntimeStatus -ModuleName TunnelTend { @{known=$true;running=$true;tunnel_id='tunnel_demo';process=@{target_kind='server_url';target_value='http://127.0.0.1:1/mcp'};raw=@{}} }
        $root = Join-Path $TestDrive 'adopt-existing'
        Register-TtService -Id local -Alias upstream -Url http://127.0.0.1:2/mcp -NoStart -StateRoot $root | Out-Null
        (Import-TtOfficialRuntime -Alias upstream -Force -StateRoot $root).imported | Should -BeTrue
        @(Get-TtService -StateRoot $root).Count | Should -Be 1
        (Get-TtService -Id local -StateRoot $root).mcp.url | Should -Be 'http://127.0.0.1:1/mcp'
        (& $script:Module { param($root) (Get-TtRuntimeStore $root).services.local.officialAlias } $root) | Should -Be 'upstream'
    }

    It 'keeps no-start registration offline and refuses a discovered collision only when starting' {
        Mock Get-TtOfficialRuntimeList -ModuleName TunnelTend { throw 'official client unavailable' }
        $root = Join-Path $TestDrive 'offline'
        (Register-TtService -Id offline -Url http://127.0.0.1:1/mcp -TunnelId tunnel_demo -NoStart -StateRoot $root).service.id | Should -Be 'offline'
        Should -Invoke Get-TtOfficialRuntimeList -ModuleName TunnelTend -Times 0 -Exactly
        { Start-TtService -Id offline -StateRoot $root } | Should -Throw '*official client unavailable*'
        (Get-TtService -Id offline -StateRoot $root).id | Should -Be 'offline'
    }

    It 'requires published verification in the actual unattended updater invocation and rejects tampered policy' {
        Mock Invoke-TtProcess -ModuleName TunnelTend { @{exit_code=0;stdout='';stderr=''} }
        & $script:Module {
            param($root)
            $r = New-TtDefaultRegistry
            Invoke-TtBundledUpdater $r $root -Force | Out-Null
            $r.settings.officialClient.allowUnverifiedAsset = [bool]1
            { Invoke-TtBundledUpdater $r $root -Force } | Should -Throw '*verification*'
        } (Join-Path $TestDrive 'updater')
        Should -Invoke Invoke-TtProcess -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $ArgumentList -contains '-RequirePublishedChecksum' -and $ArgumentList -notcontains '-AllowUnverifiedAsset' }
    }

    It 'keeps absent and explicit empty descriptor scopes as arrays without starting a host' {
        Mock Start-TtManagedService -ModuleName TunnelTend { throw 'NoStart must not start a host' }
        foreach ($explicitEmpty in @($false,$true)) {
            $project = Join-Path $TestDrive "descriptor-$explicitEmpty"
            New-Item -ItemType Directory $project | Out-Null
            $descriptor = @{mcp=@{kind='url';url='http://127.0.0.1:1/mcp'};host=@{enabled=$true;file='pwsh';arguments=@('-NoProfile','-NonInteractive');workingDirectory=$project;environment=@{}}}
            if ($explicitEmpty) { $descriptor.tunnel = @{organizationIds=@();workspaceIds=@()} }
            $descriptor | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $project 'tunneltend.service.json')
            $root = Join-Path $TestDrive "descriptor-state-$explicitEmpty"
            Register-TtService -Path $project -NoStart -StateRoot $root | Out-Null
            $service = @(Get-TtService -StateRoot $root)[0]
            ($service.tunnel.organizationIds -is [array]) | Should -BeTrue
            ($service.tunnel.workspaceIds -is [array]) | Should -BeTrue
            @($service.tunnel.organizationIds).Count | Should -Be 0
            @($service.tunnel.workspaceIds).Count | Should -Be 0
        }
        Should -Invoke Start-TtManagedService -ModuleName TunnelTend -Times 0 -Exactly
    }

    It 'retains a singleton descriptor scope and still refuses real blank and duplicate scope entries' {
        foreach ($case in @(@{name='valid';scope=@('org_fixture');valid=$true},@{name='blank';scope=@('');valid=$false},@{name='duplicate';scope=@('org_fixture','org_fixture');valid=$false})) {
            $project = Join-Path $TestDrive $case.name
            New-Item -ItemType Directory $project | Out-Null
            @{mcp=@{kind='url';url='http://127.0.0.1:1/mcp'};tunnel=@{organizationIds=$case.scope}} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $project 'tunneltend.service.json')
            $root = Join-Path $TestDrive ($case.name + '-state')
            if ($case.valid) {
                Register-TtService -Path $project -NoStart -StateRoot $root | Out-Null
                $loaded = @(Get-TtService -StateRoot $root)[0]
                @($loaded.tunnel.organizationIds) | Should -Be @('org_fixture')
            }
            else { { Register-TtService -Path $project -NoStart -StateRoot $root } | Should -Throw '*organizationIds*' }
        }
    }
}
