[CmdletBinding()]
param([switch]$RequirePester,[switch]$RequireAnalyzer)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$errors=@()
$files=@(Get-ChildItem -LiteralPath $root -Force | Where-Object {
    $_.Name -notin @('.git','artifacts','.validation','website')
} | ForEach-Object {
    if ($_.PSIsContainer) { Get-ChildItem -LiteralPath $_.FullName -Recurse -File }
    else { $_ }
} | Where-Object { $_.Extension -in @('.ps1','.psm1','.psd1') })
foreach ($file in $files) {
    $tokens=$null;$parseErrors=$null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors) | Out-Null
    foreach ($parseError in @($parseErrors)) { $errors += "$($file.FullName):$($parseError.Extent.StartLineNumber): $($parseError.Message)" }
}
if ($errors.Count -gt 0) { throw ('PowerShell parser failed: ' + ($errors -join [Environment]::NewLine)) }
Write-Host "PowerShell parser: $($files.Count) files passed"
& (Join-Path $root 'tests/ZeroDependency.ps1') -RepositoryRoot $root
if (-not $?) { throw 'The dependency-free behavior suite failed.' }
$pester=Get-Module Pester -ListAvailable | Where-Object Version -GE ([version]'6.0.0') | Sort-Object Version -Descending | Select-Object -First 1
if ($pester) {
    Import-Module $pester.Path -Force
    $configuration=[PesterConfiguration]::Default
    $configuration.Run.Path=Join-Path $root 'tests'
    $configuration.Run.PassThru=$true
    $configuration.Run.Exit=$false
    $configuration.TestResult.Enabled=$true
    $configuration.TestResult.OutputPath=Join-Path $root 'artifacts/test-results.xml'
    New-Item -ItemType Directory (Join-Path $root 'artifacts') -Force | Out-Null
    $result=Invoke-Pester -Configuration $configuration
    if ($result.FailedCount -gt 0) { throw "Pester failed: $($result.FailedCount) test(s)." }
} elseif ($RequirePester) { throw 'Pester 6.x is required but not installed.' } else { Write-Warning 'Pester 6.x is not installed; portable tests still ran.' }
$analyzer=Get-Module PSScriptAnalyzer -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($analyzer) {
    Import-Module $analyzer.Path -Force
    $findings=Invoke-ScriptAnalyzer -Path (Join-Path $root 'src') -Recurse -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1')
    $blocking=@($findings | Where-Object Severity -in @('Error','Warning'))
    $findings | Format-Table -AutoSize | Out-String | Write-Host
    if ($blocking.Count -gt 0) { throw "Script analysis failed: $($blocking.Count) blocking finding(s)." }
} elseif ($RequireAnalyzer) { throw 'PSScriptAnalyzer is required but not installed.' } else { Write-Warning 'PSScriptAnalyzer not installed.' }
Write-Host 'All available tests passed.'
