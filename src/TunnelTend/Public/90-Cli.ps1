Set-StrictMode -Version Latest

function Get-TtCliHelp {
    [CmdletBinding()]
    param()
@'
tunneltend manages registered MCP services and their official OpenAI tunnels.

Usage:
  tunneltend status [SERVICE...] [--json]
  tunneltend health [SERVICE...] [--json]
  tunneltend doctor [SERVICE...] [--json]
  tunneltend repair [SERVICE...] [--apply] [--force] [--json]
  tunneltend reconcile [SERVICE...] [--plan] [--context manual|startup|watchdog|maintenance]

  tunneltend service register PATH [--id ID] [--organization-id ID] [--workspace-id ID]
  tunneltend service register --command FILE [--arg VALUE...] [--working-directory PATH]
  tunneltend service register --url URL [--health-url URL]
  tunneltend service list | show ID | remove ID
  tunneltend service start ID | stop ID [--session-only] | restart ID
  tunneltend service enable ID | disable ID
  tunneltend service autostart ID on|off
  tunneltend service watchdog ID on|off
  tunneltend service import [ALIAS...] [--force]

  tunneltend client status | update [--check-only] [--force] | rollback [--backup PATH]
  tunneltend automation install | uninstall | status | startup | watchdog | maintenance
  tunneltend config show | set PATH VALUE
  tunneltend setup [--autostart on|off] [--auto-update on|off] [--watchdog on|off]
  tunneltend version

Defaults:
  Registered services autostart at Windows logon, are watched every two minutes,
  and are restored after verified official-client updates. Use explicit switches
  to turn automation off; tunneltend does not make users assemble JSON by hand.

Operational grammar:
  status, health, doctor, repair (without --apply), and reconcile --plan are read-only.
  repair --apply and reconcile mutate state. --force never bypasses identity,
  archive, checksum, secret-reference, or scope validation.

Global options:
  --state-root PATH   Use a non-default state directory.
  --json              Emit a stable machine-readable envelope.
  --help              Show this help.
'@
}

function Write-TtCliResult {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Envelope, [switch]$Json)
    if ($Json) {
        [Console]::Out.WriteLine(($Envelope | ConvertTo-Json -Depth 100))
        return
    }
    if ($Envelope.message) { [Console]::Out.WriteLine([string]$Envelope.message) }
    switch ($Envelope.command) {
        'status' {
            foreach ($service in @($Envelope.data.services)) {
                $mark = if ($service.healthy) { 'OK' } elseif ($service.observedState -eq 'stopped') { '--' } else { '!!' }
                [Console]::Out.WriteLine("[{0}] {1,-24} desired={2,-7} observed={3,-9} autostart={4} watchdog={5}" -f $mark,$service.id,$service.desiredState,$service.observedState,$service.autostart,$service.watchdog)
            }
        }
        'health' {
            foreach ($service in @($Envelope.data.services)) { [Console]::Out.WriteLine("{0,-24} healthy={1} ready={2} state={3}" -f $service.serviceId,$service.healthy,$service.ready,$service.state) }
        }
        'doctor' {
            if (@($Envelope.diagnostics).Count -eq 0) { [Console]::Out.WriteLine('No problems detected.') }
            foreach ($diagnostic in @($Envelope.diagnostics)) { [Console]::Out.WriteLine("[{0}] {1}: {2}" -f ([string]$diagnostic.severity).ToUpperInvariant(),$diagnostic.code,$diagnostic.message) }
        }
        default {
            if ($null -ne $Envelope.data) { [Console]::Out.WriteLine(($Envelope.data | ConvertTo-Json -Depth 30)) }
        }
    }
}

function Get-TtCliBoolOption {
    param([System.Collections.IDictionary]$Options,[string]$Name,[bool]$Default=$false)
    if (-not $Options.Contains($Name)) { return $Default }
    return ConvertTo-TtBool $Options[$Name] $Default
}

function Get-TtOperationOutcome {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Data)
    $reconcile = Get-TtMapValue $Data 'reconcile' $Data
    $changed = [bool](Get-TtMapValue $reconcile 'changed' $false)
    $session = Get-TtMapValue $Data 'session' $null
    if ($session -and (Get-TtMapValue $session 'id' $null)) { $changed = $true }
    $results = @(Get-TtMapValue $reconcile 'results' @()) + @(Get-TtMapValue $Data 'serviceUpdates' @())
    foreach ($key in @('update','clientUpdate')) {
        $update = Get-TtMapValue $Data $key $null
        if ($null -ne $update) { $results += $update }
    }
    $failed = $false
    $diagnostics = @()
    foreach ($result in $results) {
        if ($null -eq $result) { continue }
        $serviceId = Get-TtMapValue $result 'serviceId' $null
        if (Get-TtMapValue $result 'skipped' $false) {
            $reason = [string](Get-TtMapValue $result 'reason' 'policy')
            $diagnostics += [ordered]@{ severity='info'; code='operation.skipped'; serviceId=$serviceId; message="Recovery deferred by current policy: $reason." }
            continue
        }
        if ((Get-TtMapValue $result 'changed' $false) -or (Get-TtMapValue $result 'updated' $false)) { $changed = $true }
        $errorMessage = [string](Get-TtMapValue $result 'error' '')
        $resultFailed = $errorMessage -or ($result.Contains('ok') -and -not [bool]$result.ok) -or ($result.Contains('updated') -and -not [bool]$result.updated)
        if ($resultFailed) {
            $failed = $true
            if (-not $errorMessage) { $errorMessage = 'The requested operation did not succeed.' }
            $diagnostics += [ordered]@{ severity='error'; code='operation.failed'; serviceId=$serviceId; message=(Protect-TtLogText $errorMessage) }
        }
    }
    $status = if ($failed) { 'degraded' } elseif ($changed) { 'changed' } else { 'noop' }
    return [ordered]@{ status=$status; diagnostics=$diagnostics }
}

function Invoke-TtCli {
    [CmdletBinding()]
    param([string[]]$Arguments)
    $parsed = Parse-TtCliArguments $Arguments
    $positionals = @($parsed.positionals)
    $options = $parsed.options
    $json = Get-TtCliBoolOption $options 'json'
    $stateRoot = [string](Get-TtCliOption $options 'state-root' $null)
    if ($options.Contains('help') -or $positionals.Count -eq 0 -or $positionals[0] -in @('help','-h')) {
        [Console]::Out.WriteLine((Get-TtCliHelp)); return 0
    }
    $commandName = [string]$positionals[0]
    try {
        $data = $null; $status = 'ok'; $message = $null; $diagnostics = @(); $actions = @()
        $summarizeOperation = $false
        switch ($commandName) {
            'version' { $data=[ordered]@{ version=$script:TtModuleVersion; schemaVersion=$script:TtSchemaVersion }; $message="tunneltend $script:TtModuleVersion" }
            'setup' {
                $autostart = if ($options.Contains('autostart')) { [Nullable[bool]](ConvertTo-TtBool $options.autostart) } else { $null }
                $autoUpdate = if ($options.Contains('auto-update')) { [Nullable[bool]](ConvertTo-TtBool $options.'auto-update') } else { $null }
                $watchdog = if ($options.Contains('watchdog')) { [Nullable[bool]](ConvertTo-TtBool $options.watchdog) } else { $null }
                $data = Invoke-TtSetup -Autostart $autostart -AutoUpdate $autoUpdate -Watchdog $watchdog -OrganizationId (ConvertTo-TtStringArray (Get-TtCliOption $options 'organization-id' $null)) -WorkspaceId (ConvertTo-TtStringArray (Get-TtCliOption $options 'workspace-id' $null)) -RuntimeKeyRef ([string](Get-TtCliOption $options 'runtime-key-ref' $null)) -ImportAll:(Get-TtCliBoolOption $options 'import-all') -ImportAlias (ConvertTo-TtStringArray (Get-TtCliOption $options 'import-alias' $null)) -NonInteractive:(Get-TtCliBoolOption $options 'non-interactive') -SkipAutomationInstall:(Get-TtCliBoolOption $options 'skip-automation-install') -StateRoot $stateRoot
                $status='changed'
            }
            'status' {
                $data=Get-TtStatus -ServiceId @($positionals | Select-Object -Skip 1) -StateRoot $stateRoot
                if (@($data.services | Where-Object { $_.desiredState -eq 'running' -and -not $_.healthy }).Count -gt 0) { $status='degraded' }
            }
            'health' {
                $data=Get-TtHealth -ServiceId @($positionals | Select-Object -Skip 1) -StateRoot $stateRoot
                if (-not $data.healthy) { $status='degraded' }
            }
            'doctor' {
                $data=Invoke-TtDoctor -ServiceId @($positionals | Select-Object -Skip 1) -StateRoot $stateRoot
                $status=$data.status; $diagnostics=@($data.diagnostics)
            }
            'repair' {
                $apply=Get-TtCliBoolOption $options 'apply'; $force=Get-TtCliBoolOption $options 'force'
                $data=Invoke-TtRepair -ServiceId @($positionals | Select-Object -Skip 1) -Apply:$apply -Force:$force -StateRoot $stateRoot
                $status=if ($apply) {'ok'} else {'planned'}
                $summarizeOperation=$apply
                if (-not $apply) { $actions=@($data.actions) }
            }
            'reconcile' {
                $plan=Get-TtCliBoolOption $options 'plan'; $force=Get-TtCliBoolOption $options 'force'; $context=[string](Get-TtCliOption $options 'context' 'manual')
                $data=Invoke-TtReconcile -ServiceId @($positionals | Select-Object -Skip 1) -Context $context -Plan:$plan -Force:$force -StateRoot $stateRoot
                $status=if ($plan) {'planned'} else {'ok'}
                $summarizeOperation=-not $plan
                $actions=@($data.plan.actions)
            }
            'service' {
                if ($positionals.Count -lt 2) { throw 'service requires a subcommand.' }
                $sub=[string]$positionals[1]
                switch ($sub) {
                    { $_ -in @('register','add') } {
                        $id=[string](Get-TtCliOption $options 'id' $null); $alias=[string](Get-TtCliOption $options 'alias' $null)
                        $org=ConvertTo-TtStringArray (Get-TtCliOption $options 'organization-id' $null); $workspace=ConvertTo-TtStringArray (Get-TtCliOption $options 'workspace-id' $null)
                        $common=@{ Id=$id; Alias=$alias; TunnelId=[string](Get-TtCliOption $options 'tunnel-id' $null); OrganizationId=$org; WorkspaceId=$workspace; RuntimeKeyRef=[string](Get-TtCliOption $options 'runtime-key-ref' $null); AdminProfile=[string](Get-TtCliOption $options 'admin-profile' $null); HealthUrl=[string](Get-TtCliOption $options 'health-url' $null); ReadyUrl=[string](Get-TtCliOption $options 'ready-url' $null); NoAutostart=(Get-TtCliBoolOption $options 'no-autostart'); NoWatchdog=(Get-TtCliBoolOption $options 'no-watchdog'); NoSourceWatch=(Get-TtCliBoolOption $options 'no-source-watch'); NoStart=(Get-TtCliBoolOption $options 'no-start'); Disabled=(Get-TtCliBoolOption $options 'disabled'); Force=(Get-TtCliBoolOption $options 'force'); StateRoot=$stateRoot }
                        if ($options.Contains('command')) { $data=Register-TtService -Command ([string]$options.command) -Argument ([string[]]@(Get-TtCliOption $options 'arg' @())) -WorkingDirectory ([string](Get-TtCliOption $options 'working-directory' (Get-Location).Path)) @common }
                        elseif ($options.Contains('url')) { $data=Register-TtService -Url ([string]$options.url) @common }
                        else {
                            if ($positionals.Count -lt 3) { throw 'service register requires PATH, --command FILE, or --url URL.' }
                            $data=Register-TtService -Path ([string]$positionals[2]) @common
                        }
                        $status=if ($data.startError) {'degraded'} else {'changed'}
                    }
                    'list' { $data=@(Get-TtService -StateRoot $stateRoot) }
                    'show' { if ($positionals.Count -lt 3) {throw 'service show requires ID.'}; $data=Get-TtService -Id $positionals[2] -StateRoot $stateRoot }
                    { $_ -in @('remove','rm','unregister') } { if ($positionals.Count -lt 3) {throw 'service remove requires ID.'}; $data=Unregister-TtService -Id $positionals[2] -KeepRunning:(Get-TtCliBoolOption $options 'keep-running') -Confirm:$false -StateRoot $stateRoot; $status='changed' }
                    'start' { if ($positionals.Count -lt 3) {throw 'service start requires ID.'}; $data=Start-TtService $positionals[2] -StateRoot $stateRoot; $status='changed' }
                    'stop' { if ($positionals.Count -lt 3) {throw 'service stop requires ID.'}; $data=Stop-TtService $positionals[2] -SessionOnly:(Get-TtCliBoolOption $options 'session-only') -StateRoot $stateRoot; $status='changed' }
                    'restart' { if ($positionals.Count -lt 3) {throw 'service restart requires ID.'}; $data=Restart-TtService $positionals[2] -StateRoot $stateRoot; $status='changed' }
                    'enable' { if ($positionals.Count -lt 3) {throw 'service enable requires ID.'}; $data=Start-TtService $positionals[2] -StateRoot $stateRoot; $status='changed' }
                    'disable' { if ($positionals.Count -lt 3) {throw 'service disable requires ID.'}; Stop-TtService $positionals[2] -StateRoot $stateRoot | Out-Null; $data=Set-TtServicePolicy $positionals[2] -Enabled $false -DesiredState stopped -StateRoot $stateRoot; $status='changed' }
                    'autostart' { if ($positionals.Count -lt 4) {throw 'service autostart requires ID and on|off.'}; $value=ConvertTo-TtBool $positionals[3]; $data=Set-TtServicePolicy $positionals[2] -Autostart $value -StateRoot $stateRoot; $status='changed' }
                    'watchdog' { if ($positionals.Count -lt 4) {throw 'service watchdog requires ID and on|off.'}; $value=ConvertTo-TtBool $positionals[3]; $data=Set-TtServicePolicy $positionals[2] -Watchdog $value -StateRoot $stateRoot; $status='changed' }
                    'import' { $data=Import-TtOfficialRuntime -Alias @($positionals | Select-Object -Skip 2) -Force:(Get-TtCliBoolOption $options 'force') -StateRoot $stateRoot; $status='changed' }
                    default { throw "Unknown service subcommand '$sub'." }
                }
            }
            'client' {
                if ($positionals.Count -lt 2) { throw 'client requires a subcommand.' }
                switch ([string]$positionals[1]) {
                    'status' { $data=Get-TtClientStatus $stateRoot }
                    'update' { $data=Update-TtClient -Force:(Get-TtCliBoolOption $options 'force') -CheckOnly:(Get-TtCliBoolOption $options 'check-only') -StateRoot $stateRoot; $status=if ($data.changed) {'changed'} else {'noop'} }
                    { $_ -in @('rollback','restore') } { $data=Restore-TtClient -BackupPath ([string](Get-TtCliOption $options 'backup' $null)) -StateRoot $stateRoot; $status='changed' }
                    default { throw "Unknown client subcommand '$($positionals[1])'." }
                }
            }
            'automation' {
                if ($positionals.Count -lt 2) { throw 'automation requires a subcommand.' }
                switch ([string]$positionals[1]) {
                    'install' { $data=Install-TtAutomation $stateRoot; $status='changed' }
                    'uninstall' { $data=Uninstall-TtAutomation; $status='changed' }
                    'status' { $data=Get-TtAutomationStatus $stateRoot }
                    'startup' { $data=Invoke-TtStartup -StateRoot $stateRoot -SkipUpdate:(Get-TtCliBoolOption $options 'skip-update'); $summarizeOperation=$true }
                    'watchdog' { $data=Invoke-TtWatchdog -StateRoot $stateRoot -Force:(Get-TtCliBoolOption $options 'force'); $summarizeOperation=$true }
                    'maintenance' { $data=Invoke-TtMaintenance -StateRoot $stateRoot -SkipClientUpdate:(Get-TtCliBoolOption $options 'skip-client-update') -SkipServiceUpdates:(Get-TtCliBoolOption $options 'skip-service-updates') -Force:(Get-TtCliBoolOption $options 'force'); $summarizeOperation=$true }
                    default { throw "Unknown automation subcommand '$($positionals[1])'." }
                }
            }
            'config' {
                if ($positionals.Count -lt 2) { throw 'config requires show or set.' }
                switch ([string]$positionals[1]) {
                    'show' { $data=Get-TtConfiguration $stateRoot }
                    'set' {
                        if ($positionals.Count -lt 4) { throw 'config set requires PATH and VALUE.' }
                        $raw=[string]$positionals[3]
                        $value=if ($raw -match '^(true|false)$') { ConvertTo-TtBool $raw } elseif ($raw -match '^-?\d+$') { [int]$raw } else { $raw }
                        $data=Set-TtConfiguration -Path $positionals[2] -Value $value -StateRoot $stateRoot; $status='changed'
                    }
                    default { throw "Unknown config subcommand '$($positionals[1])'." }
                }
            }
            default { throw "Unknown command '$commandName'. Run 'tunneltend --help'." }
        }
        if ($summarizeOperation) {
            $outcome = Get-TtOperationOutcome $data
            $status = $outcome.status
            $diagnostics = @($outcome.diagnostics)
            if ($status -eq 'degraded') { $message = 'Some operations failed; inspect diagnostics and per-service results.' }
        }
        $envelope=New-TtEnvelope -Command $commandName -Status $status -Data $data -Diagnostics $diagnostics -Actions $actions -Message $message
        Write-TtCliResult $envelope -Json:$json
        return $(if ($status -in @('degraded','error')) { 2 } else { 0 })
    }
    catch {
        $message=Protect-TtLogText $_.Exception.Message
        $envelope=New-TtEnvelope -Command $commandName -Status error -Data $null -Diagnostics @([ordered]@{ severity='error'; code='command.failed'; message=$message }) -Message $message
        Write-TtCliResult $envelope -Json:$json
        return 4
    }
}
