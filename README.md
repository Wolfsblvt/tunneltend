# TunnelTend

[![CI](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml/badge.svg)](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml)
[![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-5391FE?logo=powershell&logoColor=white)](docs/DEVELOPMENT.md)
[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-663399.svg)](LICENSE)

**Register an MCP service once. Let TunnelTend tend its connection.**

TunnelTend is a local-first Windows manager for OpenAI's official `tunnel-client`. It remembers registered services and their desired state, then handles startup, connection, health checks, bounded recovery, source-change restarts, and verified client updates.

**[Get started](docs/getting-started.md)** · **[Documentation](docs/user-guide.md)** · **[FAQ](docs/faq.md)** · **[Install with a local agent](docs/getting-started.md#install-with-a-local-agent)**

> [!IMPORTANT]
> This is an unofficial project, unaffiliated with and not endorsed or supported by OpenAI. TunnelTend is a source preview: Windows lifecycle qualification is incomplete, and no public release has been published. See the [release checklist](docs/release-checklist.md) before relying on unattended operation.

## Quick start from source

You need Windows 11, PowerShell 7.4 or later, and an existing OpenAI tunnel setup with credentials and organization/workspace scope or a tunnel ID. The installer downloads and verifies the official client; TunnelTend never bundles it.

```powershell
git clone https://github.com/Wolfsblvt/tunneltend.git
Set-Location .\tunneltend
.\Install-TunnelTend.cmd
```

The guided installer explains the recommended defaults: logon startup, a watchdog every two minutes, and daily verified client maintenance. Each can be disabled.

Open a new terminal, register a project, and inspect the result:

```powershell
tunneltend service register C:\src\my-mcp
tunneltend status
tunneltend health
tunneltend doctor
```

Registration is retained if startup fails. Use `doctor` to resolve missing scope, credentials, or launch configuration; a saved registration alone does not prove a healthy tunnel. Discovery refuses ambiguous projects and returns the explicit choice needed.

The [getting-started guide](docs/getting-started.md) covers deterministic installation, policy switches, credential references, agent setup, and uninstall. The [registration guide](docs/registration.md) covers explicit commands, HTTP services, descriptors, and existing aliases.

## What it takes care of

| Need | TunnelTend's boundary |
| --- | --- |
| Start the fleet | Current-user Startup, Watchdog, and Maintenance tasks under `\TunnelTend\`. |
| Respect a deliberate stop | Desired state and current-logon suppression control what recovery may restart. |
| Recover a failed service | Ownership checks, thresholds, backoff, and persisted retry budgets. |
| React to source changes | Project registration enables local watching by default, with exclusions and stable debounce; `--no-source-watch` disables it. |
| Maintain the official client | Official Windows asset selection, digest verification, guarded extraction, backup, replacement, and rollback. |
| Understand a failure | Read-only facts and diagnosis with structured output for local agents. |

TunnelTend manages the lifecycle around the official client. It does not implement the tunnel protocol, host a control plane, manage secrets, or infer `git pull`, builds, dependency upgrades, or deployment commands. Application-update commands are explicit and opt-in.

## Inspect, then act

```powershell
tunneltend status --json
tunneltend health --json
tunneltend doctor --json
tunneltend reconcile --plan --json
```

These commands observe or plan without saving state. Mutations use commands such as `service start`, `service stop`, `repair --apply`, `reconcile`, and `client update`. `--force` never bypasses process identity, secret-reference validation, scope, digest verification, or archive safety.

See [operations](docs/OPERATIONS.md), the [CLI reference](docs/cli-reference.md), and [troubleshooting](docs/troubleshooting.md) for ordinary use and recovery.

## Local state and trust

By default, service definitions, observations, recovery budgets, logs, and client backups live under `%LOCALAPPDATA%\TunnelTend\state`. Credentials remain `env:` or `file:` references. Normal uninstall preserves registered state; explicit purge removes it.

Read [privacy and data](docs/PRIVACY-AND-DATA.md), [logging](docs/LOGGING.md), and the [security model](docs/SECURITY.md) for storage, redaction, process-control, and download boundaries. The official client and control plane remain external dependencies.

## Develop and contribute

Read [AGENTS.md](AGENTS.md) for repository rules and [development](docs/DEVELOPMENT.md) for the pinned tooling, root verification command, package build, and safe no-credential smoke path. [Contributing](CONTRIBUTING.md) explains the contribution route; [architecture](docs/ARCHITECTURE.md) explains the implementation.

Local tests, hosted CI, and a built ZIP each prove their own boundary. Real logon, sleep/resume, watchdog recovery, maintenance restoration, and remote MCP use require their corresponding Windows and consumer evidence before a release.

## License

Licensed under [AGPL-3.0-only](LICENSE), allowing use, modification, and sharing while preserving source access, including for users interacting with modified versions over a network.
