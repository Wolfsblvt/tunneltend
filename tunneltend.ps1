[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$RemainingArguments)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot 'src/TunnelTend/TunnelTend.psd1'
if (-not (Test-Path -LiteralPath $module)) {
    [Console]::Error.WriteLine("TunnelTend module was not found at '$module'. Reinstall tunneltend.")
    exit 10
}
Import-Module $module -Force -ErrorAction Stop
exit (Invoke-TtCli -Arguments $RemainingArguments)
