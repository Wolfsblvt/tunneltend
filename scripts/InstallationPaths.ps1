Set-StrictMode -Version Latest

# Shared by install and uninstall so an omitted override selects the same state.
function Resolve-TtInstallationStateRoot {
    param([string]$InstallRoot, [string]$StateRoot)
    if (-not $StateRoot) {
        $receiptPath = Join-Path $InstallRoot 'install.json'
        if ([IO.File]::Exists($receiptPath)) {
            $receipt = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json -AsHashtable
            if ($receipt.product -ne 'tunneltend' -or -not $receipt.stateRoot -or -not [IO.Path]::IsPathFullyQualified([string]$receipt.stateRoot)) {
                throw 'The installation receipt has no valid state root. Supply -StateRoot explicitly before continuing.'
            }
            $StateRoot = [string]$receipt.stateRoot
        }
        else { $StateRoot = Join-Path $env:LOCALAPPDATA 'TunnelTend/state' }
    }
    return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($StateRoot))
}

function Test-TtInstallationPathWithin {
    param([string]$Path, [string]$Root)
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar))
}

function Assert-TtInstallationRoots {
    param([string]$InstallRoot, [string]$StateRoot)
    if ([IO.Path]::GetRelativePath($InstallRoot, $StateRoot) -eq '.') {
        throw 'InstallRoot and StateRoot must differ: program replacement cannot distinguish program files from state in the same directory. Select a state subdirectory or a separate state root.'
    }
}

function Remove-TtInstallationPathEntry {
    param([string]$InstallRoot)
    $userPath=[Environment]::GetEnvironmentVariable('Path','User')
    $parts=@($userPath -split ';' | Where-Object { $_ -and -not [string]::Equals([IO.Path]::GetFullPath($_),$InstallRoot,[StringComparison]::OrdinalIgnoreCase) })
    [Environment]::SetEnvironmentVariable('Path',($parts -join ';'),'User')
}

function Remove-TtInstallationFiles {
    param([string]$InstallRoot, [string]$StateRoot)
    if (-not [IO.Directory]::Exists($InstallRoot)) { return }
    if (-not (Test-TtInstallationPathWithin $StateRoot $InstallRoot)) {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
        return
    }
    # The dedicated state container is not program payload. Preserve it whole,
    # including sibling state and junction targets; never walk through its links.
    foreach ($item in Get-ChildItem -LiteralPath $InstallRoot -Force) {
        if (Test-TtInstallationPathWithin $StateRoot $item.FullName) { continue }
        Remove-Item -LiteralPath $item.FullName -Recurse -Force
    }
}
