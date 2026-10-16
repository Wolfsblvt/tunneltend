BeforeAll {
    $path = Join-Path $PSScriptRoot '../src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1'
    $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
    $definitions = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object { $_.Extent.Text })
    $script:PolicyModule = New-Module -Name TunnelTendUpdaterPolicyTests -ArgumentList (,$definitions) -ScriptBlock {
        param($definitions)
        foreach ($definition in $definitions) { . ([scriptblock]::Create($definition)) }
        $script:Utf8NoBom = [Text.UTF8Encoding]::new($false)
        $script:RequirePublishedChecksum = [switch]$true
        $script:AllowUnverifiedAsset = [switch]$true
        $script:CheckOnly = [switch]$false
        $script:Force = [switch]$false
        $script:LogFile = $null
    }
    Import-Module $script:PolicyModule -DisableNameChecking
}

Describe 'Automatic published archive policy' {
    BeforeEach {
        $script:Config = Join-Path $TestDrive 'updater.json'
        @{installDirectory=(Join-Path $TestDrive 'install');stateDirectory=(Join-Path $TestDrive 'state');allowUnverifiedAsset=[bool]1} | ConvertTo-Json | Set-Content -LiteralPath $script:Config
        Mock Write-Log -ModuleName TunnelTendUpdaterPolicyTests {}
        Mock Get-LatestStableRelease -ModuleName TunnelTendUpdaterPolicyTests { @{tag_name='v0.0.16'} }
        Mock Select-WindowsReleaseAsset -ModuleName TunnelTendUpdaterPolicyTests { @{name='fixture.zip';size=7;browser_download_url='https://github.com/openai/tunnel-client/releases/download/v0.0.16/fixture.zip'} }
        Mock Read-StateFile -ModuleName TunnelTendUpdaterPolicyTests { $null }
        Mock Test-ManagedInstallation -ModuleName TunnelTendUpdaterPolicyTests { $false }
        Mock Assert-InstallDirectoryWritable -ModuleName TunnelTendUpdaterPolicyTests {}
        Mock Save-HttpsFile -ModuleName TunnelTendUpdaterPolicyTests { param($Destination) [IO.File]::WriteAllText($Destination, 'fixture') }
        Mock Test-PayloadCodeSignatures -ModuleName TunnelTendUpdaterPolicyTests { @{AllCodeFilesValid=$true;MainExecutableIsOpenAI=$true;Signers=@('OpenAI')} }
        Mock Expand-ZipSafely -ModuleName TunnelTendUpdaterPolicyTests { throw 'reached verified extraction' }
    }

    It 'refuses a missing published checksum before extraction despite emergency override and trusted signatures' {
        Mock Get-PublishedArchiveSha256 -ModuleName TunnelTendUpdaterPolicyTests { $null }
        { & $script:PolicyModule { param($path) $script:ConfigPath=$path; Invoke-Updater } $script:Config } | Should -Throw '*published SHA-256*'
        Should -Invoke Expand-ZipSafely -ModuleName TunnelTendUpdaterPolicyTests -Times 0 -Exactly
        Should -Invoke Test-PayloadCodeSignatures -ModuleName TunnelTendUpdaterPolicyTests -Times 0 -Exactly
    }

    It 'refuses a mismatching digest before extraction' {
        Mock Get-PublishedArchiveSha256 -ModuleName TunnelTendUpdaterPolicyTests { @{Hash=('0' * 64);Source='synthetic release digest'} }
        { & $script:PolicyModule { param($path) $script:ConfigPath=$path; Invoke-Updater } $script:Config } | Should -Throw '*SHA-256 mismatch*'
        Should -Invoke Expand-ZipSafely -ModuleName TunnelTendUpdaterPolicyTests -Times 0 -Exactly
    }

    It 'allows a matching published digest to reach guarded extraction' {
        Mock Get-PublishedArchiveSha256 -ModuleName TunnelTendUpdaterPolicyTests { param($StagingDirectory) @{Hash=(Get-FileSha256 (Join-Path $StagingDirectory 'fixture.zip'));Source='synthetic release digest'} }
        { & $script:PolicyModule { param($path) $script:ConfigPath=$path; Invoke-Updater } $script:Config } | Should -Throw '*reached verified extraction*'
        Should -Invoke Expand-ZipSafely -ModuleName TunnelTendUpdaterPolicyTests -Times 1 -Exactly
    }
}

AfterAll { Remove-Module $script:PolicyModule -Force -ErrorAction SilentlyContinue }
