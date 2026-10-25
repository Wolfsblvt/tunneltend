<h1><picture><source media="(prefers-color-scheme: dark)" srcset="brand/bundle/tunneltend/assets/lockup-default/on-dark.svg"><img src="brand/bundle/tunneltend/assets/lockup-default/on-light.svg" alt="TunnelTend" height="44"></picture></h1>

[![CI](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml/badge.svg)](https://github.com/Wolfsblvt/tunneltend/actions/workflows/ci.yml)
[![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-5391FE?logo=powershell&logoColor=white)](docs/DEVELOPMENT.md)
[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-663399.svg)](LICENSE)

**Register once. Leave the routine to TunnelTend.**

TunnelTend keeps the tools on your Windows PC connected to ChatGPT. Once you have connected a tool through an **MCP server**—a program that lets an AI assistant use it—TunnelTend handles the routine: starting it when you sign in, checking it, recovering within limits, and updating OpenAI's official tunnel client. It respects deliberate stops and tells you when something needs your attention.

The co-designed website is live at **[tunneltend.com](https://tunneltend.com)**, with the current reader-facing manual at **[tunneltend.com/docs/](https://tunneltend.com/docs/)**. The source lives under [`website/`](https://github.com/Wolfsblvt/tunneltend/tree/main/website); the repository's [getting-started guide](docs/getting-started.md) and [FAQ](docs/faq.md) remain useful source and maintainer companions.

**[Visit TunnelTend](https://tunneltend.com)** · **[Follow the setup guide](https://tunneltend.com/docs/getting-started/)** · [Download the release](https://github.com/Wolfsblvt/tunneltend/releases/latest) · [FAQ](https://tunneltend.com/faq/)

> [!IMPORTANT]
> TunnelTend is an independent open-source project. It is not affiliated with or endorsed by OpenAI. It manages the official client; it does not replace that client or host a tunnel service.

For example, an MCP server could let ChatGPT search a folder of your notes. That server decides which files and actions are available; TunnelTend looks after the connection. It does not turn an arbitrary app or folder into an MCP server. Your PC must be awake, online and signed in for the normal Windows setup to serve it.

## Before you install

You need **Windows 11**, **PowerShell 7.4 or newer**, a **working MCP server**, and **OpenAI Secure MCP Tunnel access**. Installing TunnelTend does not grant that access. You do not need Git or a developer checkout for the released installer.

If all you have so far is an app name or an idea, start with [Find your MCP service](https://tunneltend.com/docs/getting-started/#find-your-mcp-service). It explains what to look for in the tool's setup instructions, what you can hand to a local coding agent, and where a separate setup step is still needed.

## Install and make your first connection

Open **PowerShell 7** from Windows Start and paste:

```powershell
irm https://tunneltend.com/install.ps1 | iex
```

This downloads the latest release, checks its published SHA-256 checksum and starts the guided installer. It also downloads and verifies OpenAI's official client as a separate program. The installer asks about sign-in startup, recovery checks and client updates; each can be disabled. The default installation is for your current user and needs no administrator window.

**[Get started](https://tunneltend.com/docs/getting-started/)** walks through PowerShell, OpenAI access, credential references and the right registration command for your service. It also has a [download-and-verify route](https://tunneltend.com/docs/getting-started/#download-and-verify-yourself) if you prefer to inspect each installation step.

Once registered, read what TunnelTend sees:

```powershell
tunneltend status
tunneltend health
tunneltend doctor
```

These checks change nothing. If startup failed, your registration is kept so you can diagnose it. Finish with a [real, harmless tool request in ChatGPT](https://tunneltend.com/docs/getting-started/#connect-it-in-chatgpt)—for example, retrieve a known note through your notes server and check the result. A green local status alone does not prove that connection.

**Prefer a local coding agent?** Codex or another agent that can run commands on this Windows PC can follow the canonical guide:

> Install TunnelTend for my current Windows user and register the MCP service I identify, following this guide: https://tunneltend.com/docs/install-with-an-agent/

The agent needs access to your Windows PC, the service's setup details and your OpenAI tunnel ID. Give it a credential **reference**, never the raw key. A cloud-only chat can explain the steps but cannot install on your PC.

## What it takes care of

| Need | TunnelTend's boundary |
| --- | --- |
| Start your services | Windows tasks run for your account after you sign in. |
| Respect a deliberate stop | Stop a service until you start it again, or just for this sign-in. |
| Recover a failed service | Check the right processes, retry within a visible limit, and report when help is needed. |
| React to source changes | Watch registered project files and restart after stable changes; optional. |
| Maintain the official client | Verify downloads, keep a backup, and roll back a failed replacement. |
| Understand a failure | Read-only status and diagnosis, with structured output for local agents. |

TunnelTend manages the lifecycle around the official client. It does not implement the tunnel protocol, host a control plane, manage secrets, or infer `git pull`, builds, dependency upgrades, or deployment commands. Application-update commands are explicit and opt-in.

See [Everyday operation](https://tunneltend.com/docs/operations/) for control and policy, [Register a service](https://tunneltend.com/docs/registration/) for commands, HTTP endpoints and existing aliases, and [Troubleshooting](https://tunneltend.com/docs/troubleshooting/) when something fails. The [CLI reference](https://tunneltend.com/docs/cli/) preserves all the options, read/plan/change boundaries and JSON output for scripts and agents.

## Local state and trust

By default, service definitions, observations, recovery budgets, logs, and client backups live under `%LOCALAPPDATA%\TunnelTend\state`. Credentials remain `env:` or `file:` references. Normal uninstall preserves registered state; explicit purge removes it.

MCP requests and responses travel through OpenAI's infrastructure; local settings do not mean offline use. Read [Privacy and data](https://tunneltend.com/docs/privacy-and-data/) and [Security](https://tunneltend.com/docs/security/) for storage, credentials, process control and download boundaries.

The current release is **1.0.1**. Its [release account](docs/releases/1.0.1.md) describes the diagnostic and installer fixes. Natural Windows sign-in, sleep/resume recovery and a real remote MCP call were observed during the [original qualification](docs/releases/1.0.0.md), which names the tested versions and limits. Confirm your own service and consumer during setup.

## Develop and contribute

Read [AGENTS.md](AGENTS.md) for repository rules and [development](docs/DEVELOPMENT.md) for the pinned tooling, root verification command, package build, and safe no-credential smoke path. [Contributing](CONTRIBUTING.md) explains the contribution route; [architecture](docs/ARCHITECTURE.md) explains the implementation.

Source installation remains supported in the [maintainer getting-started guide](docs/getting-started.md). The public manual lives under [`website/`](website/README.md); the repository's `docs/` tree serves maintainers and contributors.

## License

Licensed under [AGPL-3.0-only](LICENSE), allowing use, modification, and sharing while preserving source access, including for users interacting with modified versions over a network.
