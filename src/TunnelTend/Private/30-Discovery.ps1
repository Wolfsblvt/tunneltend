Set-StrictMode -Version Latest

function Get-TtDescriptorPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProjectPath)
    foreach ($name in @('tunneltend.service.json','.tunneltend.json')) {
        $candidate = [IO.Path]::Combine($ProjectPath, $name)
        if ([IO.File]::Exists($candidate)) { return $candidate }
    }
    return $null
}

function Read-TtServiceDescriptor {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($full)) { throw "Descriptor '$full' does not exist." }
    $descriptor = ([IO.File]::ReadAllText($full, [Text.Encoding]::UTF8) | ConvertFrom-Json -AsHashtable -Depth 100)
    if (-not $descriptor) { throw "Descriptor '$full' is empty." }
    Assert-TtNoInlineSecrets $descriptor "descriptor"
    return $descriptor
}

function New-TtDiscoveryCandidate {
    [CmdletBinding()]
    param([string]$Kind, [string]$Reason, [string]$File, [string[]]$Arguments, [string]$WorkingDirectory, [int]$Confidence = 50)
    return [ordered]@{
        kind = $Kind
        reason = $Reason
        confidence = $Confidence
        mcp = [ordered]@{
            kind = 'command'
            command = [ordered]@{ file=$File; arguments=@($Arguments); workingDirectory=$WorkingDirectory; environment=[ordered]@{} }
        }
    }
}

function Find-TtProjectCandidates {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProjectPath)
    $path = [IO.Path]::GetFullPath($ProjectPath)
    if (-not [IO.Directory]::Exists($path)) { throw "Project directory '$path' does not exist." }
    $candidates = @()
    $descriptorPath = Get-TtDescriptorPath $path
    if ($descriptorPath) {
        $descriptor = Read-TtServiceDescriptor $descriptorPath
        $candidates += [ordered]@{ kind='descriptor'; reason=[IO.Path]::GetFileName($descriptorPath); confidence=100; descriptor=$descriptor }
        return $candidates
    }
    $packagePath = [IO.Path]::Combine($path, 'package.json')
    if ([IO.File]::Exists($packagePath)) {
        try {
            $package = ([IO.File]::ReadAllText($packagePath) | ConvertFrom-Json -AsHashtable -Depth 40)
            foreach ($scriptName in @('mcp','start:mcp','dev:mcp','serve:mcp')) {
                if ($package.scripts -and $package.scripts.Contains($scriptName)) {
                    $npm = if ($IsWindows) { 'npm.cmd' } else { 'npm' }
                    $candidates += New-TtDiscoveryCandidate 'node-package-script' "package.json script '$scriptName'" $npm @('run',$scriptName) $path 90
                }
            }
        }
        catch { throw "package.json in '$path' is invalid: $($_.Exception.Message)" }
    }
    $projectFiles = @(Get-ChildItem -LiteralPath $path -File -Filter '*.csproj' -ErrorAction SilentlyContinue)
    foreach ($project in $projectFiles) {
        $content = [IO.File]::ReadAllText($project.FullName)
        if ($project.BaseName -match '(?i)mcp' -or $content -match '(?i)ModelContextProtocol|McpServer') {
            $candidates += New-TtDiscoveryCandidate 'dotnet-project' ".NET MCP project '$($project.Name)'" 'dotnet' @('run','--project',$project.FullName) $path 85
        }
    }
    foreach ($name in @('server.py','mcp_server.py','mcp-server.py','main.py','app.py')) {
        $candidate = [IO.Path]::Combine($path, $name)
        if ([IO.File]::Exists($candidate)) {
            $content = [IO.File]::ReadAllText($candidate)
            if ($name -match 'mcp|server' -or $content -match '(?i)fastmcp|modelcontextprotocol|mcp\.server') {
                $python = if ($IsWindows) { 'python.exe' } else { 'python3' }
                $candidates += New-TtDiscoveryCandidate 'python-script' "Python MCP entry '$name'" $python @($candidate) $path 80
            }
        }
    }
    foreach ($name in @('server.ps1','mcp.ps1','start-mcp.ps1')) {
        $candidate = [IO.Path]::Combine($path, $name)
        if ([IO.File]::Exists($candidate)) {
            $pwsh = Get-TtPowerShellExecutable
            $candidates += New-TtDiscoveryCandidate 'powershell-script' "PowerShell MCP entry '$name'" $pwsh @('-NoLogo','-NoProfile','-NonInteractive','-File',$candidate) $path 80
        }
    }
    if ($IsWindows) {
        $executables = @(Get-ChildItem -LiteralPath $path -File -Filter '*mcp*.exe' -ErrorAction SilentlyContinue)
        foreach ($executable in $executables) {
            $candidates += New-TtDiscoveryCandidate 'executable' "MCP executable '$($executable.Name)'" $executable.FullName @() $path 75
        }
    }
    return @($candidates)
}

function Resolve-TtProjectDiscovery {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProjectPath)
    $candidates = @(Find-TtProjectCandidates $ProjectPath)
    if ($candidates.Count -eq 0) {
        throw "No MCP launch candidate was discovered in '$ProjectPath'. Add tunneltend.service.json or pass --command explicitly."
    }
    if ($candidates.Count -gt 1) {
        $reasons = ($candidates | ForEach-Object { "[$($_.kind)] $($_.reason)" }) -join '; '
        throw "Discovery in '$ProjectPath' is ambiguous: $reasons. Add tunneltend.service.json or pass an explicit command."
    }
    return $candidates[0]
}

function ConvertTo-TtGlobRegex {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Pattern)
    $normalized = $Pattern.Replace('\','/')
    $prefix = ''
    if ($normalized.StartsWith('**/')) {
        $prefix = '(?:.*/)?'
        $normalized = $normalized.Substring(3)
    }
    $escaped = [Regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*','§§DOUBLESTAR§§').Replace('\*','[^/]*').Replace('\?','[^/]')
    $escaped = $escaped.Replace('§§DOUBLESTAR§§','.*')
    return '^' + $prefix + $escaped + '$'
}

function Test-TtSourcePathIncluded {
    [CmdletBinding()]
    param([string]$RelativePath, [string[]]$Includes, [string[]]$Excludes)
    $normalized = $RelativePath.Replace('\','/')
    foreach ($pattern in @($Excludes)) { if ($normalized -match (ConvertTo-TtGlobRegex $pattern)) { return $false } }
    if (@($Includes).Count -eq 0) { return $true }
    foreach ($pattern in @($Includes)) { if ($normalized -match (ConvertTo-TtGlobRegex $pattern)) { return $true } }
    return $false
}

function Get-TtSourceFingerprint {
    [CmdletBinding()]
    param([AllowNull()][hashtable]$Source)
    if (-not $Source -or -not $Source.watch -or [string]::IsNullOrWhiteSpace([string]$Source.path)) { return $null }
    $root = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$Source.path))
    if (-not [IO.Directory]::Exists($root) -and -not [IO.File]::Exists($root)) { return "missing:$root" }
    $includes = @($Source.include)
    $excludes = @($Source.exclude)
    $records = [Collections.Generic.List[string]]::new()
    if ([IO.File]::Exists($root)) {
        $item = Get-Item -LiteralPath $root
        $records.Add("$($item.Name)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)")
    }
    else {
        $items = Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $relative = [IO.Path]::GetRelativePath($root, $item.FullName).Replace('\','/')
            if (-not (Test-TtSourcePathIncluded $relative $includes $excludes)) { continue }
            $records.Add("$relative|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)")
        }
    }
    $ordered = @($records | Sort-Object)
    return Get-TtStableHash ($ordered -join "`n") 64
}
