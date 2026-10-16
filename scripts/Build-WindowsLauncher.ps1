[CmdletBinding()]
param([string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'The native quiet task launcher targets Windows.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputPath) { $OutputPath = Join-Path $root 'artifacts/native/TunnelTend.TaskHost.exe' }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$source = Join-Path $root 'src/TunnelTend/Native/HiddenTaskLauncher.cs'
$compiler = @('Framework64','Framework') | ForEach-Object { Join-Path $env:WINDIR "Microsoft.NET/$_/v4.0.30319/csc.exe" } | Where-Object { [IO.File]::Exists($_) } | Select-Object -First 1
if (-not $compiler) { throw 'The Windows .NET Framework C# compiler is unavailable; the quiet task launcher cannot be built.' }
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath)) | Out-Null
$temporary = "$OutputPath.$([Guid]::NewGuid().ToString('N')).exe"
$process = [Diagnostics.Process]::new()
$process.StartInfo = [Diagnostics.ProcessStartInfo]::new($compiler)
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.CreateNoWindow = $true
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.RedirectStandardError = $true
foreach ($argument in @('/nologo','/target:winexe','/optimize+',('/out:' + $temporary),$source)) { [void]$process.StartInfo.ArgumentList.Add($argument) }
try {
    if (-not $process.Start()) { throw 'Could not start the native launcher compiler.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Native launcher compilation failed: $($stdout.GetAwaiter().GetResult()) $($stderr.GetAwaiter().GetResult())" }
    [IO.File]::Move($temporary, $OutputPath, $true)
}
finally { $process.Dispose(); if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
return $OutputPath
