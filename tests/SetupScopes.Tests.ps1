BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'Setup optional tunnel scope defaults' {
    BeforeEach {
        Mock Import-TtOfficialRuntime -ModuleName TunnelTend { throw 'Omitted imports must not contact the official client' }
        Mock Invoke-TtDoctor -ModuleName TunnelTend { @{status='ok'} }
    }

    It 'persists empty optional scopes through public noninteractive setup and then registers a descriptor' {
        $root = Join-Path $TestDrive 'setup-state'
        Invoke-TtSetup -NonInteractive -SkipAutomationInstall -StateRoot $root | Out-Null
        $defaults = (Get-Content -Raw -LiteralPath (Join-Path $root 'registry.json') | ConvertFrom-Json -AsHashtable).settings.defaults
        @($defaults.organizationIds).Count | Should -Be 0
        @($defaults.workspaceIds).Count | Should -Be 0
        Should -Invoke Import-TtOfficialRuntime -ModuleName TunnelTend -Times 0 -Exactly
        $project = Join-Path $TestDrive 'setup-project'
        New-Item -ItemType Directory $project | Out-Null
        @{mcp=@{kind='url';url='http://127.0.0.1:1/mcp'}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'tunneltend.service.json')
        (Register-TtService -Path $project -TunnelId tunnel_fixture -NoStart -StateRoot $root).service.id | Should -Be 'setup-project'
    }

    It 'rejects blank and duplicate default scopes before persistence' {
        foreach ($scope in @(@{values=@('');name='blank'},@{values=@('org_fixture','org_fixture');name='duplicate'})) {
            $root = Join-Path $TestDrive $scope.name
            { Set-TtConfiguration -Path settings.defaults.organizationIds -Value $scope.values -StateRoot $root } | Should -Throw '*organizationIds*'
            Test-Path -LiteralPath (Join-Path $root 'registry.json') | Should -BeFalse
        }
    }

    It 'preserves selected defaults when omitted and replaces the scope selection deliberately' {
        $root = Join-Path $TestDrive 'selected-scope'
        Invoke-TtSetup -OrganizationId org_fixture -NonInteractive -SkipAutomationInstall -StateRoot $root | Out-Null
        Invoke-TtSetup -NonInteractive -SkipAutomationInstall -StateRoot $root | Out-Null
        @((Get-TtConfiguration -StateRoot $root).defaults.organizationIds) | Should -Be @('org_fixture')
        Invoke-TtSetup -WorkspaceId ws_fixture -NonInteractive -SkipAutomationInstall -StateRoot $root | Out-Null
        $defaults = (Get-TtConfiguration -StateRoot $root).defaults
        @($defaults.organizationIds).Count | Should -Be 0
        @($defaults.workspaceIds) | Should -Be @('ws_fixture')
    }

    It 'installs the real module with unset defaults and registers through those installed bytes' {
        $install = Join-Path $TestDrive 'installed-program'
        $state = Join-Path $TestDrive 'installed-state'
        $receipt = Join-Path $TestDrive 'installed-receipt.json'
        $arguments = @('-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'Fixtures/install-and-register-offline.ps1'),'-InstallerPath',(Join-Path $PSScriptRoot '../scripts/Install-TunnelTend.ps1'),'-InstallRoot',$install,'-StateRoot',$state,'-ReceiptPath',$receipt)
        & $script:Module {
            param($arguments)
            Invoke-TtProcess -FilePath (Get-Process -Id $PID).Path -ArgumentList $arguments -TimeoutSeconds 60 | Out-Null
        } $arguments
        $observed = Get-Content -Raw -LiteralPath $receipt | ConvertFrom-Json -AsHashtable
        $observed.registered | Should -Be 'fixture-project'
        $observed.modulePath | Should -Be (Join-Path $install 'src/TunnelTend/TunnelTend.psm1')
        @($observed.defaults.organizationIds).Count | Should -Be 0
        @($observed.defaults.workspaceIds).Count | Should -Be 0
        $observed.organizationCount | Should -Be 0
        $observed.workspaceCount | Should -Be 0
    }

    It 'rejects explicit blank and duplicate input through setup, typed registration and the CLI' {
        Mock Write-TtCliResult -ModuleName TunnelTend {}
        foreach ($scope in @(@{name='blank';values=@('')},@{name='duplicate';values=@('org_fixture','org_fixture')})) {
            $root = Join-Path $TestDrive $scope.name
            { Invoke-TtSetup -OrganizationId $scope.values -NonInteractive -SkipAutomationInstall -StateRoot $root } | Should -Throw '*organizationIds*'
            { Register-TtService -Id invalid -Url http://127.0.0.1:1/mcp -OrganizationId $scope.values -NoStart -StateRoot $root } | Should -Throw
            $cli = @('service','register','--url','http://127.0.0.1:1/mcp','--id','invalid','--no-start','--json','--state-root',$root)
            foreach ($value in $scope.values) { $cli += @('--organization-id',$value) }
            Invoke-TtCli $cli | Should -Not -Be 0
            @(Get-TtService -StateRoot $root).Count | Should -Be 0
        }
    }

    It 'recovers only the known earlier null default shape without writing during a read' {
        $root = Join-Path $TestDrive 'earlier-defaults'
        & $script:Module {
            param($root)
            $r = New-TtDefaultRegistry
            $r.settings.defaults.organizationIds = @($null)
            $r.settings.defaults.workspaceIds = @($null)
            # Reproduce bytes emitted by the earlier installer, bypassing the
            # now-correct public writer solely to create this legacy fixture.
            $paths = Initialize-TtStateDirectories $root
            Write-TtJsonAtomic $paths.Registry $r
        } $root
        $path = Join-Path $root 'registry.json'
        $before = (Get-FileHash -LiteralPath $path).Hash
        $defaults = (Get-TtConfiguration -StateRoot $root).defaults
        @($defaults.organizationIds).Count | Should -Be 0
        @($defaults.workspaceIds).Count | Should -Be 0
        (Get-FileHash -LiteralPath $path).Hash | Should -Be $before
        Register-TtService -Id recovered -Url http://127.0.0.1:1/mcp -TunnelId tunnel_fixture -NoStart -StateRoot $root | Out-Null
        $saved = (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable).settings.defaults
        @($saved.organizationIds).Count | Should -Be 0
        @($saved.workspaceIds).Count | Should -Be 0
    }
}
