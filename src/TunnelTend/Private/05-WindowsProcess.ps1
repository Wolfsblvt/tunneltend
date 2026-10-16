Set-StrictMode -Version Latest

function Get-TtPowerShellExecutable {
    [CmdletBinding()]
    param([string]$ExplicitPath)
    if (-not $IsWindows) { return (Get-Process -Id $PID).Path }
    if (-not $ExplicitPath) {
        $receiptPath = [IO.Path]::GetFullPath((Join-Path $script:TtModuleRoot '../../install.json'))
        if ([IO.File]::Exists($receiptPath)) {
            $receipt = Read-TtJsonFile $receiptPath
            $ExplicitPath = [string](Get-TtMapValue $receipt 'powerShellPath' '')
        }
    }
    if ($ExplicitPath) {
        $path = [Environment]::ExpandEnvironmentVariables($ExplicitPath)
        if (-not [IO.Path]::IsPathFullyQualified($path) -or -not [IO.File]::Exists($path)) { throw 'PowerShellPath must name an existing absolute PowerShell executable.' }
        return [IO.Path]::GetFullPath($path)
    }
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) { $candidates += Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe' }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { $candidates += Join-Path $env:LOCALAPPDATA 'Microsoft/WindowsApps/pwsh.exe' }
    foreach ($path in $candidates) {
        if ([IO.File]::Exists($path)) { return $path }
    }
    throw 'Install PowerShell 7.4 or newer normally, or supply -PowerShellPath to the TunnelTend installer for a portable installation.'
}

function Get-TtWindowsLauncherPath {
    [CmdletBinding()]
    param([string]$StateRoot)
    $root = [IO.Path]::GetFullPath((Join-Path $script:TtModuleRoot '../..'))
    $packaged = Join-Path $root 'bin/TunnelTend.TaskHost.exe'
    if ([IO.File]::Exists($packaged)) { return $packaged }
    # Source-checkout automation remains usable without a separate build ritual.
    $source = Join-Path $script:TtModuleRoot 'Native/HiddenTaskLauncher.cs'
    $builder = Join-Path $root 'scripts/Build-WindowsLauncher.ps1'
    $hash = Get-TtStableHash ([IO.File]::ReadAllText($source) + [IO.File]::ReadAllText($builder)) 32
    $output = Join-Path (Get-TtPaths $StateRoot).Work "native/$hash/TunnelTend.TaskHost.exe"
    if (-not [IO.File]::Exists($output)) { & $builder -OutputPath $output | Out-Null }
    return $output
}

function Resolve-TtPowerShellProcessPath {
    [CmdletBinding()]
    param([string]$Path)
    $alias = if ($IsWindows -and -not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { Join-Path $env:LOCALAPPDATA 'Microsoft/WindowsApps/pwsh.exe' } else { '' }
    if ($IsWindows -and [string]::Equals([IO.Path]::GetFullPath($Path), $alias, [StringComparison]::OrdinalIgnoreCase)) {
        # Keep the stable alias in task/installation configuration, but bind an
        # owned process to the concrete package executable before starting it.
        $package = Get-AppxPackage -Name Microsoft.PowerShell | Select-Object -First 1
        if (-not $package) { throw 'The PowerShell application alias has no installed Microsoft.PowerShell package.' }
        $executable = Join-Path $package.InstallLocation 'pwsh.exe'
        if (-not [IO.File]::Exists($executable)) { throw 'The installed PowerShell package executable is unavailable.' }
        return $executable
    }
    return $Path
}

function Get-TtUnattendedPowerShellArguments {
    [CmdletBinding()]
    param([string]$FilePath, [string[]]$Arguments)
    if (-not $IsWindows -or [IO.Path]::GetFileName($FilePath) -notmatch '^(?:pwsh|powershell)(?:\.exe|\.console-original-[0-9]+\.exe)?$') { return ,@($Arguments) }
    $copy = @($Arguments)
    $boundary = $copy.Count
    for ($index = 0; $index -lt $copy.Count; $index++) {
        if ($copy[$index] -match '^-(?:File|Command|EncodedCommand|CommandWithArgs|f|c|e|ec)$') { $boundary = $index; break }
    }
    $prefix = @($copy | Select-Object -First $boundary)
    $prepend = @()
    foreach ($flag in @('-NoProfile','-NonInteractive')) { if ($prefix -notcontains $flag) { $prepend += $flag } }
    $windowIndex = -1
    for ($index = 0; $index -lt $prefix.Count; $index++) { if ($prefix[$index] -ieq '-WindowStyle') { $windowIndex = $index; break } }
    if ($windowIndex -ge 0) {
        if ($windowIndex + 1 -ge $boundary) { throw 'PowerShell -WindowStyle requires a value.' }
        $copy[$windowIndex + 1] = 'Hidden'
    }
    else { $prepend += @('-WindowStyle','Hidden') }
    return ,@($prepend + $copy)
}
