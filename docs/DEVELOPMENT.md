# Development

## Meaning

This guide is the complete local development and verification contract for TunnelTend. It names prerequisites, the canonical root gate, focused commands, generated artifacts, platform-specific limits, and safe development paths. It does not claim Windows behavior from portable evidence.

## Prerequisites

- PowerShell 7.4 or later.
- Git.
- Node 24 for the dependency-free qualification-report contract tests and validator.
- Pester 6.2.0.
- PSScriptAnalyzer 1.25.0.
- Windows 11 for Scheduled Task, logon, process-identity, sleep/resume, and live executable-replacement qualification.
- Windows' .NET Framework runtime/compiler for the small C# GUI task launcher. Windows package builds compile and include it; no SDK or NuGet dependencies are added. Source-checkout automation builds a source-addressed helper under its selected runtime work directory.

Install the pinned test tools for the current user:

```powershell
Install-Module Pester -RequiredVersion 6.2.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser -Force
```

## Canonical root verification

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-Tests.ps1 `
  -RequirePester `
  -RequireAnalyzer
```

This command:

1. parses every owned PowerShell source file;
2. runs the dependency-free behavior suite;
3. runs every `tests/*.Tests.ps1` container through Pester 6; and
4. runs PSScriptAnalyzer using `PSScriptAnalyzerSettings.psd1`.

Zero tests, missing required tools, parser failures, Pester failures, and analyzer warnings/errors are nonzero results when their gate is required.

Required failures throw from the runner, so a later successful script cannot mask them in a caller. CI also runs source verification and repository validation as separate steps. Quiet-launcher tests exercise actual Windows streams/exit, no-console creation and cancellation with detached-host survival; Task Scheduler registration itself remains a separate live qualification.

The report's Node contract suite runs separately in the qualification workflow:

```powershell
node --test tests/client-qualification.test.mjs
```

## Official-client qualification

Run the harness in a dedicated profile-free process: it clears inherited credentials and replaces profile/state directories before executing downloaded binaries. It never installs tasks, changes PATH, uses the live fleet or bundles the official client. The default acquires and verifies the currently supported public TunnelTend package as well as the latest stable official client:

```powershell
pwsh -NoProfile -NonInteractive -File ./scripts/Invoke-ClientQualification.ps1 -SourceCommit <actual-harness-commit>
node scripts/lib/client-qualification.mjs artifacts/qualification/report.json
```

For a source candidate, build its package first, then supply `-PackageKind source -PackagePath <actual-zip> -PackageVersion <built-version>`. `-ReleaseTag v0.0.17` can select an existing stable official artifact for a bounded transition specimen; it does not add a runtime version gate. Hosted callers additionally provide `-RunId` and `-RunAttempt`. Local run id `0` is local evidence, not hosted workflow provenance. The file is written on a diagnosed qualification failure as well as success; nonzero exit and fixed check outcomes retain the exact distinction. [Compatibility](upstream-compatibility.md) explains the four boundaries, package identities and producer/consumer responsibilities.

## Repository contract validation

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-RepositoryValidation.ps1
```

This checks required entry points, JSON syntax, broken relative Markdown links, prohibited broad process termination, unverified-update defaults, bundled official binaries, and obvious persistence inside read-only operations.

## Website

The product website lives under `website/` (Astro + Starlight, Node 24). It is a separate Node project with its own lock file and is excluded from the PowerShell gates and the installer payload.

```powershell
Set-Location .\website
npm ci
npm test
```

`npm test` validates the brand bundles, runs Astro diagnostics, builds `website/artifacts/site/` and checks the emitted identity. `npm run dev` serves a local preview; `npm run brand:export` regenerates `brand/bundle/tunneltend/` from its masters and `npm run brand:check` validates it. See [the website README](https://github.com/Wolfsblvt/tunneltend/blob/main/website/README.md) and the [integration note](documentation-site.md).

## Focused iteration

Portable fallback tests:

```powershell
pwsh -NoProfile -NonInteractive -File .\tests\ZeroDependency.ps1
```

Pester only:

```powershell
$config = [PesterConfiguration]::Default
$config.Run.Path = '.\tests'
$config.Run.Exit = $true
Invoke-Pester -Configuration $config
```

Module import and help:

```powershell
Import-Module .\src\TunnelTend\TunnelTend.psd1 -Force
Get-TtCliHelp
pwsh -NoProfile -NonInteractive -File .\tunneltend.ps1 --help
```

Read-only smoke state:

```powershell
$state = Join-Path $env:TEMP ('tunneltend-smoke-' + [guid]::NewGuid().ToString('N'))
pwsh -NoProfile -NonInteractive -File .\tunneltend.ps1 status --json --state-root $state
pwsh -NoProfile -NonInteractive -File .\tunneltend.ps1 health --json --state-root $state
pwsh -NoProfile -NonInteractive -File .\tunneltend.ps1 doctor --json --state-root $state
```

The three read-only commands must not create registry or runtime state.

## Build a release-layout candidate

Run the root gate and repository validation first, then:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Build-Release.ps1 `
  -Version 1.0.1 `
  -SkipTests
```

Generated files live under untracked `artifacts/`:

```text
artifacts/tunneltend-<version>.zip
artifacts/tunneltend-<version>.zip.sha256
artifacts/tunneltend-<version>.manifest.json
artifacts/tunneltend-<version>/
```

The build stamps only the staged package. It does not mutate source version files.

## Upstream compatibility

Refresh the release snapshot only when network access is intended:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Update-UpstreamSnapshot.ps1
```

Then inspect the official release, command help, JSON output, and adapter tests. A changed version number is evidence to review, not proof of incompatibility.

## Windows qualification

Run `docs/release-checklist.md` using isolated disposable current-user paths on Windows 11 before a public release and after changes to installer, automation, process ownership, updater, or service lifecycle behavior.

Portable tests prove source behavior and contract logic. They do not prove:

- Task Scheduler registration or triggers;
- logon and session transitions;
- Windows PID generation/path evidence;
- file locking during executable replacement;
- sleep/resume behavior;
- Windows user `PATH` mutation; or
- live official control-plane connectivity.

## Development hygiene

- Keep generated output under `artifacts/`.
- Keep fixtures synthetic and credential-free.
- Do not commit user state, official binaries, test credentials, logs, or machine-specific absolute paths.
- Use typed process arguments rather than interpolated shell strings.
- Add regression tests at the cheapest seam that catches repaired behavior.
- Inspect `git diff --check`, the staged diff, and the exact commit message before push.
