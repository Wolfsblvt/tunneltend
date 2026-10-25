# Get started with TunnelTend

Connect an MCP service you already run, then verify what TunnelTend will maintain for you. This guide covers the Windows installation and first-connection journey. The matching [GitHub Release](https://github.com/Wolfsblvt/tunneltend/releases/latest) carries downloadable availability and its release-specific qualification notes.

For the reader walkthrough, including opening PowerShell, identifying your MCP service and using the released one-line installer, follow [Get started in the public manual](https://tunneltend.com/docs/getting-started/). This repository companion keeps the source-installation and maintainer details below.

You can [follow the steps yourself](#before-installation) or [give this guide to a local coding agent](#install-with-a-local-agent). Both routes use the same installer, commands, and checks.

## Before installation

You need:

- **Windows 11 and PowerShell 7.4 or newer.** Check with `pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion'`. Install PowerShell through [Microsoft's Windows installation guide](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) if it is missing.
- **An MCP service that works locally.** Know its project directory, launch command, or HTTP MCP URL. Install its own runtime and dependencies first; TunnelTend does not infer those setup steps.
- **Access to OpenAI's Secure MCP Tunnels.** Prepare a tunnel and a runtime credential as described below. Installation does not grant that access.
- **TunnelTend files.** Download the ZIP and SHA-256 file from the [release](https://github.com/Wolfsblvt/tunneltend/releases/latest), compare `Get-FileHash -Algorithm SHA256` with the published checksum, and extract it to a directory you control. Cloning [the repository](https://github.com/Wolfsblvt/tunneltend) is also supported.

The default installation is for the current Windows user. Use that same account for setup and later automation. A default user installation does not require elevation; a custom protected location may.

## Prepare your OpenAI tunnel

For a first setup, use an **existing tunnel ID**. This keeps remote provisioning separate from the local service registration you are about to create.

1. Follow [OpenAI's tunnel onboarding](https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md) to create or obtain a tunnel in the correct organization and, where applicable, workspace. The [Platform Tunnels page](https://platform.openai.com/settings/organization/tunnels) is the official management surface. If you cannot provision one, ask the person who manages that OpenAI scope for a tunnel ID and the required access.
2. Obtain a runtime API key with the tunnel **Read** and **Use** permissions described in the [official permissions guide](https://github.com/openai/tunnel-client/blob/master/docs/permissions.md). Administrative provisioning credentials and runtime credentials have different jobs; the running tunnel should use its runtime credential.
3. Make that runtime key available through an environment variable or protected file that the Windows account running the Scheduled Tasks can read. Do not paste the key into commands, chat, a descriptor, or the TunnelTend registry.

TunnelTend accepts references in these forms:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

The default is `env:CONTROL_PLANE_API_KEY`. A variable set only in your current PowerShell process is not a reliable credential source for later Scheduled Tasks. Use a source available to the automation account and protect it with that account's local access controls. A file reference is a reference to a secret file, not an encrypted secret store supplied by TunnelTend.

Keep the tunnel ID and chosen reference ready. The ID is different from the local service ID you will choose below. Organization and workspace selectors are available for existing upstream workflows; they do not bypass OpenAI's access rules. See the [registration guide](registration.md#service-ids-aliases-and-tunnel-ids) for the relationship.

## Install TunnelTend

Open a terminal in the extracted release or source directory. If you are using Git:

```powershell
git clone https://github.com/Wolfsblvt/tunneltend.git
Set-Location .\tunneltend
```

Run the guided installer:

```powershell
.\Install-TunnelTend.cmd
```

The installer downloads and verifies the official OpenAI client by default; you do not need to install it separately for this path. TunnelTend does not bundle that binary. Installation also creates the current-user automation and adds the TunnelTend program directory to your user PATH.

The recommended defaults are:

| Policy | Default behavior |
| --- | --- |
| Startup | Start eligible registered services after this Windows user signs in. |
| Watchdog | Check every two minutes and attempt recovery when policy permits. |
| Official-client updates | Check on the maintenance cadence for a verified stable client update. |

**Open a new terminal after installation** so the PATH change is visible. Run `tunneltend version` and `tunneltend automation status --json` to inspect the installation. An empty service list is expected until you register or import a service; installed tasks alone do not prove a connection works.

Default locations:

| Contents | Location |
| --- | --- |
| TunnelTend program | `%LOCALAPPDATA%\Programs\TunnelTend` |
| Managed official client | `%LOCALAPPDATA%\Programs\TunnelTend\official-client\tunnel-client.exe` |
| Registry, observations, logs, and backups | `%LOCALAPPDATA%\TunnelTend\state` |

## Register your first service

Replace the example path with your project directory and `YOUR_EXISTING_TUNNEL_ID` with the tunnel ID you prepared. `my-mcp` is the local service ID you will use in later commands.

```powershell
tunneltend service register 'C:\src\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

If you chose a file reference, replace the final value with your reference, quoting the whole value when its path contains spaces. Do not substitute the key itself.

Registration saves the service and normally starts it immediately. If discovery finds several plausible targets, it lists their types and reasons and asks for a descriptor or explicit command; it does not generate that command. Choose the target from your MCP server's launch instructions. If startup fails, your registration is retained. Inspect `tunneltend doctor my-mcp` before retrying.

Project-path registration enables source watching by default. Add `--no-source-watch` if this service should restart only when you request it. Add `--no-start` to save a registration for inspection without starting it. `--no-autostart` affects later sign-ins; it does not disable this immediate first start.

Already have an official runtime for this tunnel? [Review and import its alias](registration.md#import-an-existing-official-alias) instead of starting a competing runtime. Otherwise, [registration](registration.md) also covers explicit commands, HTTP endpoints, and descriptors.

## Verify the whole connection

Inspect the registered service and installed automation:

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
| Registration | The target, working directory, tunnel ID or scope, credential reference, and policy are the ones you intended. |
| Current state | Running is intended, the required host and official runtime are observed, and diagnostics do not report a blocking configuration or ownership problem. |
| Health and readiness | The configured probes have the expected result. An absent probe is not a successful MCP request. |
| Automation | The intended Startup, Watchdog, and Maintenance tasks are present for this installation. Their presence does not prove a later sign-in or recovery cycle. |
| Remote consumer | Your intended consumer can actually discover and invoke a harmless tool exposed by this service. |

Configure the consumer separately using [OpenAI's current guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels). For ChatGPT, follow its connector setup and organization/workspace requirements. Then make a real request to a known harmless tool and confirm the expected response. TunnelTend's local health check does not perform that call for you.

If local checks succeed but the consumer cannot connect, follow [consumer troubleshooting](troubleshooting.md#local-checks-pass-but-the-consumer-cannot-connect). Record that boundary as unverified until the call succeeds.

## Choose installation policy

For deterministic installation, run from the extracted release or source root:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Install-TunnelTend.ps1 -NonInteractive
```

This performs installation with the recommended defaults; it is not a dry run. Choose supported switches when you want a different policy:

| Switch | Effect |
| --- | --- |
| `-DisableAutostart` | Keep service startup manual. A Startup task may still establish the watchdog's sign-in session. |
| `-DisableAutoUpdate` | Disable automatic official-client updates. |
| `-DisableWatchdog` | Disable scheduled watchdog recovery. |
| `-RuntimeKeyRef 'env:CONTROL_PLANE_API_KEY'` | Select the default runtime credential reference. |
| `-OrganizationId 'org_...'` / `-WorkspaceId 'ws_...'` | Set default upstream scope for a workflow that uses it. |
| `-TunnelClientPath C:\tools\tunnel-client.exe` | Use an existing official client instead of acquiring one during installation. |
| `-PowerShellPath C:\Tools\PowerShell\pwsh.exe` | Select a portable PowerShell 7.4+ installation for unattended operations. |
| `-RegisterPath C:\src\my-mcp` | Register a project during installation when its required configuration is already available. |
| `-AutostartAliases alias-one,alias-two` | Import selected existing official aliases. |
| `-AllManagedAliases` | Import all existing official aliases deliberately. |
| `-InstallRoot` / `-StateRoot` | Select explicit program and state directories. |
| `-SkipPath` | Leave the user's PATH unchanged. |

Quote any argument containing spaces. Scope selectors accept multiple IDs; they do not create account permissions.

Unattended tasks use a native launcher to prevent console creation and a stable PowerShell selection recorded in `install.json`. Source installation builds that launcher using Windows' existing .NET Framework compiler; no separate .NET SDK is required. Normal PowerShell installations and the current user's WindowsApps alias are supported; use `-PowerShellPath` for a portable installation.

### Custom paths and reinstallation

Program and state roots must be different directories. A dedicated nested state path such as `C:\Tools\TunnelTend\data\state` is supported; do not put state in a program payload directory such as `src` or `official-client`.

When `-StateRoot` is omitted, reinstall and uninstall read the selected installation's `install.json` receipt before falling back to the default state root. An invalid receipt requires an explicit `-StateRoot` override. Reinstallation preserves the selected state and its dedicated nested container.

To update TunnelTend, obtain and verify the intended newer release, extract it and rerun its installer for the same installation. Check the project's change notes and preserve your state first. `tunneltend client update` updates the official client, not TunnelTend's own source or program files.

The following upgrade-continuity repair is in current source for the next release; published **1.0.1 does not include it**. Before reinstalling 1.0.1, inspect and record your current choices and supply the intended policy, scope, credential-reference and client-location options explicitly.

With the repaired installer, reinstallation keeps saved autostart, automatic-update and watchdog choices, scope defaults, credential reference and official-client location when their options are omitted. This also applies to retained state after uninstall. Interactive questions start from the saved choices; explicitly supplied options take precedence. New state still receives the autonomous defaults. When calling the script directly in a PowerShell session, `-DisableAutostart:$false` explicitly enables autostart, and `-OrganizationId @()` explicitly clears the default organization list.

If installation fails after changing settings, it restores only its own settings changes alongside the previous program payload. It preserves registrations, current session intent and unrelated settings. A conflicting later change is left intact and reported as incomplete recovery, with an `installer-recovery-<id>.json` record in the selected state directory. Keep that record and inspect the named fields with `tunneltend config show`. Use explicit installer options on the next attempt to select any values you want changed; do not replace the registry with the recovery record. Optional service registration, alias import and official-client updates have their own effects; this is not a whole-fleet rollback.

## Install with a local agent

Use an agent that can run commands on the Windows computer being configured. Give it the project path or launch target, the existing tunnel ID, the credential **reference**, and any policy changes you want. A cloud chat without local computer access can explain the steps but cannot execute them there.

Copy this task and supply those installation inputs in the same conversation:

```text
Install TunnelTend for my current Windows user and register the MCP service
I identify, following this guide:
https://github.com/Wolfsblvt/tunneltend/blob/main/docs/getting-started.md#install-with-a-local-agent
```

The guide carries the setup contract. The agent should:

- Read the repository's [AGENTS.md](../AGENTS.md) before working in the source, and follow this guide's prerequisites and selected installation policy.
- Inspect the existing installation and aliases before changing them. Use the supported installer and CLI; do not assemble or normalize persisted JSON by hand.
- For the repaired installer in current source/next release, omit policy, scope, credential-reference and client-location options on reinstall unless the operator requested a change. Omission preserves saved choices. Published 1.0.1 lacks this repair: inspect and record the current choices, then pass the intended values explicitly when reinstalling it.
- Use `env:` or `file:` credential references, preserve download verification and process ownership checks, and elevate only when the chosen installation boundary requires it.
- Finish with the registration, `status`, `health`, `doctor`, and `automation status` observations above. Report the registered target, sign-in policy, automation, and any failed or unobserved step.
- Distinguish local setup from the real consumer call and later Windows lifecycle behavior. If it cannot perform an intended check, say which one remains unobserved.

The agent does not need a second prompt containing the whole manual. Plain-language choices such as “disable automatic client updates” map to the same supported policy switches used by a human.

## Uninstall or preserve state

Run the uninstaller from the source checkout. Supply `-InstallRoot` if you used a custom program directory; its receipt resolves the saved state root unless you explicitly override it.

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Uninstall-TunnelTend.ps1 -Force
```

Normal uninstall removes TunnelTend's Scheduled Tasks, attempts to stop registered services for the session, removes the program payload and managed PATH entry, and preserves registered state. The default official client inside the installation is removed with that payload; an external client installation is left alone. Project source, remote OpenAI tunnel objects, and the external credential source are not deleted. Inspect any warnings: the summary alone does not prove every runtime stopped.

| Optional switch | Consequence |
| --- | --- |
| `-KeepRunning` | Leave managed runtimes running while removing TunnelTend's supervision. |
| `-RemoveOfficialClient` | Explicitly remove the configured client file when it is inside the installation and outside state. At the default location, normal program cleanup already removes it. External client paths are not removed. |
| `-PurgeState` | Deliberately delete the selected registry, logs, and backups. Use only when that state is disposable or already preserved. |
| `-SkipPath` | Leave user PATH unchanged. |

For state nested below the installation, normal uninstall preserves its dedicated top-level container, including sibling state. A later installation can reuse preserved state. Verify its paths and run `doctor` before relying on autonomous operation again.
