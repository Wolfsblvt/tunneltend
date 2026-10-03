Set-StrictMode -Version Latest

function Assert-TtWindowsAutomationAvailable {
    [CmdletBinding()]
    param()
    if (-not $IsWindows) { throw 'Windows Scheduled Task automation is available only on Windows.' }
    if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) { throw 'The Windows ScheduledTasks module is unavailable.' }
}

function Get-TtCliScriptPath {
    [CmdletBinding()]
    param()
    if ($env:TUNNELTEND_CLI_PATH -and [IO.File]::Exists($env:TUNNELTEND_CLI_PATH)) { return [IO.Path]::GetFullPath($env:TUNNELTEND_CLI_PATH) }
    $candidate = [IO.Path]::GetFullPath([IO.Path]::Combine($script:TtModuleRoot, '..', '..', 'tunneltend.ps1'))
    if ([IO.File]::Exists($candidate)) { return $candidate }
    throw "Unable to locate tunneltend.ps1 relative to module '$script:TtModuleRoot'."
}

function Get-TtAutomationTaskDefinitions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    $automation = $Registry.settings.automation
    $state = Resolve-TtStateRoot $StateRoot
    return @(
        [ordered]@{ name='Startup'; enabled=[bool]($automation.autostart -or $automation.watchdog); mode='startup'; type='logon'; delaySeconds=[int]$automation.startupDelaySeconds },
        [ordered]@{ name='Maintenance'; enabled=[bool]$automation.autoUpdate; mode='maintenance'; type='daily'; hour=[int]$automation.maintenanceHour; minute=[int]$automation.maintenanceMinute; randomDelayMinutes=[int]$automation.maintenanceRandomDelayMinutes },
        [ordered]@{ name='Watchdog'; enabled=[bool]$automation.watchdog; mode='watchdog'; type='watchdog'; intervalMinutes=[int]$automation.watchdogIntervalMinutes; delaySeconds=[int]$automation.startupDelaySeconds }
    )
}

function New-TtScheduledTaskAction {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Mode, [string]$StateRoot)
    $pwsh = (Get-Process -Id $PID).Path
    $cli = Get-TtCliScriptPath
    $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-File',$cli,'automation',$Mode,'--state-root',(Resolve-TtStateRoot $StateRoot),'--json')
    return New-ScheduledTaskAction -Execute $pwsh -Argument (ConvertTo-TtCommandLine $arguments) -WorkingDirectory ([IO.Path]::GetDirectoryName($cli))
}

function New-TtScheduledTaskTriggers {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Definition)
    switch ($Definition.type) {
        'logon' {
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
            $trigger.Delay = "PT$([int]$Definition.delaySeconds)S"
            return @($trigger)
        }
        'daily' {
            $at = [DateTime]::Today.AddHours([int]$Definition.hour).AddMinutes([int]$Definition.minute)
            $trigger = New-ScheduledTaskTrigger -Daily -At $at
            if ([int]$Definition.randomDelayMinutes -gt 0) { $trigger.RandomDelay = "PT$([int]$Definition.randomDelayMinutes)M" }
            return @($trigger)
        }
        'watchdog' {
            $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
            $logon.Delay = "PT$([int]$Definition.delaySeconds)S"
            $logon.Repetition.Interval = "PT$([int]$Definition.intervalMinutes)M"
            $logon.Repetition.Duration = 'P1D'
            $daily = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Today)
            $daily.Repetition.Interval = "PT$([int]$Definition.intervalMinutes)M"
            $daily.Repetition.Duration = 'P1D'
            return @($logon,$daily)
        }
    }
}

function Install-TtAutomationInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    Assert-TtWindowsAutomationAvailable
    $taskPath = '\TunnelTend\'
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 2)
    $results = @()
    foreach ($definition in Get-TtAutomationTaskDefinitions $Registry $StateRoot) {
        $fullName = "TunnelTend $($definition.name)"
        if (-not $definition.enabled) {
            Unregister-ScheduledTask -TaskName $fullName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
            $results += [ordered]@{ name=$fullName; installed=$false; reason='disabled-by-configuration' }
            continue
        }
        $action = New-TtScheduledTaskAction $definition.mode $StateRoot
        $triggers = New-TtScheduledTaskTriggers $definition
        $task = New-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description "TunnelTend $($definition.mode) automation. Managed by tunneltend; edit through the CLI rather than Task Scheduler."
        Register-ScheduledTask -TaskName $fullName -TaskPath $taskPath -InputObject $task -Force | Out-Null
        $results += [ordered]@{ name=$fullName; installed=$true; mode=$definition.mode }
    }
    return $results
}

function Uninstall-TtAutomationInternal {
    [CmdletBinding()]
    param()
    Assert-TtWindowsAutomationAvailable
    $results = @()
    foreach ($name in @('TunnelTend Startup','TunnelTend Maintenance','TunnelTend Watchdog')) {
        $existing = Get-ScheduledTask -TaskName $name -TaskPath '\TunnelTend\' -ErrorAction SilentlyContinue
        if ($existing) { Unregister-ScheduledTask -TaskName $name -TaskPath '\TunnelTend\' -Confirm:$false; $results += [ordered]@{ name=$name; removed=$true } }
        else { $results += [ordered]@{ name=$name; removed=$false } }
    }
    return $results
}

function Get-TtAutomationStatusInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Registry, [string]$StateRoot)
    if (-not $IsWindows -or -not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        return [ordered]@{ supported=$false; tasks=@(); desired=(Get-TtAutomationTaskDefinitions $Registry $StateRoot) }
    }
    $tasks = @()
    foreach ($definition in Get-TtAutomationTaskDefinitions $Registry $StateRoot) {
        $name = "TunnelTend $($definition.name)"
        $task = Get-ScheduledTask -TaskName $name -TaskPath '\TunnelTend\' -ErrorAction SilentlyContinue
        $info = if ($task) { Get-ScheduledTaskInfo -TaskName $name -TaskPath '\TunnelTend\' -ErrorAction SilentlyContinue } else { $null }
        $tasks += [ordered]@{
            name=$name
            desired=[bool]$definition.enabled
            installed=$null -ne $task
            state=$(if ($task) { [string]$task.State } else { 'Missing' })
            lastRunTime=$(if ($info) { $info.LastRunTime.ToString('o') } else { $null })
            lastTaskResult=$(if ($info) { $info.LastTaskResult } else { $null })
            nextRunTime=$(if ($info) { $info.NextRunTime.ToString('o') } else { $null })
        }
    }
    return [ordered]@{ supported=$true; tasks=$tasks; desired=(Get-TtAutomationTaskDefinitions $Registry $StateRoot) }
}
