[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$NewDisplayName,[Parameter(Mandatory)][string]$NewCommandName,[switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$replacements = @(
    [pscustomobject]@{ Old = 'TUNNELTEND'; New = ($NewCommandName.ToUpperInvariant() -replace '[^A-Z0-9]', '_') }
    [pscustomobject]@{ Old = 'TunnelTend'; New = $NewDisplayName }
    [pscustomobject]@{ Old = 'tunneltend'; New = $NewCommandName }
)
$files=@(Get-ChildItem $root -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](?:\.git|artifacts)[\\/]' -and $_.Extension -in @('.ps1','.psm1','.psd1','.md','.json','.yml','.yaml','.cmd','.txt') })
$changes=@()
foreach ($file in $files) {
    $text=Get-Content $file.FullName -Raw; $updated=$text
    foreach ($replacement in $replacements) { $updated = $updated.Replace([string]$replacement.Old, [string]$replacement.New) }
    if ($updated -ne $text) { $changes += [IO.Path]::GetRelativePath($root,$file.FullName); if ($Apply -and $PSCmdlet.ShouldProcess($file.FullName,'Apply product rename')) { Set-Content $file.FullName $updated -Encoding utf8NoBOM } }
}
[ordered]@{apply=[bool]$Apply;files=$changes;warning='Review task names, state migration, repository slug, module paths, release assets, and compatibility aliases before committing.'} | ConvertTo-Json -Depth 10
