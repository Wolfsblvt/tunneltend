[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures = [Collections.Generic.List[string]]::new()
# Generated packages, local tooling, and Git objects are not repository source.
$ownedFiles = @(Get-ChildItem -LiteralPath $root -Force | Where-Object {
    $_.Name -notin @('.git', 'artifacts', '.validation')
} | ForEach-Object {
    if ($_.PSIsContainer) { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force }
    else { $_ }
})

$required = @(
    'README.md', 'AGENTS.md', 'LICENSE', 'SECURITY.md', 'CHANGELOG.md',
    'tunneltend.ps1', 'tunneltend.cmd', 'Install-TunnelTend.cmd',
    'scripts/Install-TunnelTend.ps1', 'scripts/Uninstall-TunnelTend.ps1',
    'src/TunnelTend/TunnelTend.psd1', 'schemas/registry.schema.json',
    'schemas/service.schema.json', 'carriers/Threshold-CoDesign-Branding.md'
)
foreach ($relativePath in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath))) {
        $failures.Add("missing required file: $relativePath")
    }
}

foreach ($json in Get-ChildItem -LiteralPath (Join-Path $root 'schemas') -Filter '*.json' -File) {
    try { Get-Content $json.FullName -Raw | ConvertFrom-Json -Depth 100 | Out-Null }
    catch { $failures.Add("invalid JSON: $($json.FullName): $($_.Exception.Message)") }
}

$validationScript = [IO.Path]::GetFullPath($PSCommandPath)
$codeFiles = @($ownedFiles | Where-Object {
    [IO.Path]::GetFullPath($_.FullName) -ne $validationScript -and
    $_.Extension -in @('.ps1', '.psm1', '.psd1', '.cmd')
})
$dangerousPatterns = @(
    'Invoke-Expression',
    'Stop-Process\s+-Name',
    'taskkill(?:\.exe)?\s+/IM',
    'ExecutionPolicy\s+Bypass',
    'AllowUnverifiedAsset\s*=\s*\$true'
)
foreach ($file in $codeFiles) {
    $text = Get-Content $file.FullName -Raw
    foreach ($pattern in $dangerousPatterns) {
        if ($text -match $pattern) { $failures.Add("dangerous pattern '$pattern' in $($file.FullName)") }
    }
}

$bundledClient = @($ownedFiles | Where-Object {
    $_.Name -match '^tunnel-client(?:\.exe)?$'
})
if ($bundledClient.Count -gt 0) { $failures.Add('official tunnel-client binary must not be bundled') }

$operations = Get-Content (Join-Path $root 'src/TunnelTend/Public/20-Operations.ps1') -Raw
foreach ($functionName in @('Get-TtStatus', 'Get-TtHealth', 'Invoke-TtDoctor', 'Get-TtRepairPlan')) {
    $match = [regex]::Match($operations, "(?ms)^function\s+$functionName\b.*?(?=^function\s+|\z)")
    if (-not $match.Success) { $failures.Add("missing read-only function $functionName") }
    elseif ($match.Value -match '\bSave-Tt(?:Registry|RuntimeStore)\b') {
        $failures.Add("read-only function $functionName persists state")
    }
}

foreach ($markdown in $ownedFiles | Where-Object Extension -EQ '.md') {
    $text = Get-Content $markdown.FullName -Raw
    foreach ($match in [regex]::Matches($text, '\[[^\]]+\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Split('#')[0]
        if ($target -match '^(?:https?:|mailto:|#)' -or [string]::IsNullOrWhiteSpace($target)) { continue }
        $decoded = [Uri]::UnescapeDataString($target)
        $candidate = [IO.Path]::GetFullPath((Join-Path $markdown.DirectoryName $decoded))
        if (-not (Test-Path -LiteralPath $candidate)) {
            $failures.Add("broken relative link in $($markdown.FullName): $target")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "Repository validation passed for $($codeFiles.Count) code files."
