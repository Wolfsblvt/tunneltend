Set-StrictMode -Version Latest

function ConvertTo-TtPosixShellArgument {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Argument)

    if ($Argument -match '^[A-Za-z0-9_./:@%+=,-]+$') { return $Argument }

    # tunnel-client parses mcp.command with its own POSIX-like argv parser on
    # every supported operating system. Do not use Windows CommandLineToArgvW
    # quoting here merely because TunnelTend itself is running on Windows.
    $quote = [string][char]39
    $replacement = $quote + '\' + $quote + $quote
    return $quote + $Argument.Replace($quote, $replacement) + $quote
}

function ConvertTo-TtCommandString {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$File, [string[]]$Arguments = @())

    $parts = @($File) + @($Arguments)
    return (($parts | ForEach-Object { ConvertTo-TtPosixShellArgument ([string]$_) }) -join ' ')
}

function Get-TtOfficialClientPath {
    [CmdletBinding()]
    param([hashtable]$Registry, [string]$StateRoot, [switch]$AllowMissing)
    if (-not $Registry) { $Registry = Get-TtRegistry $StateRoot }
    $configured = [Environment]::ExpandEnvironmentVariables([string]$Registry.settings.officialClient.executablePath)
    if ([IO.File]::Exists($configured)) { return [IO.Path]::GetFullPath($configured) }
    $candidate = Get-Command 'tunnel-client' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { return [IO.Path]::GetFullPath($candidate.Source) }
    if ($AllowMissing) { return [IO.Path]::GetFullPath($configured) }
    throw "The official tunnel-client executable was not found at '$configured' or on PATH. Run 'tunneltend client update --force'."
}

function Invoke-TtOfficialClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Registry,
        [string]$StateRoot,
        [int]$TimeoutSeconds = 60,
        [switch]$AllowFailure,
        [hashtable]$Environment,
        [string]$WorkingDirectory
    )
    if (-not $Registry) { $Registry = Get-TtRegistry $StateRoot }
    $path = Get-TtOfficialClientPath $Registry $StateRoot
    return Invoke-TtProcess -FilePath $path -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -TimeoutSeconds $TimeoutSeconds -AllowFailure:$AllowFailure -Environment $Environment
}

function Invoke-TtOfficialClientJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Registry,
        [string]$StateRoot,
        [int]$TimeoutSeconds = 60,
        [switch]$AllowFailure,
        [hashtable]$Environment,
        [string]$WorkingDirectory
    )
    $result = Invoke-TtOfficialClient -Arguments $Arguments -Registry $Registry -StateRoot $StateRoot -WorkingDirectory $WorkingDirectory -TimeoutSeconds $TimeoutSeconds -AllowFailure:$AllowFailure -Environment $Environment
    $payload = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$result.stdout)) {
        try { $payload = $result.stdout | ConvertFrom-Json -AsHashtable -Depth 100 }
        catch {
            if (-not $AllowFailure) { throw "Official tunnel-client did not return valid JSON for '$($Arguments -join ' ')'." }
        }
    }
    return [ordered]@{ process = $result; payload = $payload }
}

function Get-TtOfficialClientVersion {
    [CmdletBinding()]
    param([hashtable]$Registry, [string]$StateRoot)
    try {
        $result = Invoke-TtOfficialClient -Arguments @('--version') -Registry $Registry -StateRoot $StateRoot -TimeoutSeconds 15
        $text = ([string]$result.stdout).Trim()
        $version = $null
        if ($text -match '(?<version>[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)') { $version = $Matches.version }
        return [ordered]@{ installed = $true; version = $version; raw = $text; path = $result.file_path }
    }
    catch {
        return [ordered]@{ installed = $false; version = $null; raw = $null; path = (Get-TtOfficialClientPath $Registry $StateRoot -AllowMissing); error = $_.Exception.Message }
    }
}

function Test-TtOfficialClientCapabilities {
    [CmdletBinding()]
    param([hashtable]$Registry, [string]$StateRoot)
    $checks = @(
        [ordered]@{ id='version'; arguments=@('--version'); pattern='[0-9]+\.[0-9]+\.[0-9]+' },
        [ordered]@{ id='runtimes'; arguments=@('runtimes','--help'); pattern='connect' },
        [ordered]@{ id='runtimes-json'; arguments=@('runtimes','--help'); pattern='--json' },
        [ordered]@{ id='runtime-status'; arguments=@('runtimes','status','--help'); pattern='Inspect' },
        [ordered]@{ id='runtime-connect'; arguments=@('runtimes','connect','--help'); pattern='--mcp-(server-url|command)' },
        [ordered]@{ id='runtime-stop'; arguments=@('runtimes','stop','--help'); pattern='Stop' }
    )
    $results = @()
    foreach ($check in $checks) {
        try {
            $result = Invoke-TtOfficialClient -Arguments $check.arguments -Registry $Registry -StateRoot $StateRoot -TimeoutSeconds 20 -AllowFailure
            $text = ([string]$result.stdout) + [Environment]::NewLine + ([string]$result.stderr)
            $ok = $result.exit_code -eq 0 -and $text -match $check.pattern
            $results += [ordered]@{ id=$check.id; ok=$ok; exit_code=$result.exit_code; expected=$check.pattern }
        }
        catch { $results += [ordered]@{ id=$check.id; ok=$false; error=$_.Exception.Message } }
    }
    return [ordered]@{ compatible = (@($results | Where-Object { -not $_.ok }).Count -eq 0); checks = $results }
}

function Get-TtOfficialRuntimeList {
    [CmdletBinding()]
    param([hashtable]$Registry, [string]$StateRoot)
    $result = Invoke-TtOfficialClientJson -Arguments @('runtimes','list','--json') -Registry $Registry -StateRoot $StateRoot -TimeoutSeconds 30 -AllowFailure
    if ($result.process.exit_code -ne 0) {
        throw "Unable to list official runtimes: $(Protect-TtLogText (($result.process.stderr + $result.process.stdout).Trim()))"
    }
    $aliases = if ($result.payload -and $result.payload.aliases) { @($result.payload.aliases) } else { @() }
    return [ordered]@{ aliases=$aliases; raw=$result.payload }
}

function ConvertTo-TtRuntimeObservation {
    [CmdletBinding()]
    param([AllowNull()][hashtable]$Payload, [int]$ExitCode = 0, [string]$Error)
    if (-not $Payload) {
        return [ordered]@{ known=$false; running=$false; healthy=$false; ready=$false; state='missing'; error=$Error; raw=$null }
    }
    $running = $false
    $local = Get-TtMapValue $Payload 'local' $null
    foreach ($candidate in @((Get-TtMapValue $Payload 'process_running' $null),(Get-TtMapValue $Payload 'running' $null),(Get-TtMapValue $local 'process_running' $null))) {
        if ($candidate -is [bool]) { $running = $candidate; break }
    }
    $healthyValue = Get-TtMapValue $Payload 'healthy' $false
    $readyValue = Get-TtMapValue $Payload 'ready' $false
    $healthy = if ($healthyValue -is [bool]) { [bool]$healthyValue } else { $false }
    $ready = if ($readyValue -is [bool]) { [bool]$readyValue } else { $false }
    $state = [string](Get-TtMapValue $Payload 'runtime_state' '')
    if ([string]::IsNullOrWhiteSpace($state)) {
        $state = if ($ready) { 'ready' } elseif ($healthy) { 'healthy' } elseif ($running) { 'starting' } else { 'stopped' }
    }
    return [ordered]@{
        known = $true
        running = $running
        healthy = $healthy
        ready = $ready
        state = $state
        alias = [string](Get-TtMapValue $Payload 'alias' '')
        tunnel_id = [string](Get-TtMapValue $Payload 'tunnel_id' '')
        health_url = [string](Get-TtMapValue $Payload 'health_url' '')
        ui_url = [string](Get-TtMapValue $Payload 'ui_url' '')
        process = Get-TtMapValue $Payload 'process' $null
        repair_actions = @((Get-TtMapValue $Payload 'repair_actions' @()))
        exit_code = $ExitCode
        error = $Error
        raw = $Payload
    }
}

function Get-TtOfficialRuntimeStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Alias, [hashtable]$Registry, [string]$StateRoot)
    try { $result = Invoke-TtOfficialClientJson -Arguments @('runtimes','status',$Alias,'--json') -Registry $Registry -StateRoot $StateRoot -TimeoutSeconds 30 -AllowFailure }
    catch { return ConvertTo-TtRuntimeObservation -Payload $null -ExitCode 127 -Error (Protect-TtLogText $_.Exception.Message) }
    $errorText = Protect-TtLogText (($result.process.stderr + [Environment]::NewLine + $result.process.stdout).Trim())
    if (-not $result.payload) { return ConvertTo-TtRuntimeObservation -Payload $null -ExitCode $result.process.exit_code -Error $errorText }
    return ConvertTo-TtRuntimeObservation -Payload $result.payload -ExitCode $result.process.exit_code -Error $(if ($result.process.exit_code -eq 0) { $null } else { $errorText })
}

function Get-TtConnectArguments {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service)
    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($item in @('runtimes','connect','--alias',[string]$Service.tunnel.alias)) { $arguments.Add($item) }
    if ($Service.tunnel.adminProfile) { $arguments.Add('--admin-profile'); $arguments.Add([string]$Service.tunnel.adminProfile) }
    if ($Service.tunnel.tunnelId) { $arguments.Add('--tunnel-id'); $arguments.Add([string]$Service.tunnel.tunnelId) }
    else {
        foreach ($id in @($Service.tunnel.organizationIds)) { $arguments.Add('--organization-id'); $arguments.Add([string]$id) }
        foreach ($id in @($Service.tunnel.workspaceIds)) { $arguments.Add('--workspace-id'); $arguments.Add([string]$id) }
    }
    if ($Service.tunnel.runtimeKeyRef) { $arguments.Add('--runtime-api-key'); $arguments.Add([string]$Service.tunnel.runtimeKeyRef) }
    if ($Service.tunnel.profileName) { $arguments.Add('--profile'); $arguments.Add([string]$Service.tunnel.profileName) }
    if ($Service.tunnel.profileDirectory) { $arguments.Add('--profile-dir'); $arguments.Add([string]$Service.tunnel.profileDirectory) }
    if ([string]$Service.mcp.kind -eq 'url') {
        $arguments.Add('--mcp-server-url'); $arguments.Add([string]$Service.mcp.url)
    }
    elseif ([string]$Service.mcp.kind -eq 'commandString') {
        $arguments.Add('--mcp-command'); $arguments.Add([string]$Service.mcp.commandString)
    }
    else {
        $command = $Service.mcp.command
        $file = Resolve-TtExecutable ([string]$command.file) ([string]$command.workingDirectory)
        $commandString = ConvertTo-TtCommandString -File $file -Arguments @($command.arguments)
        $arguments.Add('--mcp-command'); $arguments.Add($commandString)
    }
    $arguments.Add('--json')
    return @($arguments)
}

function Start-TtOfficialRuntime {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Service, [hashtable]$Registry, [string]$StateRoot, [int]$TimeoutSeconds = 90)
    if (-not $Service.tunnel.tunnelId -and @($Service.tunnel.organizationIds).Count -eq 0 -and @($Service.tunnel.workspaceIds).Count -eq 0) {
        throw "Service '$($Service.id)' needs tunnel.tunnelId, tunnel.organizationIds, or tunnel.workspaceIds before it can start."
    }
    $environment = @{}
    $workingDirectory = $null
    if ($Service.mcp.kind -eq 'command') { $workingDirectory = [string]$Service.mcp.command.workingDirectory }
    if ($Service.mcp.kind -eq 'command' -and $Service.mcp.command.environment) {
        $environment = Get-TtResolvedEnvironment $Service.mcp.command.environment
    }
    $result = Invoke-TtOfficialClientJson -Arguments (Get-TtConnectArguments $Service) -Registry $Registry -StateRoot $StateRoot -WorkingDirectory $workingDirectory -TimeoutSeconds $TimeoutSeconds -AllowFailure -Environment $environment
    $errorText = Protect-TtLogText (($result.process.stderr + [Environment]::NewLine + $result.process.stdout).Trim())
    if ($result.process.exit_code -ne 0) {
        throw "Official runtime connect failed for '$($Service.id)': $errorText"
    }
    return ConvertTo-TtRuntimeObservation -Payload $result.payload -ExitCode $result.process.exit_code
}

function Stop-TtOfficialRuntime {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Alias, [hashtable]$Registry, [string]$StateRoot, [int]$TimeoutSeconds = 45)
    $result = Invoke-TtOfficialClientJson -Arguments @('runtimes','stop',$Alias,'--json') -Registry $Registry -StateRoot $StateRoot -TimeoutSeconds $TimeoutSeconds -AllowFailure
    if ($result.process.exit_code -ne 0) {
        $text = Protect-TtLogText (($result.process.stderr + [Environment]::NewLine + $result.process.stdout).Trim())
        if ($text -notmatch '(?i)(not known|not found|already stopped)') { throw "Official runtime stop failed for '$Alias': $text" }
    }
    return $result.payload
}
