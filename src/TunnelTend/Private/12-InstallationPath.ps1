Set-StrictMode -Version Latest

# User PATH is persistent Windows configuration; process PATH is session-local.
# Keep endpoint writes separate from ownership and rollback of our additions.
function Get-TtInstallationPathValue {
    param([ValidateSet('User','Process')][string]$Target)
    return [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]$Target)
}

function Set-TtInstallationPathValue {
    param([ValidateSet('User','Process')][string]$Target, [AllowNull()][AllowEmptyString()][string]$Value)
    [Environment]::SetEnvironmentVariable('Path', $Value, [EnvironmentVariableTarget]$Target)
}

function Add-TtInstallationPath {
    param([string]$InstallRoot, [hashtable]$Changes)
    foreach ($target in @('User','Process')) {
        $before = Get-TtInstallationPathValue $target
        if (@($before -split ';') -contains $InstallRoot) { continue }
        $after = if ([string]::IsNullOrEmpty($before)) { $InstallRoot }
            elseif ($target -eq 'User') { "$before;$InstallRoot" }
            else { "$InstallRoot;$before" }
        # Record before the endpoint call: a write may take effect before its
        # notification or return fails. Recovery reads the actual current value.
        $Changes[$target] = @{ before=$before; after=$after }
        Set-TtInstallationPathValue $target $after
    }
}

function Undo-TtInstallationPath {
    param([string]$InstallRoot, [hashtable]$Changes)
    $errors = @()
    foreach ($target in @('Process','User')) {
        if (-not $Changes.ContainsKey($target)) { continue }
        try {
            $change = $Changes[$target]
            $current = Get-TtInstallationPathValue $target
            if ($current -ceq $change.before) { continue }
            if ($current -ceq $change.after) {
                Set-TtInstallationPathValue $target $change.before
                continue
            }
            # A later writer may have added other entries. Remove only our one
            # appended/prepended entry, preserving the rest of its current value.
            $parts = [Collections.Generic.List[string]]::new()
            foreach ($part in ($current -split ';')) { $parts.Add($part) }
            $ownedIndex = -1
            for ($index = 0; $index -lt $parts.Count; $index++) {
                if (-not [string]::Equals($parts[$index], $InstallRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }
                $ownedIndex = $index
                if ($target -eq 'Process') { break }
            }
            if ($ownedIndex -ge 0) {
                $parts.RemoveAt($ownedIndex)
                Set-TtInstallationPathValue $target ([string]::Join(';', $parts))
            }
        }
        catch { $errors += "$target PATH: $($_.Exception.Message)" }
    }
    if ($errors.Count -gt 0) { throw ($errors -join '; ') }
}
