param([string]$Mode, [string]$Root, [string]$ModulePath, [string]$PowerShellPath)
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'host') {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
    while (-not [IO.File]::Exists((Join-Path $Root 'release-host.txt')) -and [DateTimeOffset]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (-not [IO.File]::Exists((Join-Path $Root 'release-host.txt'))) { throw 'Fixture host was never released.' }
    [IO.File]::WriteAllText((Join-Path $Root 'host-finished.txt'), 'survived')
    exit 0
}
if ($Mode -in @('detach-exit','detach-wait')) {
    try {
    Import-Module $ModulePath -Force
    & (Get-Module TunnelTend) {
        param($file,$root,$powerShell)
        $record = Start-TtDetachedProcess -FilePath $powerShell -ArgumentList @('-File',$file,'host',$root)
        Write-TtJsonAtomic (Join-Path $root 'host.json') $record
        Write-TtJsonAtomic (Join-Path $root 'script.json') (Get-TtProcessInfo $PID)
    } $PSCommandPath $Root $PowerShellPath
    }
    catch { [IO.File]::WriteAllText((Join-Path $Root 'error.txt'), $_.ToString()); throw }
    if ($Mode -eq 'detach-wait') { Start-Sleep -Seconds 15 }
    exit 23
}
Add-Type -Namespace QuietFixture -Name ConsoleState -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();'
@{console=[QuietFixture.ConsoleState]::GetConsoleWindow().ToInt64();arguments=@($args)} | ConvertTo-Json -Compress | Write-Output
[Console]::Error.WriteLine('fixture-error')
exit 23
