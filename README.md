<h1><picture><source media="(prefers-color-scheme: dark)" srcset="brand/bundle/tunneltend/assets/lockup-default/on-dark.svg"><img src="brand/bundle/tunneltend/assets/lockup-default/on-light.svg" alt="TunnelTend" height="44"></picture></h1>

[![CI](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml/badge.svg)](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml)
[![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-5391FE?logo=powershell&logoColor=white)](https://docs.tunneltend.com/getting-started/#before-installation)
[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-663399.svg)](LICENSE)

**Register once. Leave the routine to TunnelTend.**

TunnelTend looks after the local programs that give ChatGPT tools—your **MCP services**. Register one or many on a Windows PC, and it handles startup, tunnel connection, health checks, and bounded recovery through OpenAI's official tunnel client. Your tools might work with notes, files, a local database, or a home server; TunnelTend takes care of keeping their processes connected.

**[Website](https://tunneltend.com/) · [Documentation](https://docs.tunneltend.com/) · [Latest release](https://github.com/Wolfsblvt/tunneltend/releases/latest) · [FAQ](https://tunneltend.com/faq/)**

TunnelTend is an independent open-source project, unaffiliated with OpenAI. [How it works](https://docs.tunneltend.com/how-it-works/) explains the service, tunnel, and ChatGPT connection.

## What it takes care of

| When… | TunnelTend… |
| --- | --- |
| You sign in | Starts the services you selected through current-user Windows tasks. |
| A service fails | Checks process ownership and retries within a recovery budget, with backoff. Deliberate stops stay respected. |
| Your project changes | Restarts after watched files settle. Project watching is on by default; `--no-source-watch` turns it off. |
| OpenAI releases a client update | Verifies and stages the official client, keeps a backup, and rolls back if replacement or restoration fails. |

[Everyday operation](https://docs.tunneltend.com/operations/) explains the controls and limits. TunnelTend does not infer builds, dependency upgrades, or `git pull`; application-update commands are explicit and opt-in.

## Get running

Before installing, you need:

- **Windows 11 and PowerShell 7.4+.**
- **An MCP service that already works**, with its runtime and dependencies installed.
- **OpenAI Secure MCP Tunnels access**, an existing tunnel ID, and a runtime credential supplied by reference. [Prepare your access](https://docs.tunneltend.com/getting-started/#prepare-your-openai-access), including a credential source the Windows task account can read.

If all you have so far is an app name or an idea, start with [Find your MCP service](https://docs.tunneltend.com/getting-started/#find-your-mcp-service). It explains what to look for in the app's setup instructions and what you can hand to a local coding agent. TunnelTend does not turn an arbitrary app or folder into an MCP server. You do not need Git or a developer checkout for the released installer.

Use a persistent user environment variable or protected file for the credential; a variable set only in one terminal will not reach scheduled tasks. Your PC must stay awake and signed in for current-user automation.

The [latest stable GitHub Release](https://github.com/Wolfsblvt/tunneltend/releases/latest) establishes downloadable availability and release notes. The [Windows qualification account](docs/releases/1.0.0.md) names the versions and limits of the original sign-in, recovery and remote-call observations. Confirm your own service and consumer during setup.

### Install

Open **PowerShell 7** from Windows Start and run:

```powershell
irm https://tunneltend.com/install.ps1 | iex
```

The bootstrap verifies the release ZIP before running the guided installer. The default installation needs no administrator rights; it offers sign-in startup, recovery checks every two minutes, and daily verified updates of **OpenAI's client**. Each can be disabled.

[Read the installer](https://tunneltend.com/install.ps1), [download and verify a release yourself](https://docs.tunneltend.com/getting-started/#download-and-verify-yourself), or [install from source](https://docs.tunneltend.com/getting-started/#from-source).

### Register and verify

Open a **new terminal**. Replace the folder and tunnel ID below; `my-mcp` is your local service name. Registration starts the service immediately. Supply a credential **reference**, never the key itself.

```powershell
tunneltend service register 'C:\src\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
tunneltend status my-mcp
tunneltend health my-mcp
tunneltend doctor my-mcp
```

Add `--no-start` to save without starting. If startup fails, the registration stays and `doctor` explains the problem. Ambiguous project discovery asks you to choose. Already running the official client? [Import its alias](https://docs.tunneltend.com/registration/#import-an-existing-official-alias) instead.

**Success means more than a saved registration:** the intended host and official runtime are observed, configured probes pass, and ChatGPT can call a harmless tool successfully. [Finish the connection and verify it](https://docs.tunneltend.com/getting-started/#verify-the-whole-connection); local health alone cannot prove the remote call.

**Prefer a local coding agent?** Give an agent that can run commands on this Windows PC the same maintained journey:

> Install TunnelTend for my current Windows user and register the MCP service I identify, following this guide: https://docs.tunneltend.com/install-with-an-agent/

The agent needs access to your Windows PC, the service's setup details and your OpenAI tunnel ID. Give it a credential **reference**, never the raw key. A cloud-only chat can explain the steps but cannot install on your PC.

## Stay in control

`status`, `health`, `doctor`, `repair`, and `reconcile --plan` read or plan without saving state. Changes use explicit actions such as `service start`, `service stop`, `repair --apply`, and `client update`. Add `--json` for structured output. See the [CLI reference](https://docs.tunneltend.com/cli/) and [troubleshooting](https://docs.tunneltend.com/troubleshooting/).

Registrations, observations, logs, and backups stay under `%LOCALAPPDATA%\TunnelTend\state` by default. Credentials remain `env:` or `file:` references, and normal uninstall preserves state. Read [privacy and data](https://docs.tunneltend.com/privacy-and-data/) and the [security model](https://docs.tunneltend.com/security/) for storage, network, and process-control boundaries. MCP requests and responses travel through OpenAI's official client and infrastructure; TunnelTend also fetches releases and probes the health/readiness addresses you configure. [What leaves your computer](https://docs.tunneltend.com/privacy-and-data/#what-leaves-your-computer) separates those paths from your MCP service's own traffic. OpenAI's client and control plane remain external dependencies.

## Develop and contribute

Start with [Contributing](CONTRIBUTING.md), the [development guide](docs/DEVELOPMENT.md), and [repository instructions](AGENTS.md). The [architecture](docs/ARCHITECTURE.md) explains the implementation; [release notes](https://github.com/Wolfsblvt/tunneltend/releases) and the [Windows qualification account](docs/releases/1.0.0.md) identify tested versions and coverage limits.

## License

Licensed under [AGPL-3.0-only](LICENSE), allowing use, modification, and sharing while preserving source access, including for users interacting with modified versions over a network.
