BeforeAll {
    $script:Runner = Join-Path $PSScriptRoot '../scripts/Invoke-Tests.ps1'
}

Describe 'Repository verification failure propagation' {
    It 'rejects an invalid package version before creating or deleting output' {
        $root = Join-Path $TestDrive 'invalid-build'
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
        $builder = Join-Path $root 'scripts/Build-Release.ps1'
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../scripts/Build-Release.ps1') -Destination $builder
        { & $builder -Version 'invalid' -SkipTests } | Should -Throw '*not semantic versioning*'
        Test-Path -LiteralPath (Join-Path $root 'artifacts') | Should -BeFalse
    }

    It 'validates source and its extracted package without including local tooling' {
        $root = Join-Path $TestDrive 'source-with-artifacts'
        New-Item -ItemType Directory -Path $root | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Force | Where-Object {
            $_.Name -notin @('.git', 'artifacts', '.validation')
        } | Copy-Item -Destination $root -Recurse -Force
        $artifacts = Join-Path $root 'artifacts'
        New-Item -ItemType Directory -Path $artifacts | Out-Null
        Set-Content -LiteralPath (Join-Path $artifacts 'README.md') -Value '[tooling link](not-shipped.md)'
        Set-Content -LiteralPath (Join-Path $artifacts 'tunnel-client.exe') -Value 'synthetic downloaded artifact'

        & (Join-Path $root 'scripts/Invoke-RepositoryValidation.ps1')
        $? | Should -BeTrue

        & (Join-Path $root 'scripts/Build-Release.ps1') -Version '0.1.0-test' -SkipTests
        $package = Join-Path $TestDrive 'extracted-package'
        Expand-Archive -LiteralPath (Join-Path $artifacts 'tunneltend-0.1.0-test.zip') -DestinationPath $package
        Test-Path -LiteralPath (Join-Path $package 'tests/Fixtures/mcp-stdio-echo.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $package 'artifacts/tunnel-client.exe') | Should -BeFalse
        & (Join-Path $package 'scripts/Invoke-RepositoryValidation.ps1')
        $? | Should -BeTrue
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $artifacts 'tunneltend-0.1.0-test.manifest.json') | ConvertFrom-Json
        @($manifest.files | Where-Object { $_.Contains('\') }).Count | Should -Be 0
    }

    It 'refuses success when the dependency-free suite exits nonzero' {
        $root = Join-Path $TestDrive 'repository'
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts'), (Join-Path $root 'tests') -Force | Out-Null
        Copy-Item -LiteralPath $script:Runner -Destination (Join-Path $root 'scripts/Invoke-Tests.ps1')
        Set-Content -LiteralPath (Join-Path $root 'tests/ZeroDependency.ps1') -Value 'exit 1'

        $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        foreach ($argument in @('-NoProfile', '-NonInteractive', '-File', (Join-Path $root 'scripts/Invoke-Tests.ps1'))) {
            $start.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::Start($start)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Verification specimen timed out.' }
            $process.ExitCode | Should -Not -Be 0
            $stderr.GetAwaiter().GetResult() | Should -Match 'dependency-free behavior suite failed'
            $stdout.GetAwaiter().GetResult() | Should -Not -Match 'All available tests passed'
        }
        finally { $process.Dispose() }
    }
}
