# TunnelTend Docs

**Register once. Leave the routine to TunnelTend.**

TunnelTend manages MCP services and their OpenAI tunnel connections from your Windows computer. It remembers what you want running, starts eligible services when you sign in, checks their condition, and attempts bounded recovery when something fails.

This guide starts with an MCP service you can already run. You do not need previous experience with the official tunnel client.

> **Windows 11:** Use the [release account](releases/1.0.0.md) for availability and tested compatibility. Installation, a healthy local runtime, a successful consumer call, and behavior across your own sign-in or resume cycle remain separate checks.

## Start here

| Your next step | Guide |
| --- | --- |
| Connect your first service | [Get started](getting-started.md): prerequisites, installation, registration, and a real consumer check. |
| Let a local coding agent help | [Install with a local agent](getting-started.md#install-with-a-local-agent): the same installation with explicit inputs and completion evidence. |
| Decide whether TunnelTend fits | [FAQ](faq.md): ownership, alternatives, privacy, automation, and current limits. |

## Where TunnelTend fits

An MCP service exposes tools or resources to an AI client. OpenAI's official tunnel client connects that service to OpenAI's Secure MCP Tunnel infrastructure. TunnelTend manages the local lifecycle around the official client.

| Part | Its job |
| --- | --- |
| Your MCP service | Implements the tools and resources. It runs as a command or serves an HTTP MCP endpoint. |
| OpenAI's official `tunnel-client` | Carries the MCP connection and owns the upstream runtime and tunnel protocol. The installer downloads and verifies this separate dependency. |
| TunnelTend | Saves service registrations and operating policy; manages configured processes, official runtimes, Windows tasks, recovery, and client maintenance. |
| Your consumer | Uses the tunnel from an eligible OpenAI product. Its account, connector configuration, and permissions remain separate setup. |

TunnelTend runs locally. There is no TunnelTend account or hosted TunnelTend control plane. MCP traffic still passes through OpenAI's infrastructure; [local-first does not mean offline](PRIVACY-AND-DATA.md).

## What happens after registration

Normal registration saves a service and tries to start it immediately. If startup fails, the registration remains available for diagnosis. A saved service is useful evidence of configuration, not proof that a remote tool call works.

With the recommended installer defaults, eligible services start at the current user's Windows sign-in, the watchdog runs every two minutes, and daily maintenance checks for verified official-client updates. Each policy can be turned off. These are current-user Scheduled Tasks, so the computer and the signed-in session matter.

Project-path registration also enables source watching by default. Stable local changes can restart the service; TunnelTend does not infer a build, dependency update, or `git pull`. Use `--no-source-watch` when you want manual restarts. See [registration](registration.md#choose-startup-and-watching) and [operations](OPERATIONS.md#source-watching-and-application-updates).

## The commands you will use most

Run `tunneltend service list` to find your service ID. Replace `my-mcp` below with that ID.

| What you want | Command |
| --- | --- |
| See intended and observed state | `tunneltend status my-mcp` |
| Run the configured health checks | `tunneltend health my-mcp` |
| Understand a problem | `tunneltend doctor my-mcp` |
| Preview a repair | `tunneltend repair my-mcp` |
| Apply a fresh repair plan | `tunneltend repair my-mcp --apply` |
| Start or restart a service | `tunneltend service start my-mcp` / `tunneltend service restart my-mcp` |
| Keep it stopped across later sign-ins | `tunneltend service stop my-mcp` |
| Stop it for this sign-in session | `tunneltend service stop my-mcp --session-only` |

`status`, `health`, `doctor`, and a repair preview do not save or repair state. Read-only checks can still inspect processes and contact configured endpoints. Add `--json` for structured results.

A session-only stop is respected by the watchdog. An explicit manual start, restart, or applying manual reconciliation can resume it; a new sign-in resets session suppression. Use the ordinary durable stop when you want it to stay stopped. [Operations](OPERATIONS.md#manual-intent) explains these distinctions.

## Go deeper when you need it

| Reader job | Canonical guide |
| --- | --- |
| Register a project, command, HTTP endpoint, or existing alias | [Service registration](registration.md) |
| Understand registration, intended state, and observations | [Service state](product-model.md) |
| Control sign-in startup, recovery, watching, and updates | [Operations](OPERATIONS.md) |
| Look up a command or exit code | [CLI reference](cli-reference.md) |
| Diagnose a failed start or unreachable consumer | [Troubleshooting](troubleshooting.md) |
| Understand local data and credential references | [Privacy and data](PRIVACY-AND-DATA.md) |
| Understand process control and download safeguards | [Security](SECURITY.md) |
| Find and share useful diagnostic evidence | [Logging](LOGGING.md) |
| Remove TunnelTend or preserve an installation | [Uninstall](getting-started.md#uninstall-or-preserve-state) |

For implementation and contribution work, use the [repository documentation map](README.md) and [contributing guide](../CONTRIBUTING.md).
