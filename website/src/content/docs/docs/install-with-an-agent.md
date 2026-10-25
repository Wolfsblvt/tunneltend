---
title: "Install with an agent"
description: "Hand the TunnelTend installation to a local coding agent on your Windows PC: what to give it, what it will do, and which observations count as done."
identity:
  social:
    eyebrow: Documentation
---

A local coding agent, such as Codex or Claude Code running on the Windows computer you want to set up, can install TunnelTend and register your service for you. It uses the same installer, the same CLI and the same read-only checks a person would. There is no separate agent-only mechanism, and installing it does not hand the agent your OpenAI account or its access. Signing in to OpenAI stays with you; see [What the agent may do beyond installing](#what-the-agent-may-do-beyond-installing).

## For you

Copy this task into your agent, then supply the inputs it asks for in the same conversation:

```text
Install TunnelTend for my current Windows user and register the MCP service I identify, following this guide: https://docs.tunneltend.com/install-with-an-agent/
```

Give the agent:

- the **project folder, launch command or HTTP MCP address** of the service you want registered;
- your **existing tunnel ID** from OpenAI (see [Prepare your OpenAI access](https://docs.tunneltend.com/getting-started/#prepare-your-openai-access));
- the **credential reference** you prepared, such as `env:CONTROL_PLANE_API_KEY` or `file:C:\secure\runtime-key.txt`, never the key itself; and
- any **policy wishes** in plain words, for example “keep client updates manual”. They map to the same switches a person would use.

**Only know the app you want to connect?** Give the agent a link to that app's MCP setup instructions and ask it to help identify the server and its launch method first. [Find your MCP service](https://docs.tunneltend.com/getting-started/#find-your-mcp-service) explains what you are looking for. If the server or its dependencies still need installation, that is a separate setup task to agree with the agent before asking it to register the service. It should not invent an integration from an app name.

A cloud-only chat without access to your computer can explain local installation but cannot run it. A configured consumer may still make and verify its own remote tool call; that proves a separate boundary. OpenAI sign-in stays with you. A capable agent can use an already authorized credential reference or mediated provider route without reading secret values.

:::note
TunnelTend is an independent open-source project, not affiliated with OpenAI. The installer fetches OpenAI’s official tunnel client as a separate, verified download. It does not create tunnels, keys or ChatGPT connectors itself.
:::

## For the agent

This page is the setup contract. Follow it rather than improvising from general knowledge about tunnels or MCP.

### Prerequisites to check first

- Windows 11 and PowerShell 7.4 or newer: `pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion'`. If `pwsh` is missing, tell the human; `winget install --id Microsoft.PowerShell --source winget` installs it.
- An MCP server that already runs on this machine: a project folder with one plausible launch target, an explicit command, or an HTTP MCP endpoint. Do not install the service’s own runtime or dependencies unless the human asks for that separately.
- An existing OpenAI tunnel ID and a runtime credential **reference** supplied by the human. If either is missing, ask; do not invent a tunnel, a key, or an organization scope.
- Check whether TunnelTend is already installed. If it is, inspect `tunneltend version`, `tunneltend service list` and `tunneltend automation status --json` before changing it. A missing `tunneltend` command on a fresh PC is expected; if an installation is reported but the command is missing, check [PATH and the installation location](https://docs.tunneltend.com/troubleshooting/#the-command-is-not-found). Inspect any official-client aliases the human already runs by hand. An existing alias is [imported deliberately](https://docs.tunneltend.com/registration/#import-an-existing-official-alias), not duplicated.

### Install

Use the supported installer; never assemble program files or state by hand. From a PowerShell 7 session on this machine:

```powershell
& ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) -NonInteractive
```

That resolves the latest stable release, downloads the ZIP and its SHA-256 file, refuses a checksum mismatch, extracts to `%LOCALAPPDATA%\TunnelTend\downloads\tunneltend-<version>\`, and runs `scripts\Install-TunnelTend.ps1` with the given switches. `-NonInteractive` applies the recommended defaults (sign-in startup, watchdog every two minutes, daily verified client updates). Add policy switches when the human asked for them:

| Human wish | Switch |
| --- | --- |
| Keep service startup manual | `-DisableAutostart` |
| No automatic official-client updates | `-DisableAutoUpdate` |
| No scheduled watchdog recovery | `-DisableWatchdog` |
| Use a different default credential reference | `-RuntimeKeyRef 'env:NAME'` or `-RuntimeKeyRef 'file:C:\path\key.txt'` |
| Default organization or workspace scope | `-OrganizationId 'org_...'` / `-WorkspaceId 'ws_...'` |
| Use an official client already on disk | `-TunnelClientPath C:\tools\tunnel-client.exe` |
| Portable PowerShell for unattended tasks | `-PowerShellPath C:\Tools\PowerShell\pwsh.exe` |
| Custom program or state directories | `-InstallRoot` / `-StateRoot` (must differ) |
| Leave the user `PATH` alone | `-SkipPath` |

Equivalent route from a verified extracted release or a clone of `https://github.com/Wolfsblvt/tunneltend` (the installer still needs network access to acquire the official client unless a suitable existing client is selected):

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Install-TunnelTend.ps1 -NonInteractive
```

The installer downloads OpenAI’s official `tunnel-client`, verifies its published digest, installs the program to `%LOCALAPPDATA%\Programs\TunnelTend`, adds that directory to the user `PATH`, creates the current-user Scheduled Tasks under `\TunnelTend\`, and creates `%LOCALAPPDATA%\TunnelTend\state`. The default user installation needs no elevation; elevate only when a chosen custom location genuinely requires it. Open a **new** shell afterwards so `PATH` is current, or call `%LOCALAPPDATA%\Programs\TunnelTend\tunneltend.cmd` directly.

### Register the service the human identified

Register only what the human named. Replace the path, the ID, the tunnel ID and the reference with their values:

```powershell
tunneltend service register 'C:\Tools\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

- Credentials are references only (`env:` or `file:`). Never pass a key value on the command line, in a descriptor, in a log, or in your report; TunnelTend rejects inline secret material.
- If discovery refuses an ambiguous folder, it lists candidate types and reasons, not a complete command to run. Read the identified MCP server's launch instructions and use an explicit target or descriptor; ask the human when the intended target remains unclear. Do not guess.
- For a command use `--command FILE [--arg VALUE...] [--working-directory PATH]`; for an HTTP server use `--url URL [--health-url URL]`. [Register a service](https://docs.tunneltend.com/registration/) has the full shape.
- Registration starts the service immediately. If the start fails, the registration is retained; read `tunneltend doctor my-mcp --json` and report the cause instead of retrying blindly.
- `--no-source-watch` disables restart-on-file-change for a project registration; `--no-autostart` keeps it out of later sign-ins. Use them only when the human asked.

### Completion checks

Finish with the read-only observations. They print facts and persist nothing:

```powershell
tunneltend service show my-mcp --json
tunneltend status my-mcp --json
tunneltend health my-mcp --json
tunneltend doctor my-mcp --json
tunneltend automation status --json
```

Report, from those outputs: the registered target and working directory, the tunnel ID or scope, the credential reference, the sign-in and watchdog policy, the observed state (host process and official runtime), health and readiness results, any `doctor` diagnostics, and the three Scheduled Tasks’ presence. Include the exact remaining manual dependency, if any.

### Boundaries

- Keep OpenAI authentication human and obtain any missing authority before account or access changes. Use authorized credential references and mediated provider routes without reading secret values back. Authorization to install and register TunnelTend is not authority to create accounts, tunnels, keys, connectors or other provider-side access; see [What the agent may do beyond installing](#what-the-agent-may-do-beyond-installing).
- Use the installer and the public CLI. Never hand-edit or normalize `registry.json`, `runtime.json` or any other TunnelTend JSON.
- Preserve download verification and process-ownership checks. `--force` never bypasses process identity, credential-reference validation, scope, digest verification or archive safety; do not reach for it to make a check pass.
- A process launch, a saved registration or installed tasks are not success. Success is the observed state above plus, separately, a real harmless tool call from the human’s consumer (ChatGPT or another OpenAI product). Make that call only if the human authorized it and you can reach the consumer from this machine; otherwise report it as unobserved.
- Distinguish local setup from the consumer side and from later Windows lifecycle behavior (a future sign-in, sleep/resume, a watchdog cycle). Name each check you could not perform as unobserved rather than assumed.
- Elevate only when the chosen installation boundary genuinely needs it. Do not change machine-wide settings.

### What the agent may do beyond installing

Installing and registering are covered by the task above. Provider and consumer work is a separate grant: creating or changing a tunnel, a key or credential, a connector or any other OpenAI-side resource, and making a real tool call through the consumer. A capable local agent may carry that work when the human has explicitly authorized it, and then only for the exact effect named.

- **Authentication stays human.** The human completes OpenAI sign-in, two-factor prompts and consent screens themselves, or in a session they deliberately opened for the agent. Do not work around a sign-in, and do not use an account, browser session or token the human did not provide for this task.
- **Authority is per effect.** “Install TunnelTend” does not authorize creating an account, a tunnel, a key or a connector. When the human names an effect, do that effect and stop; do not widen it.
- **Secrets stay mediated.** A key value is created, stored and read through the provider’s own interface or the human’s secret store, then reached only by reference (`env:` or `file:`). It never appears in a command line, a descriptor, a log or your report.
- **Say what you observed.** Report each provider or consumer step as done, failed or unobserved, with the evidence you saw.

## What “done” looks like

TunnelTend is installed for the current user, the named service is registered with a credential reference, `status`, `health` and `doctor` report the expected facts, and the intended Scheduled Tasks exist. The last step is configuring the consumer on OpenAI’s side and making one real tool call, by the human or by the agent under the authorization above, as described in [Connect it in ChatGPT](https://docs.tunneltend.com/getting-started/#connect-it-in-chatgpt). If that call fails while local checks pass, [Troubleshooting](https://docs.tunneltend.com/troubleshooting/) separates the two.
