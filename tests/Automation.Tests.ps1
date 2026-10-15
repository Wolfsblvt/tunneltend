BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'Windows watchdog triggers' {
    It 'reports event-triggered tasks with no next scheduled run time' -Skip:(-not $IsWindows) {
        Mock Get-ScheduledTask -ModuleName TunnelTend { [pscustomobject]@{ State = 'Ready' } }
        Mock Get-ScheduledTaskInfo -ModuleName TunnelTend { [pscustomobject]@{ LastRunTime = $null; NextRunTime = $null; LastTaskResult = 267011 } }
        $status = & $script:Module { param($root) Get-TtAutomationStatusInternal (New-TtDefaultRegistry) $root } $TestDrive
        $status.tasks.Count | Should -Be 3
        foreach ($task in $status.tasks) {
            $task.installed | Should -BeTrue
            $task.lastRunTime | Should -BeNullOrEmpty
            $task.nextRunTime | Should -BeNullOrEmpty
        }
    }

    It 'removes earlier registrations when a later task fails to register' -Skip:(-not $IsWindows) {
        Mock Get-ScheduledTask -ModuleName TunnelTend { $null }
        Mock Register-ScheduledTask -ModuleName TunnelTend {
            if ($TaskName -eq 'TunnelTend Watchdog') { throw 'synthetic task registration failure' }
        }
        Mock Unregister-ScheduledTask -ModuleName TunnelTend {}

        { & $script:Module { param($root) Install-TtAutomationInternal (New-TtDefaultRegistry) $root } $TestDrive } | Should -Throw '*synthetic task registration failure*'

        Should -Invoke Unregister-ScheduledTask -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $TaskName -eq 'TunnelTend Startup' }
        Should -Invoke Unregister-ScheduledTask -ModuleName TunnelTend -Exactly 1 -ParameterFilter { $TaskName -eq 'TunnelTend Maintenance' }
        Should -Invoke Unregister-ScheduledTask -ModuleName TunnelTend -Exactly 0 -ParameterFilter { $TaskName -eq 'TunnelTend Watchdog' }
    }

    It 'creates repeating logon and daily triggers without registering tasks' -Skip:(-not $IsWindows) {
        $triggers = @(& $script:Module {
            New-TtScheduledTaskTriggers @{ type = 'watchdog'; delaySeconds = 20; intervalMinutes = 2 }
        })
        $triggers.Count | Should -Be 2
        foreach ($trigger in $triggers) {
            [Xml.XmlConvert]::ToTimeSpan($trigger.Repetition.Interval).TotalMinutes | Should -Be 2
            [Xml.XmlConvert]::ToTimeSpan($trigger.Repetition.Duration).TotalDays | Should -Be 1
        }
        $triggers[0].CimClass.CimClassName | Should -Be 'MSFT_TaskLogonTrigger'
        $triggers[1].CimClass.CimClassName | Should -Be 'MSFT_TaskDailyTrigger'
    }
}
