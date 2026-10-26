BeforeAll {
    $script:QualificationScript = Join-Path $PSScriptRoot '../scripts/Invoke-ClientQualification.ps1'
}

Describe 'Credential-free qualification failure receipt' -Skip:(-not $IsWindows) {
    It 'preserves a bounded failed report before exiting when its tested package is unavailable' {
        $output = Join-Path $TestDrive 'report.json'
        $info = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        foreach ($argument in @('-NoProfile','-NonInteractive','-File',$script:QualificationScript,'-PackageKind','source','-SourceCommit',('a' * 40),'-OutputPath',$output)) { $info.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::Start($info)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Qualification failure receipt timed out.' }
            $process.ExitCode | Should -Not -Be 0
            $stdout.GetAwaiter().GetResult() | Should -Not -Match 'Qualification completed'
            $stderr.GetAwaiter().GetResult() | Should -Match 'qualification failed'
        }
        finally { $process.Dispose() }
        $report = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json -AsHashtable
        $report.package.sha256 | Should -BeNullOrEmpty
        $report.release | Should -BeNullOrEmpty
        foreach ($architecture in $report.architectures) {
            $architecture.distribution.outcome | Should -Be 'failed'
            @($architecture.distribution.checks | Where-Object { $_.id -eq 'package-acquisition' -and $_.outcome -eq 'failed' }).Count | Should -Be 1
            $architecture.credentialFreeCli.outcome | Should -Be 'not exercised'
            $architecture.localFleet.outcome | Should -Be 'not exercised'
            $architecture.connectedConsumer.outcome | Should -Be 'not exercised'
        }
        $report.Keys | Should -Not -Contain 'stdout'
        $report.Keys | Should -Not -Contain 'stderr'
    }
}
