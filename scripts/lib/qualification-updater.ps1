# Isolate tested-package functions from the harness's current-source bootstrap.
function New-QualificationUpdater {
    param([Parameter(Mandatory)][string]$Path)
    New-Module -Name TtQualificationUpdater -ArgumentList $Path -ScriptBlock {
        param($updaterPath)
        . $updaterPath -LibraryOnly
        Export-ModuleMember -Function @()
    }
}

function Get-QualificationAsset {
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSModuleInfo]$Updater,
        [Parameter(Mandatory)][object]$Release,
        [Parameter(Mandatory)][ValidateSet('X64','Arm64')][string]$Architecture
    )
    & $Updater {
        param($release,$architecture)
        if ((Get-Command Select-WindowsReleaseAsset).Parameters.ContainsKey('Architecture')) {
            return Select-WindowsReleaseAsset -Release $release -ExplicitAssetName '' -Architecture $architecture
        }
        if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -eq $architecture) {
            return Select-WindowsReleaseAsset -Release $release -ExplicitAssetName ''
        }
        # No result means this package cannot select the requested foreign architecture.
    } $Release $Architecture
}
