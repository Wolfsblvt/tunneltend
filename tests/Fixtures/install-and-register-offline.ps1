param([Parameter(Mandatory)][string]$InstallerPath, [Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$StateRoot, [Parameter(Mandatory)][string]$ReceiptPath)
$ErrorActionPreference = 'Stop'
# Import the actual copied module. Only host/provider effects are doubled;
# configuration, setup, persistence, descriptor registration and receipts are real.
function global:Import-Module {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Name, [switch]$Force)
    Microsoft.PowerShell.Core\Import-Module -Name $Name -Force:$Force -Global
    function global:Install-TtAutomation { @{fixture=$true} }
    function global:Get-TtAutomationStatus { @{tasks=@()} }
    function global:Invoke-TtDoctor { @{status='ok'} }
    function global:Get-TtStatus { @{} }
    function global:Import-TtOfficialRuntime { throw 'Unexpected official runtime import' }
    & (Get-Module TunnelTend) {
        function script:Invoke-TtDoctor { @{status='ok'} }
        function script:Import-TtOfficialRuntime { throw 'Unexpected official runtime import' }
    }
    if ((Get-Command Install-TtAutomation).ModuleName) { throw 'Fixture did not contain automation effects' }
}
& $InstallerPath -InstallRoot $InstallRoot -StateRoot $StateRoot -NonInteractive -SkipClientInstall -SkipPath | Out-Null
$installedModule = (Get-Module TunnelTend).Path
if (-not $installedModule.StartsWith($InstallRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'The installed module was not loaded' }
$defaults = (Get-Content -Raw -LiteralPath (Join-Path $StateRoot 'registry.json') | ConvertFrom-Json -AsHashtable).settings.defaults
Invoke-TtSetup -NonInteractive -SkipAutomationInstall -StateRoot $StateRoot | Out-Null
$project = Join-Path (Split-Path $StateRoot) 'fixture-project'
New-Item -ItemType Directory -Path $project -Force | Out-Null
@{mcp=@{kind='url';url='http://127.0.0.1:1/mcp'}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'tunneltend.service.json')
$registration = Register-TtService -Path $project -TunnelId tunnel_fixture -RuntimeKeyRef env:TUNNELTEND_UNUSED_FIXTURE -NoStart -StateRoot $StateRoot
$receipt = @{modulePath=$installedModule;defaults=$defaults;registered=$registration.service.id;organizationCount=@($registration.service.tunnel.organizationIds).Count;workspaceCount=@($registration.service.tunnel.workspaceIds).Count}
[IO.File]::WriteAllText($ReceiptPath, ($receipt | ConvertTo-Json -Depth 6))
