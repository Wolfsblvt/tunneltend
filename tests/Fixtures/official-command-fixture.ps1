# Synthetic official-client boundary: re-exec with inherited working directory,
# then run a project-relative MCP command. No network or credential is used.
param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string]$EncodedArguments)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../src/TunnelTend/TunnelTend.psd1') -Force
$commandArguments = @([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedArguments)) | ConvertFrom-Json)
$record = & (Get-Module TunnelTend) {
    param($command, $arguments)
    Start-TtDetachedProcess -FilePath $command -ArgumentList $arguments
} $Command $commandArguments
@{pid=$record.pid;detached=$true} | ConvertTo-Json -Compress
