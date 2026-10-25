---
title: "Get started"
description: "Install TunnelTend on Windows, prepare your OpenAI tunnel access, register your first service, and verify that ChatGPT can really reach it."
identity:
  social:
    eyebrow: Documentation
---

This guide takes you from a working MCP service on your Windows PC to a useful result from that service in ChatGPT. You will check the prerequisites, prepare OpenAI access, install TunnelTend, register the service, and try a real request. If a word is new, [How it works](https://docs.tunneltend.com/how-it-works/) explains the pieces.

You can follow the steps yourself, or [hand this guide to a local coding agent](https://docs.tunneltend.com/install-with-an-agent/). Both routes use the same installer, the same commands and the same checks.

## Before installation

Check these before installing:

- **Windows 11.** This release does not offer a supported macOS or Linux installation.
- **PowerShell 7.4 or newer.** This is the app in which you will paste the commands. [Open and check it below](#open-powershell-7); Git is not needed for the released installer.
- **A working MCP service.** You need the server's project folder, launch command, or HTTP MCP address. The next section helps you identify which you have.
- **OpenAI Secure MCP Tunnel access.** You need a tunnel ID, permission to use it, and a runtime API key. Check [OpenAI’s current access requirements](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for your organization or workspace before spending time on local setup. A ChatGPT subscription by itself is not proof of tunnel access.

The default installation is for your current Windows user and needs no elevation. Use that same account for setup and for the automation that follows. A custom protected location may need elevation; the default does not.

:::note
TunnelTend is an independent open-source project and is not affiliated with OpenAI. It manages OpenAI’s official tunnel client; it does not replace it or host anything for you.
:::

## Find your MCP service

Start with the app or task you want ChatGPT to use. An **MCP server** is the program that makes that app's information or actions available. Your app's ordinary installation folder, a folder of documents, or its website address is not automatically an MCP server.

Look in the app or MCP server's setup instructions for one of these:

| What its instructions give you | What to keep for registration |
| --- | --- |
| A project folder containing an MCP server, with its dependencies already installed | The full folder path, such as `C:\Tools\my-mcp`. TunnelTend will look for a descriptor or one supported launch target. |
| A command that starts the MCP server, often described as **stdio** | The executable, each argument, and any required working directory. Use [the command route](https://docs.tunneltend.com/registration/#register-a-command). |
| A running server's **HTTP MCP endpoint** | Its exact MCP URL. Use [the HTTP route](https://docs.tunneltend.com/registration/#register-an-http-endpoint). An ordinary web page or health-check address will not do. |
| An existing OpenAI tunnel-client alias | [Inspect and import that alias](https://docs.tunneltend.com/registration/#import-an-existing-official-alias) instead of starting another runtime for it. |

**Only know the app's name so far?** Give its setup-documentation link to a local coding agent, or ask the app's maintainer whether it supports MCP and how to start that server. An agent can help identify the target, but an app without MCP support needs a separate integration. TunnelTend does not build that integration or install the server's dependencies. Get the server working using its own instructions before returning here.

The [agent installation guide](https://docs.tunneltend.com/install-with-an-agent/) tells you what to hand over once you have those details. You can keep using the manual even if you have no local coding agent.

## Open PowerShell 7

1. Open Windows **Start**, search for **PowerShell 7**, and open it. The older app named **Windows PowerShell** is a different version. Use an ordinary window for the default current-user installation; **Run as administrator** is not needed.
2. Paste the following line and press **Enter**:

   ```powershell
   $PSVersionTable.PSVersion
   ```

3. Check the `Major` and `Minor` numbers. You need 7.4 or newer. If PowerShell 7 is missing or too old, use [Microsoft’s installation guide](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows), then open it again. If you already use Windows Package Manager, its install command is `winget install --id Microsoft.PowerShell --source winget`.

Copy only the commands in a code block, not a `PS C:\…>` prompt from a screenshot. Paths and IDs in the examples are placeholders: replace them with your own before running the registration command. Keep quotation marks around paths that contain spaces.

## Prepare your OpenAI access

For a first setup, use an **existing tunnel ID**. That keeps the OpenAI-side provisioning separate from the local registration you are about to create, so a problem on one side is easy to tell from the other.

1. Create or obtain a tunnel in the correct OpenAI organization and, where it applies, workspace. Follow [OpenAI’s tunnel onboarding](https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md); the [Platform Tunnels page](https://platform.openai.com/settings/organization/tunnels) is the official management surface. If you cannot create one, ask whoever administers that OpenAI organization for a tunnel ID and the access you need.
2. Obtain a runtime API key with the tunnel **Read** and **Use** permissions described in OpenAI’s [permissions guide](https://github.com/openai/tunnel-client/blob/master/docs/permissions.md). Administrative keys and runtime keys have different jobs; the running tunnel should use a runtime key.
3. Put that key where the Windows account running TunnelTend can read it: an environment variable or a protected file. Do not paste it into a command, a chat, a descriptor or TunnelTend’s registry.

TunnelTend saves a **reference** in the registration instead of the key itself. The reference tells the local programs where to find the key:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

For the default `env:CONTROL_PLANE_API_KEY` reference:

1. In Windows Start, search for **Edit environment variables for your account** and open it.
2. Under **User variables**, choose **New**. Set the name to `CONTROL_PLANE_API_KEY` and enter the runtime key as its value yourself. If that name already exists, check which service uses it before replacing its value.
3. Save the dialog. Save your work, sign out of Windows and sign back in, then open PowerShell 7 again so the new sign-in and its programs inherit the user variable.

Do not put the key into the commands below, share it with an agent, or print it to check that it exists. `tunneltend doctor` can report an unavailable credential reference without displaying the key. Setting `$env:CONTROL_PLANE_API_KEY` in one terminal changes only that process and its children; it does not prepare later Scheduled Tasks. [Microsoft explains environment-variable scope](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_environment_variables).

If you already keep the runtime key in a file protected for your Windows account, use a `file:` reference instead. Both the environment variable and the file must be accessible to the account running TunnelTend; neither is an encrypted secret store. The file example above is a placeholder, not a file TunnelTend creates for you.

Keep the tunnel ID and your chosen reference ready. The tunnel ID is OpenAI’s; the service ID you choose in a moment is TunnelTend’s local name for the service. Organization and workspace selectors are available for workflows that need them; they do not bypass OpenAI’s access rules. [Register a service](https://docs.tunneltend.com/registration/) explains the relationship between IDs, aliases and tunnel IDs.

## Install TunnelTend

The one-line route is the shortest. You can also download the release yourself, install from source, or [ask a local coding agent to follow the guide](https://docs.tunneltend.com/install-with-an-agent/). Each uses the same installer. It asks whether to start registered services at sign-in, check for verified client updates daily, and check for services needing recovery every two minutes. The recommended answer to each is yes, and each can be changed later.

### One line

Open a PowerShell 7 window (`pwsh`, not the old Windows PowerShell) and paste:

```powershell
irm https://tunneltend.com/install.ps1 | iex
```

The script resolves the latest stable release, downloads the release ZIP and its published SHA-256 file, refuses to continue on a checksum mismatch, extracts the release to `%LOCALAPPDATA%\TunnelTend\downloads\tunneltend-<version>\`, and runs the guided installer from there. Want to read it first? It is served as plain text at [tunneltend.com/install.ps1](/install.ps1).

For unattended installation or different defaults, see [Choose installation policy](#choose-installation-policy). To download and verify without installing:

```powershell
& ([scriptblock]::Create((irm https://tunneltend.com/install.ps1))) -NoInstall
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

**Close your terminal app completely and reopen PowerShell 7 after installation** so it can pick up the updated `PATH` (Windows' list of folders in which to find commands). Then look at what you have:

```powershell
tunneltend version
tunneltend automation status
```

`version` should report the installed TunnelTend version. `automation status` should show the tasks selected during installation. An empty service list is expected until you register one. Installed tasks alone do not prove that any connection works. If Windows says `tunneltend` is not recognized, use [the command-not-found steps](https://docs.tunneltend.com/troubleshooting/#the-command-is-not-found).

## Register your first service

Use the route that matches [the service details you found](#find-your-mcp-service). The example below is for an **MCP project folder**. If your instructions give a launch command or an HTTP URL, follow [Register a service](https://docs.tunneltend.com/registration/) for that command, then return to [Verify the whole connection](#verify-the-whole-connection).

Replace `'C:\Tools\my-mcp'` with the actual MCP project folder and `YOUR_EXISTING_TUNNEL_ID` with the tunnel ID from OpenAI. `my-mcp` is a local name you choose; use that same name in the checks below. The backtick at the end of a line continues the command onto the next line: copy the whole block together.

```powershell
tunneltend service register 'C:\Tools\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

If you chose a file reference, replace the final value with it and quote the whole value when the path contains spaces. Do not substitute the key itself.

What happens:

- TunnelTend uses a project descriptor when present, or looks for one supported launch target. If it finds none or several, it stops before saving a guessed definition. Use the server's documented launch command or a descriptor; the error lists candidate reasons when there are several, but does not write the correct command for you.
- Once the definition is valid, TunnelTend saves the registration and attempts to start it and connect the official client to your tunnel.
- If that first start fails, the registration stays. Read the command's error and run `tunneltend doctor my-mcp` before retrying. If it only reports an unhealthy service, [Troubleshooting](https://docs.tunneltend.com/troubleshooting/#registration-was-saved-but-the-service-will-not-start) shows how to inspect more detail.

Useful switches for this first command:

| Switch | Effect |
| --- | --- |
| `--no-start` | Save the registration for inspection without starting it. |
| `--no-source-watch` | Do not restart the service when files in the project change. Project registration watches by default. |
| `--no-autostart` | Do not start this service at later sign-ins. The immediate first start still happens. |

Already running the official client for this tunnel by hand? [Import its alias](https://docs.tunneltend.com/registration/#import-an-existing-official-alias) instead of starting a competing runtime. A command (`--command`), an HTTP endpoint (`--url`) and descriptor files are also covered in [Register a service](https://docs.tunneltend.com/registration/).

## Verify the whole connection

First check the local side. Replace `my-mcp` if you chose a different service ID. Each command prints facts and changes nothing:

```powershell
tunneltend status my-mcp
tunneltend health my-mcp
tunneltend doctor my-mcp
```

Look for your service with `desired=running`. The observed state uses different words: a ready service shows `observed=ready`; `healthy`, `degraded` and `stopped` are other possible observations. In the health output, check `healthy=True` and `ready=True`, then read any diagnostic messages. `doctor` prints `No problems detected.` when it finds nothing to report. If a check reports a problem, start with [Troubleshooting](https://docs.tunneltend.com/troubleshooting/); do not repeatedly register the same service or add `--force` to make the message disappear.

For the saved definition, use `tunneltend service show my-mcp`. Add `--json` to any check when you or an agent need the complete structured fields, including diagnostic repair suggestions. Read the facts, not just the exit code:

| Check | What to establish |
| --- | --- |
| Registration | The target, working directory, tunnel ID or scope, credential reference and policy are the ones you intended. |
| Current state | Running is intended, the host process and the official runtime are observed, and `doctor` reports no blocking configuration or ownership problem. |
| Health and readiness | The configured probes have the expected result. A probe you never configured is not an MCP test. |
| Automation | The intended Startup, Watchdog and Maintenance tasks are present for this installation. Their presence does not prove a later sign-in or recovery cycle. |
| Remote consumer | ChatGPT (or your intended consumer) can actually discover and call a harmless tool exposed by this service. |

The remote check completes the journey. A green local status is evidence that your PC is doing its part, not proof that the whole chain works. Continue below.

## Connect it in ChatGPT

Configure the consumer on OpenAI’s side. For ChatGPT, follow [OpenAI’s current guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for your plan, organization and workspace: that is where the connector is created and where OpenAI states who may use it. TunnelTend does not create connectors and has no view of your ChatGPT settings.

OpenAI’s [connector setup instructions](https://github.com/openai/tunnel-client/blob/master/docs/permissions.md#chatgpt-connector-setup) point to [ChatGPT connector settings](https://chatgpt.com/#settings/Connectors): choose **Connection: Tunnel**, then select your tunnel or paste its ID. Use the same tunnel ID you registered locally. If that choice or tunnel is unavailable, check the workspace and permissions in the official guide or ask your organization's administrator; reinstalling TunnelTend will not grant access.

Choose a harmless task supported by **your** MCP server, with a result you can recognize. For a notes-search server, for example:

1. Pick an existing, non-sensitive note with a distinctive phrase you know.
2. In ChatGPT, enable the connected tool as directed by OpenAI's guide and ask it to find that phrase using your notes tool.
3. Check that ChatGPT actually used the tool and returned the expected note or excerpt. A plausible answer without a tool call is not a connection test.

For another kind of server, choose an equivalent read-only request from its documented tools. TunnelTend does not add a universal test tool. Until a real request succeeds, treat the connection as unverified, even when everything on your PC is green.

**You have reached the first useful result** when that request returns the expected information. You can close the terminal afterwards. Sign-in startup and recovery follow the policies you selected; an awake, online PC and a signed-in Windows session are still required. [Everyday operation](https://docs.tunneltend.com/operations/) explains later starts, stops and updates.

If the local checks pass but ChatGPT cannot connect, follow [Troubleshooting](https://docs.tunneltend.com/troubleshooting/), which separates local causes from upstream scope, credential and connector problems.

## Other ways to install

The released one-line installer above is the normal route. Use these alternatives when you want to inspect the download yourself or work from source. If you have already installed, you can skip this section.

### Download and verify yourself

Get `tunneltend-<version>.zip` and `tunneltend-<version>.zip.sha256` from the **Assets** list on the [latest release](https://github.com/Wolfsblvt/tunneltend/releases/latest) and save both in one folder. Choose the TunnelTend release ZIP, not GitHub's **Source code** download. In PowerShell 7, move to the download folder with `Set-Location 'C:\path\to\your\downloads'`, replacing that example with its actual path.

The script below compares the ZIP's SHA-256 checksum with the published one and stops on a mismatch before anything is extracted or run; otherwise it extracts and starts the installer. Use the version you downloaded:

```powershell
$zip = '.\tunneltend-1.0.1.zip'
$expected = ((Get-Content "$zip.sha256" -Raw) -split '\s+' | Select-Object -First 1).ToLowerInvariant()
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expected -notmatch '^[0-9a-f]{64}$' -or $actual -ne $expected) {
  throw "Checksum mismatch for $zip. Expected $expected but downloaded $actual. Nothing was extracted. Delete the download and get it again."
} else {
  Expand-Archive $zip -DestinationPath .\tunneltend
  .\tunneltend\Install-TunnelTend.cmd
}
```

If it refuses, delete the download and get it again. Do not extract a ZIP that failed the comparison.

### From source

For contributors or readers who deliberately want the source tree, cloning is supported too. This route requires Git; the released routes above do not:

```powershell
git clone https://github.com/Wolfsblvt/tunneltend.git
Set-Location .\tunneltend
.\Install-TunnelTend.cmd
```

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

Reinstallation preserves saved autostart, automatic-update and watchdog choices, scope defaults, credential reference and official-client location when their options are omitted, including retained state after uninstall. Questions start from saved choices; explicit options take precedence. New state still uses the autonomous defaults. When calling the script directly in a PowerShell session, `-DisableAutostart:$false` enables autostart explicitly, and `-OrganizationId @()` clears the default organization list.

If a later installation step fails, the installer restores its own settings changes and the previous program payload while preserving registrations, session intent and unrelated settings. If another writer changed the same field, recovery leaves that value intact and reports the conflict and an `installer-recovery-<id>.json` record in the selected state directory. Keep the record and inspect the named fields with `tunneltend config show`. Use explicit installer options on the next attempt to select any values you want changed; do not replace the registry with the recovery record. Optional registration, alias import and official-client updates retain their own effects; this is not a whole-fleet rollback.

## From here

- [Everyday operation](https://docs.tunneltend.com/operations/): deliberate stops, what the watchdog may restart, source watching, client updates, and [how to uninstall](https://docs.tunneltend.com/operations/#uninstall) while keeping your registrations.
- [Install with an agent](https://docs.tunneltend.com/install-with-an-agent/): hand this same journey to a local coding agent with explicit inputs and completion evidence.
