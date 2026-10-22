---
title: "Get started"
description: "Install TunnelTend on Windows, prepare your OpenAI tunnel access, register your first service, and verify that ChatGPT can really reach it."
identity:
  social:
    eyebrow: Documentation
---

This is the complete first journey: from a tool that already runs on your Windows PC to a connection you have verified from ChatGPT. It takes one terminal and about twenty minutes, most of it on OpenAI’s side. If a word is new, [How it works](/docs/how-it-works/) explains it in five minutes.

You can follow the steps yourself, or [hand this guide to a local coding agent](/docs/install-with-an-agent/). Both routes use the same installer, the same commands and the same checks.

## Before installation

You need four things:

- **Windows 11 with PowerShell 7.4 or newer.** Check with `pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion'`. If `pwsh` is missing, install it with `winget install --id Microsoft.PowerShell --source winget` or follow [Microsoft’s guide](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
- **An MCP server that already works on your PC.** Know its project folder, its launch command, or its HTTP MCP address. Install its own runtime and dependencies first; TunnelTend does not guess those steps and does not turn an arbitrary program into an MCP server.
- **Access to OpenAI’s Secure MCP Tunnels.** A tunnel in your OpenAI organization and a runtime key, prepared in the next section. Installing TunnelTend grants no access.
- **About ten minutes of attention at the OpenAI steps.** Everything else is a few commands.

The default installation is for your current Windows user and needs no elevation. Use that same account for setup and for the automation that follows. A custom protected location may need elevation; the default does not.

:::note
TunnelTend is an independent open-source project and is not affiliated with OpenAI. It manages OpenAI’s official tunnel client; it does not replace it or host anything for you.
:::

## Prepare your OpenAI access

For a first setup, use an **existing tunnel ID**. That keeps the OpenAI-side provisioning separate from the local registration you are about to create, so a problem on one side is easy to tell from the other.

1. Create or obtain a tunnel in the correct OpenAI organization and, where it applies, workspace. Follow [OpenAI’s tunnel onboarding](https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md); the [Platform Tunnels page](https://platform.openai.com/settings/organization/tunnels) is the official management surface. If you cannot create one, ask whoever administers that OpenAI organization for a tunnel ID and the access you need.
2. Obtain a runtime API key with the tunnel **Read** and **Use** permissions described in OpenAI’s [permissions guide](https://github.com/openai/tunnel-client/blob/master/docs/permissions.md). Administrative keys and runtime keys have different jobs; the running tunnel should use a runtime key.
3. Put that key where the Windows account running TunnelTend can read it: an environment variable or a protected file. Do not paste it into a command, a chat, a descriptor or TunnelTend’s registry.

TunnelTend never stores the key. It stores a **reference** in one of these forms and resolves it only when the official client starts:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

The default reference is `env:CONTROL_PLANE_API_KEY`. A variable set only in your current PowerShell window is not visible to the later Scheduled Tasks; set it as a user environment variable (Windows Settings → “Edit environment variables for your account”) or use a file reference. A file reference is a pointer to a file you protect with your account’s permissions; it is not an encrypted store.

Keep the tunnel ID and your chosen reference ready. The tunnel ID is OpenAI’s; the service ID you choose in a moment is TunnelTend’s local name for the service. Organization and workspace selectors are available for workflows that need them; they do not bypass OpenAI’s access rules. [Register a service](/docs/registration/) explains the relationship between IDs, aliases and tunnel IDs.

## Install TunnelTend

Pick one route. All three end at the same guided installer, which asks three questions before it changes anything: start registered services at sign-in, check for verified client updates daily, and recover unhealthy services every two minutes. The recommended answer to each is yes, and each can be changed later.

### One line

Open a PowerShell 7 window (`pwsh`, not the old Windows PowerShell) and paste:

```powershell
irm https://tunneltend.com/install.ps1 | iex
```

The script resolves the latest stable release, downloads the release ZIP and its published SHA-256 file, refuses to continue on a checksum mismatch, extracts the release to `%LOCALAPPDATA%\TunnelTend\downloads\tunneltend-<version>\`, and runs the guided installer from there. Want to read it first? It is served as plain text at [tunneltend.com/install.ps1](/install.ps1).

To pass installer switches, or to download and verify without installing:

```powershell
& ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) -NonInteractive -DisableAutoUpdate
& ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) -NoInstall
```

### Download and verify yourself

Get `tunneltend-<version>.zip` and `tunneltend-<version>.zip.sha256` from the [latest release](https://github.com/Wolfsblvt/tunneltend/releases/latest). Compare the hashes, extract, and run the installer:

```powershell
Get-FileHash .\tunneltend-1.0.0.zip -Algorithm SHA256
Get-Content .\tunneltend-1.0.0.zip.sha256
Expand-Archive .\tunneltend-1.0.0.zip -DestinationPath .\tunneltend
.\tunneltend\Install-TunnelTend.cmd
```

The two hashes must match exactly. If they do not, delete the download and get it again.

### From source

Cloning the repository is supported too:

```powershell
git clone https://github.com/Wolfsblvt/tunneltend.git
Set-Location .\tunneltend
.\Install-TunnelTend.cmd
```

### What the installer does

- Downloads OpenAI’s official `tunnel-client` for Windows and verifies its published digest. You do not install it separately for this path, and TunnelTend never bundles it.
- Copies the TunnelTend program to `%LOCALAPPDATA%\Programs\TunnelTend` and adds that directory to your user `PATH`.
- Creates the current-user Scheduled Tasks you agreed to under `\TunnelTend\`.
- Creates the state directory at `%LOCALAPPDATA%\TunnelTend\state` for registrations, observations, logs and client backups.

| Contents | Location |
| --- | --- |
| TunnelTend program | `%LOCALAPPDATA%\Programs\TunnelTend` |
| Managed official client | `%LOCALAPPDATA%\Programs\TunnelTend\official-client\tunnel-client.exe` |
| Registry, observations, logs and backups | `%LOCALAPPDATA%\TunnelTend\state` |

**Open a new terminal after installation** so the `PATH` change is visible. Then look at what you have:

```powershell
tunneltend version
tunneltend automation status --json
```

An empty service list is expected until you register one. Installed tasks alone do not prove that any connection works.

## Register your first service

Replace the example folder with your project directory and `YOUR_EXISTING_TUNNEL_ID` with the tunnel ID you prepared. `my-mcp` is the local service ID you will use in later commands; pick something short.

```powershell
tunneltend service register 'C:\src\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

If you chose a file reference, replace the final value with it and quote the whole value when the path contains spaces. Do not substitute the key itself.

What happens:

- TunnelTend looks at the folder for one plausible way to launch an MCP server. If it finds several, it stops and shows you the explicit command to run instead; it does not guess.
- The registration is saved, and the service is started immediately with the official client connected to your tunnel.
- If that first start fails, the registration stays. Run `tunneltend doctor my-mcp` before retrying; it names the cause.

Useful switches for this first command:

| Switch | Effect |
| --- | --- |
| `--no-start` | Save the registration for inspection without starting it. |
| `--no-source-watch` | Do not restart the service when files in the project change. Project registration watches by default. |
| `--no-autostart` | Do not start this service at later sign-ins. The immediate first start still happens. |

Already running the official client for this tunnel by hand? [Import its alias](/docs/registration/#import-an-existing-official-alias) instead of starting a competing runtime. A command (`--command`), an HTTP endpoint (`--url`) and descriptor files are also covered in [Register a service](/docs/registration/).

## Verify the whole connection

Read what TunnelTend observed. Each command prints facts and changes nothing:

```powershell
tunneltend service show my-mcp --json
tunneltend status my-mcp --json
tunneltend health my-mcp --json
tunneltend doctor my-mcp --json
tunneltend automation status --json
```

Read the returned facts, not just the exit code:

| Check | What to establish |
| --- | --- |
| Registration | The target, working directory, tunnel ID or scope, credential reference and policy are the ones you intended. |
| Current state | Running is intended, the host process and the official runtime are observed, and `doctor` reports no blocking configuration or ownership problem. |
| Health and readiness | The configured probes have the expected result. A probe you never configured is not an MCP test. |
| Automation | The intended Startup, Watchdog and Maintenance tasks are present for this installation. Their presence does not prove a later sign-in or recovery cycle. |
| Remote consumer | ChatGPT (or your intended consumer) can actually discover and call a harmless tool exposed by this service. |

The last row is the one that matters, and TunnelTend cannot do it for you: a green local status is evidence that your PC is doing its part, not proof that the whole chain works.

## Connect it in ChatGPT

Configure the consumer on OpenAI’s side. For ChatGPT, follow [OpenAI’s current guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for your plan, organization and workspace: that is where the connector is created and where OpenAI states who may use it. TunnelTend does not create connectors and has no view of your ChatGPT settings.

Then make one real request to a known harmless tool and confirm the expected answer comes back. That call is the proof. Until it succeeds, treat the connection as unverified, even when everything on your PC is green.

If the local checks pass but ChatGPT cannot connect, follow [Troubleshooting](/docs/troubleshooting/), which separates local causes from upstream scope, credential and connector problems.

## Choose installation policy

The guided installer is the normal route. For a deterministic installation with the recommended defaults and no questions, run from the extracted release or source root:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Install-TunnelTend.ps1 -NonInteractive
```

This installs; it is not a dry run. Add switches when you want a different policy. The same switches work after the one-line installer through `& ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) <switches>`.

| Switch | Effect |
| --- | --- |
| `-DisableAutostart` | Keep service startup manual. A Startup task may still establish the watchdog’s sign-in session. |
| `-DisableAutoUpdate` | Disable automatic official-client updates. |
| `-DisableWatchdog` | Disable scheduled watchdog recovery. |
| `-RuntimeKeyRef 'env:CONTROL_PLANE_API_KEY'` | Select the default runtime credential reference. |
| `-OrganizationId 'org_...'` / `-WorkspaceId 'ws_...'` | Set default upstream scope for a workflow that uses it. |
| `-TunnelClientPath C:\tools\tunnel-client.exe` | Use an official client you already have instead of acquiring one during installation. |
| `-PowerShellPath C:\Tools\PowerShell\pwsh.exe` | Select a portable PowerShell 7.4+ installation for unattended operations. |
| `-RegisterPath C:\src\my-mcp` | Register a project during installation when its required configuration is already available. |
| `-AutostartAliases alias-one,alias-two` | Import selected existing official aliases. |
| `-AllManagedAliases` | Import all existing official aliases deliberately. |
| `-InstallRoot` / `-StateRoot` | Select explicit program and state directories. |
| `-SkipPath` | Leave your user `PATH` unchanged. |

Quote any argument containing spaces. Scope selectors accept several IDs; they do not create account permissions.

Unattended tasks use a native launcher so no console window appears, and a stable PowerShell selection recorded in `install.json`. Source installation builds that launcher with Windows’ existing .NET Framework compiler; no separate SDK is needed. Normal PowerShell installations and the WindowsApps alias are supported; use `-PowerShellPath` for a portable installation.

### Custom paths and reinstallation

Program and state roots must be different directories. A dedicated nested state path such as `C:\Tools\TunnelTend\data\state` is supported; do not put state inside a program payload directory such as `src` or `official-client`.

When `-StateRoot` is omitted, reinstall and uninstall read the installation’s `install.json` receipt before falling back to the default state root. An invalid receipt requires an explicit `-StateRoot`. Reinstallation preserves the selected state.

To update TunnelTend itself, obtain and verify the newer release, extract it and rerun its installer for the same installation. Preserve your state first and read the change notes. `tunneltend client update` updates OpenAI’s client, not TunnelTend.

## From here

- [Everyday operation](/docs/operations/): deliberate stops, what the watchdog may restart, source watching, client updates, and [how to uninstall](/docs/operations/#uninstall) while keeping your registrations.
- [Install with an agent](/docs/install-with-an-agent/): hand this same journey to a local coding agent with explicit inputs and completion evidence.
