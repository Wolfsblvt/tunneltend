[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$manifest=Join-Path $RepositoryRoot 'src/TunnelTend/TunnelTend.psd1'
Import-Module $manifest -Force
$module=Get-Module TunnelTend
$script:passed=0
$script:failed=0

function Test-Case([string]$Name,[scriptblock]$Body) {
    try { & $Body; $script:passed++; [Console]::WriteLine("PASS $Name") }
    catch { $script:failed++; [Console]::Error.WriteLine("FAIL $Name :: $($_.Exception.Message)") }
}
function Assert-True($Condition,[string]$Message='assertion failed') { if (-not $Condition) { throw $Message } }
function Assert-Equal($Expected,$Actual,[string]$Message='values differ') { if (($Expected | ConvertTo-Json -Compress -Depth 50) -ne ($Actual | ConvertTo-Json -Compress -Depth 50)) { throw "$Message expected='$Expected' actual='$Actual'" } }

Test-Case 'module imports and exports CLI' { Assert-True ($null -ne (Get-Command Invoke-TtCli -ErrorAction SilentlyContinue)) }
Test-Case 'service ids normalize deterministically' {
    $actual=& $module { ConvertTo-TtServiceId ' My_Service  Name ' }
    Assert-Equal 'my-service-name' $actual
}
Test-Case 'empty service id is refused' {
    $threw=$false; try { & $module { ConvertTo-TtServiceId '---' } | Out-Null } catch { $threw=$true }
    Assert-True $threw
}
Test-Case 'secret references are strict' {
    Assert-True (& $module { Test-TtSecretReference 'env:CONTROL_PLANE_API_KEY' })
    Assert-True (& $module { Test-TtSecretReference 'file:C:\secrets\runtime.key' })
    Assert-True (-not (& $module { Test-TtSecretReference 'literal-secret' }))
}
Test-Case 'inline secret patterns are rejected' {
    $threw=$false; try { & $module { Assert-TtNoInlineSecrets 'Authorization: Bearer abcdefghijklmnop' } } catch { $threw=$true }
    Assert-True $threw
}
Test-Case 'Windows quoting handles spaces and quotes' {
    $quoted=& $module { ConvertTo-TtWindowsCommandArgument 'C:\Program Files\A "quoted" thing' }
    Assert-True ($quoted.StartsWith('"') -and $quoted.EndsWith('"'))
}
Test-Case 'default registry enables autonomous behavior' {
    $registry=& $module { New-TtDefaultRegistry }
    Assert-True $registry.settings.automation.autostart
    Assert-True $registry.settings.automation.watchdog
    Assert-True $registry.settings.automation.autoUpdate
    Assert-Equal 2 $registry.settings.automation.watchdogIntervalMinutes
}
Test-Case 'service definitions omit empty tunnel scope values' {
    $service=& $module {
        $registry=New-TtDefaultRegistry
        New-TtServiceDefinition -Id demo -Mcp @{kind='url';url='http://127.0.0.1:1/mcp'} -TunnelId tunnel_demo -OrganizationId $null -WorkspaceId $null -SourceWatch $false -Defaults $registry.settings.defaults
    }
    Assert-Equal @() @($service.tunnel.organizationIds)
    Assert-Equal @() @($service.tunnel.workspaceIds)
}
Test-Case 'registry round trip is atomic and schema-versioned' {
    $state=Join-Path ([IO.Path]::GetTempPath()) ('tt-test-'+[Guid]::NewGuid().ToString('N'))
    try {
        & $module { param($root) $r=Get-TtRegistry $root; Save-TtRegistry $r $root } $state
        $path=Join-Path $state 'registry.json'
        Assert-True (Test-Path $path)
        $data=Get-Content $path -Raw | ConvertFrom-Json
        Assert-Equal 1 $data.schemaVersion
    } finally { Remove-Item $state -Recurse -Force -ErrorAction SilentlyContinue }
}
Test-Case 'ambiguous discovery refuses to guess' {
    $dir=Join-Path ([IO.Path]::GetTempPath()) ('tt-discovery-'+[Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory $dir | Out-Null
        '{"scripts":{"mcp":"node one.js","start:mcp":"node two.js"}}' | Set-Content (Join-Path $dir 'package.json')
        $threw=$false; try { & $module { param($p) Resolve-TtProjectDiscovery $p } $dir | Out-Null } catch { $threw=$true }
        Assert-True $threw
    } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
Test-Case 'source fingerprint excludes build output' {
    $dir=Join-Path ([IO.Path]::GetTempPath()) ('tt-source-'+[Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory (Join-Path $dir 'bin') -Force | Out-Null
        'one' | Set-Content (Join-Path $dir 'server.ps1')
        'x' | Set-Content (Join-Path $dir 'bin/generated.dll')
        $source=@{path=$dir;watch=$true;include=@('**/*');exclude=@('bin/**');debounceSeconds=1}
        $a=& $module { param($s) Get-TtSourceFingerprint $s } $source
        'y' | Set-Content (Join-Path $dir 'bin/generated.dll')
        $b=& $module { param($s) Get-TtSourceFingerprint $s } $source
        Assert-Equal $a $b
    } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
Test-Case 'recovery budget is persisted before action and bounded' {
    & $module {
        $runtime=New-TtDefaultRuntimeStore
        $record=Get-TtRuntimeServiceRecord $runtime 'demo' -Create
        $policy=@{enabled=$true;maxAttempts=2;windowMinutes=20;initialBackoffSeconds=1;maximumBackoffSeconds=10;unhealthyThreshold=1}
        Register-TtRecoveryAttempt $record $policy 'test' | Out-Null
        Register-TtRecoveryAttempt $record $policy 'test' | Out-Null
        $decision=Test-TtRecoveryAllowed $record $policy
        if ($decision.allowed -or $decision.reason -ne 'budget-exhausted') { throw 'budget did not exhaust' }
    }
}
Test-Case 'status health and doctor remain read-only' {
    $state=Join-Path ([IO.Path]::GetTempPath()) ('tt-readonly-'+[Guid]::NewGuid().ToString('N'))
    try {
        & $module {
            param($root)
            $r=Get-TtRegistry $root
            $service=New-TtServiceDefinition -Id demo -Mcp @{kind='url';url='http://127.0.0.1:65534/mcp'} -TunnelId 'tunnel_demo' -SourceWatch $false -Defaults $r.settings.defaults
            $r.services.demo=$service
            Save-TtRegistry $r $root
            $rt=Get-TtRuntimeStore $root; Get-TtRuntimeServiceRecord $rt demo -Create | Out-Null; Save-TtRuntimeStore $rt $root
            Set-Item Function:Get-TtOfficialRuntimeStatus -Value { param($Alias) [ordered]@{known=$true;running=$false;healthy=$false;ready=$false;state='stopped';alias=$Alias;tunnel_id='tunnel_demo';process=$null;raw=@{};error=$null} }
            Set-Item Function:Get-TtOfficialClientVersion -Value { [ordered]@{installed=$true;version='0.0.11';path='fake'} }
            Set-Item Function:Test-TtOfficialClientCapabilities -Value { [ordered]@{compatible=$true;checks=@()} }
            Set-Item Function:Get-TtAutomationStatusInternal -Value { [ordered]@{supported=$false;tasks=@();desired=@()} }
            Get-TtStatus -StateRoot $root | Out-Null
            Get-TtHealth -StateRoot $root | Out-Null
            Invoke-TtDoctor -StateRoot $root | Out-Null
        } $state
        $registryPath=Join-Path $state 'registry.json'; $runtimePath=Join-Path $state 'runtime.json'
        $beforeR=(Get-FileHash $registryPath).Hash; $beforeT=(Get-FileHash $runtimePath).Hash
        & $module {
            param($root)
            Set-Item Function:Get-TtOfficialRuntimeStatus -Value { param($Alias) [ordered]@{known=$true;running=$false;healthy=$false;ready=$false;state='stopped';alias=$Alias;tunnel_id='tunnel_demo';process=$null;raw=@{};error=$null} }
            Set-Item Function:Get-TtOfficialClientVersion -Value { [ordered]@{installed=$true;version='0.0.11';path='fake'} }
            Set-Item Function:Test-TtOfficialClientCapabilities -Value { [ordered]@{compatible=$true;checks=@()} }
            Set-Item Function:Get-TtAutomationStatusInternal -Value { [ordered]@{supported=$false;tasks=@();desired=@()} }
            Get-TtStatus -StateRoot $root | Out-Null; Get-TtHealth -StateRoot $root | Out-Null; Invoke-TtDoctor -StateRoot $root | Out-Null
        } $state
        Assert-Equal $beforeR (Get-FileHash $registryPath).Hash
        Assert-Equal $beforeT (Get-FileHash $runtimePath).Hash
    } finally { Remove-Item $state -Recurse -Force -ErrorAction SilentlyContinue }
}
Test-Case 'read-only commands do not create an absent state root' {
    $state=Join-Path ([IO.Path]::GetTempPath()) ('tt-absent-readonly-'+[Guid]::NewGuid().ToString('N'))
    try {
        & $module {
            param($root)
            Set-Item Function:Get-TtOfficialClientVersion -Value { [ordered]@{installed=$false;version=$null;path='missing';error='missing'} }
            Set-Item Function:Test-TtOfficialClientCapabilities -Value { [ordered]@{compatible=$false;checks=@()} }
            Set-Item Function:Get-TtAutomationStatusInternal -Value { [ordered]@{supported=$false;tasks=@();desired=@()} }
            Get-TtStatus -StateRoot $root | Out-Null
            Get-TtHealth -StateRoot $root | Out-Null
            Invoke-TtDoctor -StateRoot $root | Out-Null
        } $state
        Assert-True (-not (Test-Path -LiteralPath $state)) 'read-only commands created the absent state root'
    } finally { Remove-Item $state -Recurse -Force -ErrorAction SilentlyContinue }
}
Test-Case 'CLI help names operational grammar' {
    $help=Get-TtCliHelp
    foreach ($word in @('status','health','doctor','repair','reconcile')) { Assert-True ($help -match $word) }
}
Test-Case 'CLI boolean options never consume following positionals' {
    $parsed=& $module { Parse-TtCliArguments @('--json','status','demo','--force') }
    Assert-Equal @('status','demo') @($parsed.positionals)
    Assert-True $parsed.options.json
    Assert-True $parsed.options.force
}

[Console]::WriteLine("Zero-dependency tests: $script:passed passed, $script:failed failed")
if ($script:failed -gt 0) { exit 1 }
