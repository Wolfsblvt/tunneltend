# TunnelTend

[![CI](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml/badge.svg)](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml)
[![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-5391FE?logo=powershell&logoColor=white)](docs/DEVELOPMENT.md)
[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-663399.svg)](LICENSE)

**Register an MCP service once. TunnelTend keeps it connected afterward.**

TunnelTend is an unofficial, local-first Windows manager for OpenAI's official `tunnel-client`. It turns one or many MCP services into durable desired state, then handles startup, tunnel connection, health observation, bounded recovery, source-change restarts, and verified official-client updates.

> [!IMPORTANT]
> TunnelTend is unofficial and is not affiliated with, supported by, certified by, or endorsed by OpenAI.

> [!NOTE]
> The repository is currently pre-release. Source and CI are public; the first GitHub binary/source release remains gated on the disposable-Windows lifecycle checklist.

## Quick start from source

Requirements: Windows 11, PowerShell 7.4 or later, and an OpenAI tunnel runtime/admin setup appropriate for the tunnel you want to operate.

```powershell
git clone https://github.com/Wolfsblvt/tunneltend.git
Set-Location .\tunneltend
.\Install-TunnelTend.cmd
```

Then register a local MCP project and inspect the fleet:

```powershell
tunneltend service register C:\src\internal-tools

tunneltend status
tunneltend health
tunneltend doctor
```

The recommended setup enables:

- registered-service autostart at Windows logon;
- watchdog reconciliation every two minutes;
- daily verified updates of the official tunnel client;
- restoration of services intended to be running; and
- bounded recovery instead of endless restart loops.

Normal users do not need to edit JSON state files.

## What TunnelTend owns

TunnelTend manages the local lifecycle around the official client:

- durable registration for command-backed and HTTP MCP services;
- desired state and current-logon operator intent;
- process, tunnel, health, and readiness observation;
- bounded restart and recovery budgets;
- source-change detection with stable debounce;
- verified official-client update, backup, restoration, and rollback;
- current-user Windows Scheduled Tasks; and
- truthful read-only diagnostics for humans and agents.

It does **not** implement the OpenAI tunnel protocol, host a central service, infer project update commands, or bundle OpenAI's binary.

## Guided and deterministic setup

Guided setup:

```powershell
pwsh -NoProfile -File .\scripts\Install-TunnelTend.ps1
```

Deterministic setup for scripts and local agents:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Install-TunnelTend.ps1 `
  -NonInteractive `
  -AllManagedAliases
```

Common policy switches:

```text
-DisableAutostart
-DisableAutoUpdate
-DisableWatchdog
-AutostartAliases shelfbound,heartwood
-OrganizationId org_...
-WorkspaceId ws_...
-RuntimeKeyRef env:CONTROL_PLANE_API_KEY
-TunnelClientPath C:\path\to\tunnel-client.exe
-RegisterPath C:\src\some-mcp
```

Secrets are references only:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

TunnelTend rejects likely inline secret material in persisted service definitions and redacts common secret forms from operational messages.

## Register services

Conservative project discovery:

```powershell
tunneltend service register C:\src\internal-tools
```

Explicit command:

```powershell
tunneltend service register C:\src\internal-tools `
  --id internal-tools `
  --command pwsh `
  --arg -File `
  --arg .\server.ps1
```

Existing HTTP MCP service:

```powershell
tunneltend service register `
  --id docs-mcp `
  --url http://127.0.0.1:3001/mcp `
  --health-url http://127.0.0.1:3001/health
```

Import official managed aliases:

```powershell
tunneltend service import --all
```

Discovery prefers an explicit service descriptor, then explicit CLI configuration, then unambiguous project discovery. Ambiguity is returned to the operator instead of being resolved by arbitrary ordering.

## Manage the fleet

```powershell
tunneltend service list
tunneltend service show internal-tools
tunneltend service start internal-tools
tunneltend service stop internal-tools
tunneltend service restart internal-tools
tunneltend service enable internal-tools
tunneltend service disable internal-tools
tunneltend service remove internal-tools
```

A manual stop suppresses automatic resurrection for the current logon session. A later manual start reactivates that service.

## Operational grammar

TunnelTend keeps facts, plans, and mutations distinct:

| Command | Meaning | Mutates state |
|---|---|---:|
| `status` | Desired and observed fleet facts | No |
| `health` | Live process, tunnel, health, and readiness probes | No |
| `doctor` | Diagnosis and recommended actions | No |
| `repair` | Bounded repair plan | No |
| `repair --apply` | Apply the reported repair plan | Yes |
| `reconcile --plan` | Preview desired-state convergence | No |
| `reconcile` | Converge desired and observed state | Yes |

Use `--json` for the stable machine-readable envelope:

```powershell
tunneltend status --json
tunneltend health --json
tunneltend doctor --json
tunneltend reconcile --plan --json
```

`--force` may bypass confirmation, debounce, or recovery backoff only where documented. It never bypasses process ownership, secret-reference rules, scope validation, release verification, or archive safety.

## Autonomous Windows lifecycle

TunnelTend installs current-user tasks under `\TunnelTend\`:

- **TunnelTend Startup** establishes the logon session, checks official-client updates when due, and starts eligible services.
- **TunnelTend Watchdog** reconciles active registered services every two minutes by default.
- **TunnelTend Maintenance** performs daily verified client maintenance and restores the intended fleet.

The watchdog manages only registered services intended to be active in the current session. It does not resurrect disabled services, manually suppressed services, or unrelated aliases.

## Official-client updates

```powershell
tunneltend client status
tunneltend client update
tunneltend client rollback
```

TunnelTend downloads the official client directly from `openai/tunnel-client`, selects the exact Windows architecture asset, verifies published SHA-256 material, extracts into a guarded staging area, backs up the current installation, replaces it transactionally, verifies required capabilities, restores the intended fleet, and rolls back on failure.

Application updates are separate and opt-in. TunnelTend never invents `git pull`, dependency upgrades, builds, migrations, or container pulls merely because a registered path contains source code.

## Ask a local agent to install it

Give a capable local coding agent this prompt:

```text
Clone https://github.com/Wolfsblvt/tunneltend.git and read AGENTS.md completely
before changing or running anything. Install TunnelTend for the current Windows
user with the recommended defaults. Register the MCP projects I name, keep
secrets as env: or file: references, do not weaken release verification or
process-identity checks, and do not elevate unless the selected installation
directory genuinely requires it.

Finish by running:
  tunneltend status --json
  tunneltend health --json
  tunneltend doctor --json
  tunneltend automation status --json

Summarize what is registered, what starts at logon, what automation was
installed, and every boundary that remains unobserved.
```

Add plain-language constraints such as `Do not enable autostart`, `Disable automatic official-client updates`, or `Autostart only shelfbound and heartwood` when needed. The complete agent contract lives in [AGENTS.md](AGENTS.md).

## State and privacy boundary

By default, state remains under the current Windows user profile:

```text
%LOCALAPPDATA%\TunnelTend\state\
  registry.json     durable desired state and policy
  runtime.json      observations, session intent, and recovery budgets
  logs\             structured JSONL operational logs
  backups\          official-client rollback material
  work\             temporary operation data
```

Writes are atomic and schemas are versioned. See [Privacy and data](docs/PRIVACY-AND-DATA.md), [Data model](docs/DATA-MODEL.md), and [Logging](docs/LOGGING.md).

## Develop and verify

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-Tests.ps1 `
  -RequirePester `
  -RequireAnalyzer

pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-RepositoryValidation.ps1

pwsh -NoProfile -NonInteractive -File .\scripts\Build-Release.ps1 `
  -Version 0.1.0-preview.1 `
  -SkipTests
```

The complete portable gate uses Pester 6.2.0 and PSScriptAnalyzer 1.25.0. Windows lifecycle behavior still requires the [disposable-Windows release checklist](docs/release-checklist.md).

## Documentation

Start with the [documentation map](docs/README.md). The most useful deeper references are:

- [Product model](docs/product-model.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Registration](docs/registration.md)
- [Operations](docs/OPERATIONS.md)
- [CLI reference](docs/cli-reference.md)
- [Security](docs/SECURITY.md)
- [Official-client compatibility](docs/upstream-compatibility.md)
- [Development](docs/DEVELOPMENT.md)
- [Release procedure](docs/RELEASING.md)

## License

Licensed under [AGPL-3.0-only](LICENSE), allowing use, modification, and sharing while preserving source access, including for users interacting with modified versions over a network.
