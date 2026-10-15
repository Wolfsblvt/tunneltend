BeforeAll {
    $script:UpdaterPath = Join-Path $PSScriptRoot '../src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1'
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:UpdaterPath,
        [ref]$tokens,
        [ref]$parseErrors)
    if (@($parseErrors).Count -gt 0) {
        throw "Updater script did not parse: $($parseErrors[0].Message)"
    }

    function Get-UpdaterFunctionText([string]$Name) {
        $definition = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $Name
        }, $true)
        if (-not $definition) { throw "Updater function '$Name' was not found." }
        return $definition.Extent.Text
    }

    $assertText = Get-UpdaterFunctionText 'Assert-OfficialReleaseAssetUrl'
    $selectText = Get-UpdaterFunctionText 'Select-WindowsReleaseAsset'
    $expandText = Get-UpdaterFunctionText 'Expand-ZipSafely'
    $script:UpdaterFunctions = New-Module -Name TunnelTendUpdaterSelectionTests -ArgumentList $assertText, $selectText, $expandText -ScriptBlock {
        param($AssertText, $SelectText, $ExpandText)
        $script:OfficialReleasePathPrefix = '/openai/tunnel-client/releases/download/'
        . ([scriptblock]::Create($AssertText))
        . ([scriptblock]::Create($SelectText))
        . ([scriptblock]::Create($ExpandText))
    }
}

Describe 'Official ZIP attributes' {
    It 'extracts regular Unix files and still rejects symbolic links' {
        foreach ($specimen in @(@{ name = 'regular'; mode = 0x81A4; allowed = $true }, @{ name = 'symlink'; mode = 0xA1FF; allowed = $false })) {
            $zipPath = Join-Path $TestDrive ($specimen.name + '.zip')
            $destination = Join-Path $TestDrive $specimen.name
            $archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
            try {
                $entry = $archive.CreateEntry('payload.txt')
                $entry.ExternalAttributes = $specimen.mode -shl 16
                $writer = [IO.StreamWriter]::new($entry.Open())
                try { $writer.Write('verified payload') } finally { $writer.Dispose() }
            }
            finally { $archive.Dispose() }

            if ($specimen.allowed) {
                & $script:UpdaterFunctions { param($zip, $target) Expand-ZipSafely $zip $target 1024 10 } $zipPath $destination
                Get-Content -Raw -LiteralPath (Join-Path $destination 'payload.txt') | Should -Be 'verified payload'
            }
            else {
                { & $script:UpdaterFunctions { param($zip, $target) Expand-ZipSafely $zip $target 1024 10 } $zipPath $destination } | Should -Throw '*symbolic link*'
                Test-Path -LiteralPath (Join-Path $destination 'payload.txt') | Should -BeFalse
            }
        }
    }
}

AfterAll {
    Remove-Module $script:UpdaterFunctions -Force -ErrorAction SilentlyContinue
}

Describe 'Official tunnel-client release selection' {
    It 'chooses the primary client when runtime variants share the architecture' {
        $tag = 'v0.0.15'
        $base = "https://github.com/openai/tunnel-client/releases/download/$tag"
        $release = [pscustomobject]@{
            assets = @(
                [pscustomobject]@{ name = "tunnel-client-runtime-cloudflared-$tag-windows-amd64.zip"; browser_download_url = "$base/tunnel-client-runtime-cloudflared-$tag-windows-amd64.zip" }
                [pscustomobject]@{ name = "tunnel-client-runtime-$tag-windows-amd64.zip"; browser_download_url = "$base/tunnel-client-runtime-$tag-windows-amd64.zip" }
                [pscustomobject]@{ name = "tunnel-client-$tag-windows-amd64.zip"; browser_download_url = "$base/tunnel-client-$tag-windows-amd64.zip" }
            )
        }

        $selected = & $script:UpdaterFunctions {
            param($Release)
            Select-WindowsReleaseAsset -Release $Release -ExplicitAssetName ''
        } $release

        $selected.name | Should -Be 'tunnel-client-v0.0.15-windows-amd64.zip'
    }

    It 'honors an explicit official ZIP override without weakening URL checks' {
        $tag = 'v0.0.15'
        $name = "tunnel-client-runtime-$tag-windows-amd64.zip"
        $release = [pscustomobject]@{
            assets = @([pscustomobject]@{
                name = $name
                browser_download_url = "https://github.com/openai/tunnel-client/releases/download/$tag/$name"
            })
        }

        # Explicit selection remains an expert override for future naming changes,
        # but it must still be a ZIP from the official release. The integration
        # layer never emits a runtime-only asset name.
        $selected = & $script:UpdaterFunctions {
            param($Release, $Name)
            Select-WindowsReleaseAsset -Release $Release -ExplicitAssetName $Name
        } $release $name

        $selected.name | Should -Be $name
    }
}
