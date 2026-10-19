BeforeAll {
    $workflow = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../.github/workflows/upstream-compatibility.yml')
    $step = [regex]::Match($workflow, '(?ms)      - name: Preserve changed snapshot.*?        run: \|\r?\n(?<body>.*?)(?=      - uses:)')
    if (-not $step.Success) { throw 'Cannot find the upstream snapshot comparison step.' }
    $script:Comparison = [scriptblock]::Create(($step.Groups['body'].Value -replace '(?m)^          ', ''))

    function New-SnapshotRepository([string]$Name) {
        $directory = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path (Join-Path $directory 'docs/research') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $directory 'docs/research/openai-tunnel-client-release.json') -Value '{"tag":"v1"}'
        git -C $directory -c init.defaultBranch=main init --quiet
        git -C $directory add -- .
        git -C $directory -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m fixture
        if ($LASTEXITCODE -ne 0) { throw 'Could not prepare the snapshot fixture.' }
        return $directory
    }

    function Invoke-SnapshotComparison([string]$Directory) {
        $previousOutput = $env:GITHUB_OUTPUT
        $output = Join-Path $Directory 'step-output.txt'
        Push-Location $Directory
        try {
            $env:GITHUB_OUTPUT = $output
            & $script:Comparison
            return Get-Content -Raw -LiteralPath $output
        }
        finally {
            Pop-Location
            $env:GITHUB_OUTPUT = $previousOutput
        }
    }
}

# Release packages omit GitHub workflows; this contract belongs to the source checkout.
Describe 'Upstream watch snapshot detection' -Skip:(-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '../.github/workflows/upstream-compatibility.yml'))) {
    It 'does not report a changed release when Git exits zero without stdout' {
        $directory = New-SnapshotRepository unchanged
        Invoke-SnapshotComparison $directory | Should -Match 'changed=false'
        Test-Path -LiteralPath (Join-Path $directory 'artifacts') | Should -BeFalse
    }

    It 'preserves a real changed snapshot and reports the change' {
        $directory = New-SnapshotRepository changed
        Set-Content -LiteralPath (Join-Path $directory 'docs/research/openai-tunnel-client-release.json') -Value '{"tag":"v2"}'
        $output = @(Invoke-SnapshotComparison $directory)
        $output[-1] | Should -Match 'changed=true'
        Get-Content -Raw -LiteralPath (Join-Path $directory 'artifacts/upstream-release.diff') | Should -Match 'v2'
        Get-Content -Raw -LiteralPath (Join-Path $directory 'artifacts/openai-tunnel-client-release.json') | Should -Match 'v2'
    }

    It 'refuses a Git inspection error instead of calling it a changed release' {
        $directory = Join-Path $TestDrive 'not-a-repository'
        New-Item -ItemType Directory -Path $directory | Out-Null
        { Invoke-SnapshotComparison $directory 2>$null } | Should -Throw '*Git snapshot comparison failed*'
        Test-Path -LiteralPath (Join-Path $directory 'step-output.txt') | Should -BeFalse
    }
}
