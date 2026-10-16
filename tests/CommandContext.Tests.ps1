BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/TunnelTend/TunnelTend.psd1') -Force
    $script:Module = Get-Module TunnelTend
}

Describe 'Registered context through detached restart' {
    It 'runs a project-relative Node entrypoint and an npm project script from another caller directory' {
        $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $npm = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $node -or -not $npm) { Set-ItResult -Skipped -Because 'Node and Windows npm are needed for this optional process qualification'; return }
        $directory = Join-Path $TestDrive 'project with spaces'
        New-Item -ItemType Directory -Path $directory | Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'server.js'), 'require("fs").writeFileSync("receipt.json", JSON.stringify({cwd:process.cwd(), marker:require("fs").readFileSync("marker.txt","utf8")}));')
        [IO.File]::WriteAllText((Join-Path $directory 'marker.txt'), 'registered project')
        @{scripts=@{mcp='node server.js'}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $directory 'package.json')
        $fixture = Join-Path $PSScriptRoot 'Fixtures/official-command-fixture.ps1'
        # Only the official-provider call is doubled. The adapter supplies its
        # registered directory, and the fixture really starts a detached child.
        Mock Invoke-TtOfficialClientJson -ModuleName TunnelTend {
            param($WorkingDirectory)
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($script:TargetArguments) -Compress)))
            $fixtureArguments = @('-NoProfile','-NonInteractive','-File',$fixture,'-Command',$script:TargetFile,'-EncodedArguments',$encoded)
            $result = & (Get-Module TunnelTend) {
                param($fixtureArguments,$directory)
                Invoke-TtProcess -FilePath (Get-Process -Id $PID).Path -ArgumentList $fixtureArguments -WorkingDirectory $directory
            } $fixtureArguments $WorkingDirectory
            $script:DetachedPid = ($result.stdout | ConvertFrom-Json).pid
            @{process=@{exit_code=0;stdout='{}';stderr=''};payload=@{}}
        }
        foreach ($target in @(@{file=$node.Source;arguments=@('server.js')}, @{file=$npm.Source;arguments=@('run','--silent','mcp')})) {
            $script:TargetFile = $target.file
            $script:TargetArguments = $target.arguments
            foreach ($attempt in 1..2) {
                $receipt = Join-Path $directory 'receipt.json'
                if (Test-Path -LiteralPath $receipt) { Remove-Item -LiteralPath $receipt }
                try {
                    & $script:Module {
                        param($directory,$file,$arguments)
                        $r = New-TtDefaultRegistry
                        $service = New-TtServiceDefinition -Id demo -TunnelId tunnel_demo -Defaults $r.settings.defaults -Mcp @{kind='command';command=@{file=$file;arguments=$arguments;workingDirectory=$directory;environment=@{}}}
                        Start-TtOfficialRuntime $service $r | Out-Null
                    } $directory $target.file $target.arguments
                    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)
                    while (-not (Test-Path -LiteralPath $receipt) -and [DateTimeOffset]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
                    Test-Path -LiteralPath $receipt | Should -BeTrue
                    $observed = Get-Content -Raw -LiteralPath $receipt | ConvertFrom-Json
                    $observed.cwd | Should -Be $directory
                    $observed.marker | Should -Be 'registered project'
                }
                finally {
                    # Own the fixture child until completion; never signal a bare PID.
                    if ($script:DetachedPid) {
                        $child = Get-Process -Id $script:DetachedPid -ErrorAction SilentlyContinue
                        if ($child) { $child.WaitForExit(15000) | Should -BeTrue }
                    }
                }
            }
        }
    }
}
