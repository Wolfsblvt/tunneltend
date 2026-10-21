# TunnelTend agent contract

## Meaning

This file is the repository-local operating contract for agents working on TunnelTend. It defines product ownership, command semantics, safety invariants, repository commands, Git posture, and completion evidence. It supplements current Leitsatz doctrine and does not replace product authority or the official tunnel-client contract.

## Mandatory first reads

Before substantive repository work:

1. Load current Leitsatz global doctrine and the selected full Identity.
2. Read this entire file.
3. Read `docs/VISION.md`, `docs/DIRECTION.md`, and the files directly governing the requested change.
4. For official-client or release work, verify the current stable `openai/tunnel-client` release and command surface from primary sources.

Do not reconstruct unavailable doctrine, authority, or product truth from memory. Name the missing source and continue only through honestly unaffected work.

## Product purpose

TunnelTend is an unofficial, local-first Windows desired-state manager for OpenAI's official `tunnel-client`. Users register MCP services once. TunnelTend then owns routine startup, tunnel connection, observation, bounded recovery, source-change restarts, verified client updates, and Windows automation.

The official client remains an external dependency and protocol authority. Keep version-specific integration inside `src/TunnelTend/Private/20-OfficialClient.ps1` and the updater boundary.

## Ownership boundary

TunnelTend owns:

- durable service registration and desired state;
- current-logon intent, including deliberate suppression;
- explicit descriptors and conservative discovery;
- configured host-process lifecycle;
- official-runtime lifecycle through a narrow adapter;
- process, tunnel, health, and readiness observation;
- bounded recovery budgets and backoff;
- stable source-change detection;
- verified official-client updates and rollback;
- Windows Scheduled Task registration; and
- read-only diagnostics and structured output.

TunnelTend does not own:

- the OpenAI tunnel protocol or remote control plane;
- arbitrary project builds, dependency updates, migrations, or `git pull`;
- secrets as raw registry values;
- cloud hosting or a central TunnelTend service; or
- generic process supervision outside registered services.

## Operational grammar

| Command | Contract |
|---|---|
| `status` | Read-only desired and observed facts. |
| `health` | Read-only live probes. |
| `doctor` | Read-only diagnosis and recommended actions. |
| `repair` | Read-only bounded repair plan. |
| `repair --apply` | Explicit mutation applying the plan. |
| `reconcile --plan` | Read-only convergence preview. |
| `reconcile` | Explicit desired-state convergence. |

Read-only commands must not persist normalization, timestamps, observations, budgets, or repairs. A command response is not proof of the resulting service postcondition; verify the resulting observation separately.

Structured commands use the versioned envelope in `schemas/output.schema.json`. Preserve compatibility or deliberately version the contract.

## Desired state and session intent

`registry.json` is authoritative desired state. `runtime.json` contains observations, process ownership evidence, recovery accounting, source fingerprints, and current-logon intent.

The watchdog may reconcile only registered services intended to be active in the current session. It must not resurrect disabled services, services deliberately stopped during that session, or abandoned official aliases that were never imported.

Startup establishes a new session boundary. Maintenance preserves session intent rather than treating every enabled registration as currently wanted.

## Registration

The primary human path is:

```powershell
tunneltend service register C:\path\to\project
```

Resolution order:

1. explicit descriptor;
2. explicit CLI target;
3. conservative project discovery;
4. ambiguity refusal.

Never choose arbitrarily among several candidates. Return the candidates and exact explicit command needed to continue.

Normal registration persists the service and starts it unless `--no-start` is supplied. If immediate startup fails, retain the registration and report degraded startup truth.

Secrets are references only:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

Reject likely inline secret material in commands, arguments, environment values, descriptors, errors, and logs.

## Process ownership and termination

Never terminate by process name alone.

Before terminating a recorded PID, verify all available ownership evidence:

- the PID still exists;
- the canonical executable path matches;
- process start time or equivalent generation evidence matches when available; and
- the process belongs to the registered service or official runtime being operated.

PID reuse and stale runtime state are expected. A mismatch is a blocked repair, not permission to kill another process.

`--force` may bypass confirmation, debounce, or recovery backoff only where documented. It never bypasses process identity, secret validation, scope checks, release verification, or archive safety.

## Recovery

Recovery is bounded and reserved in durable runtime state before disruptive mutation:

1. observe current state;
2. confirm the service is intended to be active;
3. validate configuration and official-client capabilities;
4. reserve the attempt;
5. stop only owned processes and runtimes;
6. start the configured host when needed;
7. connect or restore the official runtime;
8. wait for bounded health and readiness; and
9. record result and next eligibility.

One failing service must not block unrelated services. Repeated failure must exhaust a visible budget instead of looping forever.

## Official-client updates

The release source is fixed to `openai/tunnel-client` unless product authority changes it.

Automatic updates require:

- latest stable release unless prereleases are explicitly selected;
- exact Windows architecture selection;
- published release digest or checksum verification;
- guarded extraction against traversal, links, entry-count, and size abuse;
- staged version and capability validation before downtime;
- backup before replacement;
- transactional replacement;
- post-update capability and fleet verification;
- rollback after replacement or restoration failure;
- no automatic downgrade; and
- no official binary committed or bundled by TunnelTend.

Do not replace this with a short download, unzip, and copy sequence.

## Application updates and source watching

A service-specific application-update command is explicit and opt-in. Never infer `git pull`, package-manager updates, restores, builds, migrations, container pulls, or arbitrary scripts.

Source watching detects local changes, not deployments. Honor includes/excludes, avoid junction and symlink loops, establish a baseline before restart, and require stable debounce. Do not consume recovery budget for an incomplete registration.

## Windows automation

Scheduled Tasks live under `\TunnelTend\`:

- `TunnelTend Startup`
- `TunnelTend Watchdog`
- `TunnelTend Maintenance`

Installation is idempotent, current-user scoped by default, and non-overlapping. Elevation is required only when the chosen install boundary genuinely needs it. The Startup task may remain necessary to establish a reliable session boundary even when service autostart is disabled.

## Human and agent setup

Use the public installer and CLI. Do not edit JSON directly except for an explicit corruption recovery.

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Install-TunnelTend.ps1 `
  -NonInteractive `
  -AllManagedAliases
```

Useful switches:

```text
-DisableAutostart
-DisableAutoUpdate
-DisableWatchdog
-AutostartAliases alias-one,alias-two
-OrganizationId org_...
-WorkspaceId ws_...
-RuntimeKeyRef env:CONTROL_PLANE_API_KEY
-TunnelClientPath C:\path\to\tunnel-client.exe
-RegisterPath C:\src\some-mcp
```

Completion evidence:

```powershell
tunneltend status --json
tunneltend health --json
tunneltend doctor --json
tunneltend automation status --json
```

Do not report installation success merely because task registration or process start returned.

## Repository map

See `docs/PROJECT-MAP.md`. Primary implementation homes:

```text
src/TunnelTend/Public/       supported command surface
src/TunnelTend/Private/      state, adapters, health, reconciliation, updater, automation
src/TunnelTend/Tools/        hardened official-client updater
scripts/                     install, uninstall, verification, packaging, compatibility
schemas/                     versioned persisted and output contracts
tests/                       Pester and dependency-free behavior tests
carriers/                    bounded assignment and co-design carriers
```

## Canonical commands

Install the pinned verification dependencies:

```powershell
Install-Module Pester -RequiredVersion 6.2.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser -Force
```

Root verification command:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-Tests.ps1 `
  -RequirePester `
  -RequireAnalyzer
```

Repository contract validation:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-RepositoryValidation.ps1
```

Build a candidate after those gates:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Build-Release.ps1 `
  -Version 0.1.0-preview.1 `
  -SkipTests
```

Safe no-credential smoke path:

```powershell
pwsh -NoProfile -NonInteractive -File .\tunneltend.ps1 --help
pwsh -NoProfile -NonInteractive -File .\tunneltend.ps1 status --json --state-root "$env:TEMP\tunneltend-smoke"
```

Full prerequisites and command meanings live in `docs/DEVELOPMENT.md`.

## Windows release evidence

Before any public release, execute `docs/release-checklist.md` on a disposable Windows account. It covers Task Scheduler registration, sign-in startup, session suppression, watchdog recovery, wrong-PID protection, sleep/resume, concurrent reconciliation, official-client update/rollback, and uninstall/adoption behavior.

Do not claim Windows lifecycle validation from Linux or source-only checks.

## Durable branch posture

```text
main:
  maintainer integration: direct allowed
  external contributions: PR required
  required pre-integration evidence: CI / Test and package for the exact candidate when provider-visible
  required approval/review: none
  resolved conversations: no
  automatic CI: CI; Upstream compatibility watch
  automatic retained branch effects: none
  other pre-update evidence: disposable-Windows lifecycle validation before the first public release
```

The repository is early, founder-controlled, and pre-release. Public release publication, tags, packages, settings changes, or other retained effects still require their own current authority.

## Contribution discipline

- Keep changes scoped to the selected product consequence.
- Add regression protection for repaired behavior and meaningful lifecycle transitions.
- Preserve the read/plan/apply boundary.
- Update schema, migration, and documentation truth together.
- Refresh the upstream compatibility snapshot when relying on changed official-client behavior.
- Never commit secrets, official binaries, generated state, validation logs, or local absolute paths.
- Inspect the final diff, run `git diff --check`, and run the relevant gates before returning work.

## Branding

The current product name is **TunnelTend** and the command/repository slug is **`tunneltend`**. Treat that as the incumbent durable identity. The approved identity is The Fold with the Moonpool After Dark palette. Follow `docs/branding.md`; the artwork lives under `brand/`, where `brand/bundle/` is generated from `brand/source/` and never edited by hand. Do not redraw the mark, imitate OpenAI or MCP marks, or imply endorsement. A wordmark, website, and social composition are not yet designed.

## License

Repository-owned source is AGPL-3.0-only. The official OpenAI tunnel client is a separate external work under its own license and must not be bundled or silently relicensed.
