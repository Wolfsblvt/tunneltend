Set-StrictMode -Version Latest

$script:TtProductName = 'tunneltend'
$script:TtSchemaVersion = 1
$script:TtModuleVersion = '1.0.1'

function Test-TtWindows {
    [CmdletBinding()]
    param()
    return $IsWindows
}

function Get-TtUtcNow {
    [CmdletBinding()]
    param()
    return [DateTimeOffset]::UtcNow.ToString('o')
}

function ConvertTo-TtHashtable {
    [CmdletBinding()]
    param([AllowNull()][Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IDictionary]) {
            $result = [ordered]@{}
            foreach ($key in $InputObject.Keys) {
                $result[[string]$key] = ConvertTo-TtHashtable $InputObject[$key]
            }
            return $result
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $items = @()
            foreach ($item in $InputObject) { $items += ,(ConvertTo-TtHashtable $item) }
            return ,$items
        }
        if ($InputObject -is [pscustomobject]) {
            $result = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $result[$property.Name] = ConvertTo-TtHashtable $property.Value
            }
            return $result
        }
        return $InputObject
    }
}


function Get-TtMapValue {
    [CmdletBinding()]
    param([AllowNull()]$Map, [Parameter(Mandatory)][string]$Key, $Default = $null)
    if ($null -eq $Map) { return $Default }
    if ($Map -is [System.Collections.IDictionary] -and $Map.Contains($Key)) { return $Map[$Key] }
    $property = $Map.PSObject.Properties[$Key]
    if ($property) { return $property.Value }
    return $Default
}

function Copy-TtObject {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()]$InputObject)
    # Pipeline enumeration otherwise turns [] into null and [one] into a scalar
    # while merging descriptors; preserve the JSON value's collection shape.
    return ,((ConvertTo-Json -InputObject $InputObject -Depth 100 -Compress) | ConvertFrom-Json -AsHashtable -Depth 100 -NoEnumerate)
}


function Merge-TtHashtable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Base, [Parameter(Mandatory)][hashtable]$Overlay)
    $result = Copy-TtObject $Base
    foreach ($key in $Overlay.Keys) {
        if ($result.Contains($key) -and $result[$key] -is [System.Collections.IDictionary] -and $Overlay[$key] -is [System.Collections.IDictionary]) {
            $result[$key] = Merge-TtHashtable ([hashtable](ConvertTo-TtHashtable $result[$key])) ([hashtable](ConvertTo-TtHashtable $Overlay[$key]))
        } else {
            $result[$key] = Copy-TtObject $Overlay[$key]
        }
    }
    return $result
}

function Get-TtDefaultStateRoot {
    [CmdletBinding()]
    param()
    if (-not [string]::IsNullOrWhiteSpace($env:TUNNELTEND_STATE_DIR)) {
        return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($env:TUNNELTEND_STATE_DIR))
    }
    $receiptPath = [IO.Path]::GetFullPath([IO.Path]::Combine($script:TtModuleRoot, '..', '..', 'install.json'))
    if ([IO.File]::Exists($receiptPath)) {
        $receipt = [IO.File]::ReadAllText($receiptPath) | ConvertFrom-Json -AsHashtable
        $installedState = [string](Get-TtMapValue $receipt 'stateRoot' '')
        if (-not [IO.Path]::IsPathRooted($installedState)) { throw "Installation receipt '$receiptPath' requires an absolute stateRoot." }
        return [IO.Path]::GetFullPath($installedState)
    }
    if ($IsWindows) {
        $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }
        return [IO.Path]::Combine($base, 'TunnelTend', 'state')
    }
    $base = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { [IO.Path]::Combine($HOME, '.local', 'state') }
    return [IO.Path]::Combine($base, 'tunneltend')
}

function Get-TtDefaultInstallRoot {
    [CmdletBinding()]
    param()
    if ($IsWindows) {
        $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }
        return [IO.Path]::Combine($base, 'Programs', 'TunnelTend')
    }
    return [IO.Path]::Combine($HOME, '.local', 'share', 'tunneltend')
}

function Resolve-TtStateRoot {
    [CmdletBinding()]
    param([string]$StateRoot)
    $candidate = if ([string]::IsNullOrWhiteSpace($StateRoot)) { Get-TtDefaultStateRoot } else { $StateRoot }
    return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($candidate))
}

function Get-TtPaths {
    [CmdletBinding()]
    param([string]$StateRoot)
    $root = Resolve-TtStateRoot $StateRoot
    return [ordered]@{
        Root          = $root
        Registry      = [IO.Path]::Combine($root, 'registry.json')
        Runtime       = [IO.Path]::Combine($root, 'runtime.json')
        Logs          = [IO.Path]::Combine($root, 'logs')
        Backups       = [IO.Path]::Combine($root, 'backups')
        Work          = [IO.Path]::Combine($root, 'work')
        ClientUpdater = [IO.Path]::Combine($root, 'official-client-updater.json')
    }
}

function Initialize-TtStateDirectories {
    [CmdletBinding()]
    param([string]$StateRoot)
    $paths = Get-TtPaths $StateRoot
    foreach ($path in @($paths.Root, $paths.Logs, $paths.Backups, $paths.Work)) {
        [IO.Directory]::CreateDirectory($path) | Out-Null
    }
    return $paths
}

function Get-TtStableHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value, [int]$Length = 16)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    $hex = [Convert]::ToHexString($hash).ToLowerInvariant()
    return $hex.Substring(0, [Math]::Min($Length, $hex.Length))
}

function Invoke-WithTtLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$StateRoot,
        [int]$TimeoutSeconds = 45
    )
    $root = Resolve-TtStateRoot $StateRoot
    $name = if ($IsWindows) { "Local$([char]92)TunnelTend-" + (Get-TtStableHash $root 24) } else { 'TunnelTend-' + (Get-TtStableHash $root 24) }
    $created = $false
    $mutex = [Threading.Mutex]::new($false, $name, [ref]$created)
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds)) }
        catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) { throw "Timed out waiting for the tunneltend state lock at '$root'." }
        return & $ScriptBlock
    }
    finally {
        if ($acquired) { try { $mutex.ReleaseMutex() } catch { } }
        $mutex.Dispose()
    }
}

function Read-TtJsonFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, $DefaultValue)
    if (-not [IO.File]::Exists($Path)) { return Copy-TtObject $DefaultValue }
    try {
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($text)) { throw 'file is empty' }
        return ($text | ConvertFrom-Json -AsHashtable -Depth 100)
    }
    catch {
        throw "State file '$Path' is not valid JSON: $($_.Exception.Message)"
    }
}

function Write-TtJsonAtomic {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    $directory = [IO.Path]::GetDirectoryName($Path)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temp = [IO.Path]::Combine($directory, ".$( [IO.Path]::GetFileName($Path) ).$([Guid]::NewGuid().ToString('N')).tmp")
    try {
        $json = $Value | ConvertTo-Json -Depth 100
        [IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temp, $Path, $true)
    }
    finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

function Test-TtSecretReference {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -ne $Value.Trim() -or $Value.Contains([char]0) -or $Value -match '[\r\n]') {
        return $false
    }
    if ($Value -match '^env:[A-Za-z_][A-Za-z0-9_]*$') { return $true }
    if ($Value -match '^file:(?<path>.+)$') { return -not [string]::IsNullOrWhiteSpace($Matches.path) }
    return $false
}

function Resolve-TtSecretReference {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Reference)
    if ($Reference -match '^env:(?<name>[A-Za-z_][A-Za-z0-9_]*)$') {
        $value = [Environment]::GetEnvironmentVariable($Matches.name)
        if ([string]::IsNullOrEmpty($value)) { throw "Environment variable '$($Matches.name)' is not set." }
        return $value
    }
    if ($Reference -match '^file:(?<path>.+)$') {
        $path = [Environment]::ExpandEnvironmentVariables($Matches.path)
        if (-not [IO.File]::Exists($path)) { throw "Secret reference file '$path' does not exist." }
        return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8).Trim()
    }
    throw "Secret values must use env:NAME or file:/path references."
}

function Test-TtLikelySecretMaterial {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $patterns = @(
        'sk-[A-Za-z0-9_-]{12,}',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[=:]\s*\S+',
        '://[^/\s@]+@'
    )
    foreach ($pattern in $patterns) { if ($Value -match $pattern) { return $true } }
    return $false
}

function Assert-TtNoInlineSecrets {
    [CmdletBinding()]
    param([AllowNull()]$Value, [string]$Field = 'value')
    if ($null -eq $Value) { return }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) { Assert-TtNoInlineSecrets $Value[$key] "$Field.$key" }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $index = 0
        foreach ($item in $Value) { Assert-TtNoInlineSecrets $item "$Field[$index]"; $index++ }
        return
    }
    $text = [string]$Value
    if (Test-TtLikelySecretMaterial $text) { throw "$Field appears to contain inline secret material. Use env:NAME or file:/path." }
}

function Protect-TtLogText {
    [CmdletBinding()]
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $redacted = $Text
    $redacted = [regex]::Replace($redacted, 'sk-[A-Za-z0-9_-]{12,}', '[REDACTED]')
    $redacted = [regex]::Replace($redacted, '(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]{8,}', '$1[REDACTED]')
    $redacted = [regex]::Replace($redacted, '(?i)((?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[=:]\s*)\S+', '$1[REDACTED]')
    return $redacted
}

function Write-TtLog {
    [CmdletBinding()]
    param(
        [ValidateSet('debug','info','warning','error')][string]$Level = 'info',
        [Parameter(Mandatory)][string]$Event,
        [string]$Message,
        [hashtable]$Data,
        [string]$StateRoot
    )
    $paths = Initialize-TtStateDirectories $StateRoot
    $entry = [ordered]@{
        timestamp = Get-TtUtcNow
        level = $Level
        event = $Event
        message = Protect-TtLogText $Message
    }
    if ($Data) { $entry.data = ConvertTo-TtHashtable $Data }
    $line = $entry | ConvertTo-Json -Compress -Depth 30
    $logPath = [IO.Path]::Combine($paths.Logs, "tunneltend-$([DateTimeOffset]::Now.ToString('yyyy-MM-dd')).jsonl")
    [IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function New-TtEnvelope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [ValidateSet('ok','degraded','error','planned','changed','noop')][string]$Status = 'ok',
        [AllowNull()]$Data,
        [object[]]$Diagnostics = @(),
        [object[]]$Actions = @(),
        [string]$Message
    )
    return [ordered]@{
        schema_version = 1
        product = 'tunneltend'
        product_version = $script:TtModuleVersion
        timestamp = Get-TtUtcNow
        command = $Command
        status = $Status
        message = $Message
        data = $Data
        diagnostics = @($Diagnostics)
        actions = @($Actions)
    }
}

function ConvertTo-TtServiceId {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)
    $id = $Value.Trim().ToLowerInvariant()
    $id = $id -replace '_', '-'
    $id = $id -replace '[^a-z0-9.-]+', '-'
    $id = $id -replace '-{2,}', '-'
    $id = $id.Trim('-', '.')
    if ([string]::IsNullOrWhiteSpace($id)) { throw 'A service id must contain an ASCII letter or number.' }
    if ($id.Length -gt 96) { throw 'A service id may not exceed 96 characters.' }
    return $id
}

function Resolve-TtServiceSelection {
    [CmdletBinding()]
    param(
        [AllowNull()][string[]]$ServiceId,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Services
    )

    $selected = @(
        $ServiceId |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            ForEach-Object { ConvertTo-TtServiceId ([string]$_) }
    )
    if ($selected.Count -gt 0) { return $selected }
    return @($Services.Keys | Sort-Object)
}

function Resolve-TtExecutable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath, [string]$WorkingDirectory)
    $expanded = [Environment]::ExpandEnvironmentVariables($FilePath)
    if ([IO.Path]::IsPathRooted($expanded)) {
        if (-not [IO.File]::Exists($expanded)) { throw "Executable '$expanded' does not exist." }
        return [IO.Path]::GetFullPath($expanded)
    }
    if ($WorkingDirectory) {
        $candidate = [IO.Path]::GetFullPath([IO.Path]::Combine($WorkingDirectory, $expanded))
        if ([IO.File]::Exists($candidate)) { return $candidate }
    }
    $command = Get-Command $expanded -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw "Executable '$FilePath' was not found." }
    return [IO.Path]::GetFullPath($command.Source)
}

function ConvertTo-TtWindowsCommandArgument {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Argument)
    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') { return $Argument }
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($slashes * 2) + 1)))
            [void]$builder.Append('"')
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) { [void]$builder.Append(('\' * $slashes)); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-TtCommandLine {
    [CmdletBinding()]
    param([string[]]$Arguments)
    return (($Arguments | ForEach-Object { ConvertTo-TtWindowsCommandArgument ([string]$_) }) -join ' ')
}

function Invoke-TtProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory,
        [hashtable]$Environment,
        [int]$TimeoutSeconds = 60,
        [switch]$AllowFailure,
        [string]$StandardInput
    )
    if ($IsWindows -and ([IO.Path]::GetFileName($FilePath) -match '^pwsh\.console-original-[0-9]+\.exe$' -or $FilePath -in @('pwsh','pwsh.exe'))) { $FilePath = Get-TtPowerShellExecutable }
    $ArgumentList = Get-TtUnattendedPowerShellArguments $FilePath $ArgumentList
    $resolved = Resolve-TtExecutable $FilePath $WorkingDirectory
    $resolved = Resolve-TtPowerShellProcessPath $resolved
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $resolved
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $null -ne $StandardInput
    if ($WorkingDirectory) { $psi.WorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory) }
    foreach ($argument in @($ArgumentList)) { [void]$psi.ArgumentList.Add([string]$argument) }
    if ($Environment) {
        foreach ($key in $Environment.Keys) { $psi.Environment[[string]$key] = [string]$Environment[$key] }
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $startedAt = [DateTimeOffset]::UtcNow
    if (-not $process.Start()) { throw "Failed to start '$resolved'." }
    if ($null -ne $StandardInput) { $process.StandardInput.Write($StandardInput); $process.StandardInput.Close() }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill($true) } catch { }
        $process.WaitForExit()
        throw "Command '$resolved' timed out after $TimeoutSeconds seconds."
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $result = [ordered]@{
        file_path = $resolved
        arguments = @($ArgumentList)
        exit_code = $process.ExitCode
        stdout = $stdout
        stderr = $stderr
        started_at = $startedAt.ToString('o')
        finished_at = (Get-TtUtcNow)
    }
    $process.Dispose()
    if (-not $AllowFailure -and $result.exit_code -ne 0) {
        $detail = Protect-TtLogText (($result.stderr + [Environment]::NewLine + $result.stdout).Trim())
        throw "Command '$resolved' failed with exit code $($result.exit_code): $detail"
    }
    return $result
}

function Start-TtDetachedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory,
        [hashtable]$Environment
    )
    if ($IsWindows -and ([IO.Path]::GetFileName($FilePath) -match '^pwsh\.console-original-[0-9]+\.exe$' -or $FilePath -in @('pwsh','pwsh.exe'))) { $FilePath = Get-TtPowerShellExecutable }
    $ArgumentList = Get-TtUnattendedPowerShellArguments $FilePath $ArgumentList
    $resolved = Resolve-TtExecutable $FilePath $WorkingDirectory
    $resolved = Resolve-TtPowerShellProcessPath $resolved
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $resolved
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory) }
    foreach ($argument in @($ArgumentList)) { [void]$psi.ArgumentList.Add([string]$argument) }
    if ($Environment) {
        foreach ($key in $Environment.Keys) { $psi.Environment[[string]$key] = [string]$Environment[$key] }
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw "Failed to start '$resolved'." }
    $record = [ordered]@{
        pid = $process.Id
        executable_path = $resolved
        start_time_utc = $process.StartTime.ToUniversalTime().ToString('o')
        command_hash = Get-TtStableHash (($resolved, @($ArgumentList), $WorkingDirectory) | ConvertTo-Json -Compress) 32
    }
    $process.Dispose()
    return $record
}

function Get-TtProcessInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$ProcessId)
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $path = $null
        try { $path = $process.Path } catch { }
        $start = $null
        try { $start = $process.StartTime.ToUniversalTime().ToString('o') } catch { }
        return [ordered]@{ running = $true; pid = $ProcessId; executable_path = $path; start_time_utc = $start }
    }
    catch {
        if ($_.CategoryInfo.Category -ne [Management.Automation.ErrorCategory]::ObjectNotFound) { throw }
        return [ordered]@{ running = $false; pid = $ProcessId; executable_path = $null; start_time_utc = $null }
    }
}

function Test-TtOwnedProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$ProcessRecord)
    if (-not $ProcessRecord.pid) { return $false }
    $info = Get-TtProcessInfo ([int]$ProcessRecord.pid)
    if (-not $info.running) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$info.executable_path)) { return $false }
    if (-not $ProcessRecord.start_time_utc -or -not $info.start_time_utc) { return $false }
    $expected = [IO.Path]::GetFullPath([string]$ProcessRecord.executable_path)
    $actual = [IO.Path]::GetFullPath([string]$info.executable_path)
    if (-not [string]::Equals($expected, $actual, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if ($ProcessRecord.start_time_utc -and $info.start_time_utc) {
        # JSON readers on supported PowerShell versions may materialize dates.
        # Casting those through string loses their Kind/offset and precision.
        $expectedStart = [DateTimeOffset]$ProcessRecord.start_time_utc
        $actualStart = [DateTimeOffset]$info.start_time_utc
        if ([Math]::Abs(($expectedStart - $actualStart).TotalSeconds) -gt 2) { return $false }
    }
    return $true
}

function Stop-TtOwnedProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$ProcessRecord, [int]$TimeoutSeconds = 15)
    if (-not (Test-TtOwnedProcess $ProcessRecord)) {
        throw "Refusing to terminate PID '$($ProcessRecord.pid)' because its executable identity or start time does not match the recorded owned process."
    }
    $process = Get-Process -Id ([int]$ProcessRecord.pid) -ErrorAction Stop
    try { $process.CloseMainWindow() | Out-Null } catch { }
    try { $process.WaitForExit($TimeoutSeconds * 1000) | Out-Null } catch { }
    if (-not $process.HasExited) {
        $process.Kill($true)
        $process.WaitForExit($TimeoutSeconds * 1000) | Out-Null
    }
    if (-not $process.HasExited) { throw "Owned process '$($ProcessRecord.pid)' did not exit after termination was requested." }
}

function Get-TtResolvedEnvironment {
    [CmdletBinding()]
    param([AllowNull()][hashtable]$References)
    $result = @{}
    if (-not $References) { return $result }
    foreach ($name in $References.Keys) {
        $reference = [string]$References[$name]
        if (-not (Test-TtSecretReference $reference)) { throw "Environment entry '$name' must be an env:NAME or file:/path reference." }
        $result[[string]$name] = Resolve-TtSecretReference $reference
    }
    return $result
}

function Compare-TtVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Left, [Parameter(Mandatory)][string]$Right)
    $l = [System.Management.Automation.SemanticVersion]::Parse($Left.TrimStart('v'))
    $r = [System.Management.Automation.SemanticVersion]::Parse($Right.TrimStart('v'))
    return $l.CompareTo($r)
}

function Parse-TtCliArguments {
    [CmdletBinding()]
    param([string[]]$Arguments)

    $booleanOptions = @(
        'json', 'help', 'apply', 'force', 'plan',
        'no-autostart', 'no-watchdog', 'no-source-watch', 'no-start', 'disabled',
        'keep-running', 'session-only', 'check-only', 'import-all', 'non-interactive',
        'skip-automation-install', 'skip-update', 'skip-client-update', 'skip-service-updates'
    )
    $options = [ordered]@{}
    $positionals = [Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt @($Arguments).Count; $index++) {
        $token = [string]$Arguments[$index]
        if ($token -eq '--') {
            foreach ($remaining in @($Arguments | Select-Object -Skip ($index + 1))) {
                $positionals.Add([string]$remaining)
            }
            break
        }
        if ($token -notmatch '^--(?<name>[A-Za-z0-9][A-Za-z0-9-]*)(=(?<inline>.*))?$') {
            $positionals.Add($token)
            continue
        }
        $name = $Matches.name.ToLowerInvariant()
        $value = $true
        $hasInlineValue = $Matches.ContainsKey('inline')
        if ($hasInlineValue) { $value = [string]$Matches.inline }
        elseif ($name -notin $booleanOptions -and ($index + 1) -lt @($Arguments).Count -and [string]$Arguments[$index + 1] -notmatch '^--[A-Za-z0-9]') {
            $index++
            $value = [string]$Arguments[$index]
        }
        if ($options.Contains($name)) {
            if ($options[$name] -isnot [Collections.IList]) { $options[$name] = @($options[$name]) }
            $options[$name] += $value
        }
        else { $options[$name] = $value }
    }
    return [ordered]@{ positionals = @($positionals); options = $options }
}

function Get-TtCliOption {
    [CmdletBinding()]
    param([System.Collections.IDictionary]$Options, [Parameter(Mandatory)][string]$Name, $Default = $null)
    $key = $Name.ToLowerInvariant()
    if ($Options -and $Options.Contains($key)) { return $Options[$key] }
    return $Default
}

function ConvertTo-TtBool {
    [CmdletBinding()]
    param($Value, [bool]$Default = $false)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }
    switch -Regex ([string]$Value) {
        '^(1|true|yes|on)$' { return $true }
        '^(0|false|no|off)$' { return $false }
        default { throw "'$Value' is not a boolean value." }
    }
}

function ConvertTo-TtStringArray {
    [CmdletBinding()]
    param($Value, [switch]$RejectEmpty)
    if ($null -eq $Value) { return @() }
    $result = @()
    foreach ($item in @($Value)) {
        foreach ($part in ([string]$item -split ',')) {
            if ($RejectEmpty -and [string]::IsNullOrWhiteSpace($part)) { throw 'Tunnel scope selectors must not contain empty values.' }
            if (-not [string]::IsNullOrWhiteSpace($part)) { $result += $part.Trim() }
        }
    }
    return @($result)
}
