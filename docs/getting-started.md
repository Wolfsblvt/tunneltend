# Getting started with TunnelTend

## Meaning

This guide owns installation, policy selection, credential references, the first registered service, local-agent setup, and uninstall for the source preview. It describes the supported command path without claiming completed Windows lifecycle qualification or a published release.

## Before installation

Use Windows 11 and PowerShell 7.4 or newer. Clone this repository and run installation from its root. The official client is acquired separately from `openai/tunnel-client` and verified; no OpenAI binary is bundled.

An operational tunnel also needs an existing OpenAI tunnel setup: an appropriate runtime/admin credential reference and organization/workspace scope or an existing tunnel ID. Do not put raw credentials in arguments, descriptors, registry files, or diagnostics.

## Guided installation

```powershell
.\Install-TunnelTend.cmd
```

The recommended defaults enable registered-service startup at logon, watchdog reconciliation every two minutes, and daily verified official-client updates. Open a new terminal after installation so the user PATH change is visible.

Unattended tasks use TunnelTend's native GUI launcher to prevent console creation. Installation and reinstallation select a normal PowerShell 7.4+ installation or the current user's WindowsApps alias, rather than capturing the installer's interpreter. A portable installation can be selected with `-PowerShellPath`; the installation receipt preserves that selection for later re-registration. Distributed packages include the launcher. Installing directly from source builds it with Windows' existing .NET Framework compiler; no separate .NET SDK is required.

## Deterministic installation

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Install-TunnelTend.ps1 -NonInteractive
```

Service selection is explicit. Add `-AllManagedAliases` to import all existing official aliases, `-AutostartAliases alias-one,alias-two` to select aliases, or `-RegisterPath C:\src\my-mcp` to register a project during installation.

Useful installation switches:

| Switch | Meaning |
| --- | --- |
| `-DisableAutostart` | Keep service startup manual. |
| `-DisableAutoUpdate` | Disable automatic official-client updates. |
| `-DisableWatchdog` | Disable scheduled recovery. |
| `-OrganizationId org_...` / `-WorkspaceId ws_...` | Set default tunnel scope. |
| `-RuntimeKeyRef env:CONTROL_PLANE_API_KEY` | Select a credential reference. |
| `-TunnelClientPath C:\tools\tunnel-client.exe` | Use an existing official client. |
| `-PowerShellPath C:\Tools\PowerShell\pwsh.exe` | Select a portable PowerShell 7.4+ installation for unattended operations. |
| `-InstallRoot` / `-StateRoot` | Select explicit program and state paths. |

Program and state roots must be different directories. A dedicated nested state path such as `C:\Tools\TunnelTend\data\state` is supported; do not place state in a program payload directory such as `src` or `official-client`. Reinstallation preserves nested state at the selected coordinate. When `-StateRoot` is omitted, reinstall and uninstall use the selected installation's `install.json` receipt before falling back to the default state root. An invalid receipt requires an explicit `-StateRoot` override.

Secret references have these forms:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

The referenced environment variable or file must be available to the account running the automation. TunnelTend does not create or manage the external credential.

## Register and observe

```powershell
tunneltend service register C:\src\my-mcp
tunneltend status --json
tunneltend health --json
tunneltend doctor --json
tunneltend automation status --json
```

Registration normally starts the service. If startup fails, the registration survives and reports its failure. Read `doctor` before retrying. A process being alive, a healthy tunnel, MCP readiness, and a successful call from your remote consumer are separate observations.

See [registration](registration.md) for explicit command and URL targets, [operations](OPERATIONS.md) for lifecycle and recovery, and the [CLI reference](cli-reference.md) for the command grammar.

## Install with a local agent

Give a capable local coding agent the repository URL and this request, adding the project paths and policy you want:

```text
Clone https://github.com/Wolfsblvt/tunneltend.git and read AGENTS.md completely.
Use docs/getting-started.md to install TunnelTend for the current Windows user
with the recommended defaults. Register the MCP projects I name. Keep secrets
as env: or file: references and preserve process ownership and release
verification. Do not elevate unless the selected installation boundary needs it.

Finish with status, health, doctor, and automation status using --json.
Report what is registered, what starts at logon, what automation was installed,
and which lifecycle or remote-consumer behavior remains unobserved.
```

Plain-language constraints such as “disable automatic client updates” or “autostart only alias-one” select supported policy; they do not require a second setup mechanism.

## Uninstall or preserve state

Run from the source checkout, supplying `-InstallRoot` if you selected a custom program directory. The installation receipt resolves a custom state root unless you explicitly override it:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Uninstall-TunnelTend.ps1 -Confirm:$false
```

Normal uninstall removes tasks, program files, and the managed PATH entry while preserving registered state. `-RemoveOfficialClient` also removes a managed client inside the installation. `-PurgeState` explicitly removes the selected registry, logs, and backups; use it only when those are disposable or already preserved.

For state nested below the installation, reinstall and normal uninstall preserve its entire dedicated top-level container, including sibling state and junction targets. `-SkipPath` leaves user PATH unchanged, matching the installer's option for installations without a PATH entry.
