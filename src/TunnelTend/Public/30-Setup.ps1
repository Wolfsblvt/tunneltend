Set-StrictMode -Version Latest

function Read-TtSetupBoolean {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt, [bool]$Default)
    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer -match '^(?i)y(?:es)?$'
}

function Invoke-TtSetup {
    [CmdletBinding()]
    param(
        [Nullable[bool]]$Autostart,
        [Nullable[bool]]$AutoUpdate,
        [Nullable[bool]]$Watchdog,
        [string[]]$OrganizationId,
        [string[]]$WorkspaceId,
        [string]$RuntimeKeyRef,
        [switch]$ImportAll,
        [string[]]$ImportAlias,
        [switch]$NonInteractive,
        [switch]$SkipAutomationInstall,
        [string]$StateRoot
    )
    $settings = Get-TtConfiguration $StateRoot
    if (-not $NonInteractive) {
        if ($null -eq $Autostart) { $Autostart = Read-TtSetupBoolean 'Start registered services at Windows logon?' ([bool]$settings.automation.autostart) }
        if ($null -eq $AutoUpdate) { $AutoUpdate = Read-TtSetupBoolean 'Check verified stable official-client updates automatically?' ([bool]$settings.automation.autoUpdate) }
        if ($null -eq $Watchdog) { $Watchdog = Read-TtSetupBoolean 'Recover unhealthy registered services automatically?' ([bool]$settings.automation.watchdog) }
        if (@($OrganizationId).Count -eq 0 -and @($WorkspaceId).Count -eq 0) {
            $scope = Read-Host 'Default organization id for newly registered services (blank to leave unset)'
            if (-not [string]::IsNullOrWhiteSpace($scope)) { $OrganizationId = @($scope.Trim()) }
        }
        if (-not $RuntimeKeyRef) {
            $answer = Read-Host "Runtime key reference [env:CONTROL_PLANE_API_KEY]"
            $RuntimeKeyRef = if ([string]::IsNullOrWhiteSpace($answer)) { 'env:CONTROL_PLANE_API_KEY' } else { $answer.Trim() }
        }
    }
    if ($null -eq $Autostart) { $Autostart = [bool]$settings.automation.autostart }
    if ($null -eq $AutoUpdate) { $AutoUpdate = [bool]$settings.automation.autoUpdate }
    if ($null -eq $Watchdog) { $Watchdog = [bool]$settings.automation.watchdog }
    if (-not $RuntimeKeyRef) { $RuntimeKeyRef = [string]$settings.defaults.runtimeKeyRef }
    if (-not (Test-TtSecretReference $RuntimeKeyRef)) { throw 'RuntimeKeyRef must use env:NAME or file:/path.' }

    Set-TtConfiguration 'settings.automation.autostart' ([bool]$Autostart) $StateRoot | Out-Null
    Set-TtConfiguration 'settings.automation.autoUpdate' ([bool]$AutoUpdate) $StateRoot | Out-Null
    Set-TtConfiguration 'settings.automation.watchdog' ([bool]$Watchdog) $StateRoot | Out-Null
    if (@($OrganizationId).Count -gt 0) { Set-TtConfiguration 'settings.defaults.organizationIds' @($OrganizationId) $StateRoot | Out-Null }
    if (@($WorkspaceId).Count -gt 0) { Set-TtConfiguration 'settings.defaults.workspaceIds' @($WorkspaceId) $StateRoot | Out-Null }
    Set-TtConfiguration 'settings.defaults.runtimeKeyRef' $RuntimeKeyRef $StateRoot | Out-Null

    $imports = @()
    if ($ImportAll -or @($ImportAlias).Count -gt 0) {
        $imports = @(Import-TtOfficialRuntime -Alias $(if ($ImportAll) { @() } else { @($ImportAlias) }) -StateRoot $StateRoot)
    }
    $automation = if ($SkipAutomationInstall) { $null } elseif ($IsWindows) { Install-TtAutomation $StateRoot } else { Get-TtAutomationStatus $StateRoot }
    return [ordered]@{
        configured = $true
        settings = Get-TtConfiguration $StateRoot
        imports = $imports
        automation = $automation
        doctor = Invoke-TtDoctor -StateRoot $StateRoot
    }
}
