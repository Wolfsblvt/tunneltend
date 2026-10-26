Describe 'Windows qualification workflow invocation' -Skip:(-not $IsWindows -or -not (Test-Path (Join-Path $PSScriptRoot '../.github/workflows/upstream-compatibility.yml'))) {
    It 'delivers separate arguments and preserves a diagnosed child failure report' {
        $repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        $root = Join-Path $TestDrive 'workflow'
        foreach ($name in @('scripts/lib','schemas','src/TunnelTend/Tools','src/TunnelTend/Private')) { New-Item -ItemType Directory (Join-Path $root $name) -Force | Out-Null }
        foreach ($name in @('scripts/Invoke-ClientQualification.ps1','scripts/lib/qualification-updater.ps1','schemas/client-qualification.schema.json','src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1','src/TunnelTend/Private/20-OfficialClient.ps1')) { Copy-Item (Join-Path $repository $name) (Join-Path $root $name) }
        $workflow = Get-Content -LiteralPath (Join-Path $repository '.github/workflows/upstream-compatibility.yml') -Raw
        $match = [regex]::Match($workflow, '(?ms)      - name: Exercise actual distribution and credential-free CLI.*?        run: \|\r?\n(?<body>.*?)(?=      - name: Validate report)')
        if (-not $match.Success) { throw 'The maintained qualification invocation is missing.' }
        $body = [scriptblock]::Create(($match.Groups['body'].Value -replace '(?m)^          ', ''))
        $saved = @{}
        foreach ($key in @('PACKAGE_KIND','SOURCE_COMMIT','RUN_ID','RUN_ATTEMPT')) { $saved[$key]=[Environment]::GetEnvironmentVariable($key) }
        Push-Location $root
        try {
            $env:PACKAGE_KIND='source'; $env:SOURCE_COMMIT='a' * 40; $env:RUN_ID='12'; $env:RUN_ATTEMPT='1'
            { & $body } | Should -Throw '*Qualification failed*'
            $report=Get-Content -LiteralPath (Join-Path $root 'artifacts/qualification/report.json') -Raw | ConvertFrom-Json -AsHashtable
            $report.source.commit | Should -Be ('a' * 40)
            $report.run.id | Should -Be '12'
            $report.package.kind | Should -Be 'source'
            $report.architectures[0].distribution.outcome | Should -Be 'failed'
        }
        finally {
            Pop-Location
            foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
        }
    }
}
