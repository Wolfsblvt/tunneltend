---
title: "Everyday operation"
description: "Control what runs, understand what the three Windows tasks may do, stop a service on purpose, handle source watching and official client updates, and uninstall without losing your registrations."
---

After the first setup, most days need nothing from you. This page is for the days that do: a service you want paused, a client update you want to inspect, a repair you want to preview before it happens, or TunnelTend itself that you want gone.

## The three Windows tasks

TunnelTend runs through current-user Windows Scheduled Tasks under `\TunnelTend\`. They run as you, with your ordinary limited privileges, only while you are signed in. This is sign-in automation, not a system service: nothing is available before you log in, and the default configuration does not wake the computer. Tasks use `StartWhenAvailable` and skip overlapping instances; neither makes a sleeping, signed-out or offline PC serve anything.

| Task | Runs | May do |
| --- | --- | --- |
| Startup | After you sign in, with a configurable delay. | Opens a new session, optionally checks for a due verified client update, activates services whose autostart is on, reconciles them and verifies the result. |
| Watchdog | Every two minutes by default. | Observes every registered service, records source state, stops an unwanted runtime, and starts or recovers a service that is eligible for this session and within its recovery policy. |
| Maintenance | Daily at 05:15 with up to twenty minutes of random delay by default. | Checks for a verified official client update, restores the intended fleet afterwards, and runs any application-update commands you explicitly enabled. |

Scheduled actions run through TunnelTend's own `TunnelTend.TaskHost.exe`, which starts PowerShell without a console window, keeps output and exit status, and stops its script if the task is cancelled. Nothing flashes on your screen.

A service with autostart off is not started by the Startup task. A new sign-in clears the previous session's suppressions by design; a durable stop and a disabled flag stay as they were.

Inspect, install or remove the tasks with:

```powershell
tunneltend automation status
tunneltend automation install
tunneltend automation uninstall
```

You can also run a task's work by hand: `tunneltend automation startup`, `tunneltend automation watchdog`, `tunneltend automation maintenance`. Running `automation startup` opens a fresh session and clears the previous session's suppressions, so treat it as a real action, not a check.

## Look before you change anything

```powershell
tunneltend status
tunneltend health
tunneltend doctor
tunneltend repair
tunneltend reconcile --plan
```

None of these saves state. `repair` without `--apply` shows the repair it would make; `reconcile --plan` shows what converging every service to its desired state would change. Then act deliberately:

```powershell
tunneltend repair --apply
tunneltend reconcile
tunneltend service restart my-mcp
tunneltend client update
```

Add `--json` to any command when another program will read the result. Applying a repair computes a fresh plan at that moment, not a frozen copy of the preview you looked at.

## Start, stop, enable and policy commands

Replace `my-mcp` with your service ID (`tunneltend service list` shows them).

| Command | Intent and effect |
| --- | --- |
| `tunneltend service start my-mcp` | Enables the service, restores running intent, activates it for this session and starts it. |
| `tunneltend service stop my-mcp` | Saves durable *stopped* intent and stops the service. Later sign-ins and the watchdog respect it. |
| `tunneltend service stop my-mcp --session-only` | Keeps durable intent but suppresses automatic startup and recovery until your next sign-in. |
| `tunneltend service restart my-mcp` | Restores running intent and restarts, also after a deliberate stop. |
| `tunneltend service enable my-mcp` | Enables *and starts* the service; it is not only a flag. |
| `tunneltend service disable my-mcp` | Stops and disables the service. |
| `tunneltend service autostart my-mcp off` | Changes future sign-in behavior without touching the current runtime. `on` turns it back on. |
| `tunneltend service watchdog my-mcp off` | Turns watchdog recovery off for this service. `on` turns it back on. |

A failed start or restart keeps the running intent; a failed stop keeps the requested stopped or suppressed intent. Check the observation afterwards rather than assuming a failed command changed nothing.

## Stop a service on purpose

There are two kinds of stop, and the difference matters.

**A durable stop** is `tunneltend service stop my-mcp`. The service stays stopped through every later sign-in, every watchdog pass and manual repair or reconciliation, until you start, restart or enable it again. Use it when you mean "stay down".

**A session-only stop** is `tunneltend service stop my-mcp --session-only`. The watchdog leaves the service alone for the rest of this sign-in. Your next sign-in, an explicit `start` or `restart`, or an applied manual `repair`/`reconcile` can bring it back. Use it when you mean "not right now".

:::caution
`repair --apply` and a plain `reconcile` consider every enabled, desired-running service, including one you stopped with `--session-only` and one sign-in startup did not activate. They respect a durable stop and a disabled flag. Preview with `tunneltend repair my-mcp` or `tunneltend reconcile my-mcp --plan`, then apply to the service you mean.
:::

To take a service away from TunnelTend entirely, use `tunneltend service remove my-mcp`. Add `--keep-running` to withdraw supervision but leave the processes up. See [Register a service](/docs/registration/#verify-or-remove-a-registration).

## When recovery holds back

The watchdog recovers a service only when it is enabled, desired running, active in this session, not suppressed, configuration-ready and within its retry budget. The default budget is four attempts in a rolling twenty-minute window with backoff growing from ten seconds to five minutes. A running but unhealthy service normally needs two unhealthy observations first; a missing runtime can be started at once.

An exhausted budget shows up in `doctor` and is not a lockout: attempts become eligible again as older ones leave the window. A deferred recovery is reported as `operation.skipped`, not as a failure. Before forcing another attempt, read `doctor`, the [logs](/docs/logging/), the command path, the credential reference and the tunnel scope. Health and readiness are separate: startup waits for both as configured, the watchdog recovers on health, and a readiness-only failure does not by itself trigger a restart. HTTP probes check a response, not a tool call from ChatGPT.

## Source watching and application updates

Project registrations watch their folder by default; `--no-source-watch` or a descriptor policy turns that off. Command-only and URL-only registrations have no folder to watch. Watching records a baseline, notices a changed fingerprint, and restarts once the change has been stable for the debounce period. The default debounce is ten seconds, but observation happens on the watchdog cadence, so a restart is not promised ten seconds after you save.

Includes and exclusions decide what is watched. Generated, dependency, version-control, state, log and likely secret paths are excluded by default. Watching never runs a build, installs dependencies, pulls from Git or deploys.

An **application-update command** is a different thing: a command you define in the service definition that updates the application itself. It is off by default and runs only when you explicitly configure and enable it. In this release, maintenance considers every update-enabled registration, including disabled, desired-stopped and session-suppressed ones; those states do not pause the update command. Whether the update then stops and starts the service follows enabled, desired-running and not-suppressed state, and an update can activate such a service.

:::note
Keep application updates off unless that behavior matches how you work. Manage the policy in the service definition; `service stop` is not a pause button for application maintenance. See [Use a project descriptor](/docs/registration/#use-a-project-descriptor).
:::

## Official client updates

OpenAI's tunnel client is a separate program with its own releases. With the recommended defaults, TunnelTend checks daily for a newer stable release and installs it only after verification.

```powershell
tunneltend client status
tunneltend client update --check-only
tunneltend client update
tunneltend client rollback
tunneltend client rollback --backup C:\path\to\backup
```

`client update --check-only` tells you what is available without replacing anything. A real update prepares everything while your services keep running: release metadata, the published checksum, extraction, payload, version and capability checks all have to pass before any downtime begins. Then TunnelTend snapshots the intended fleet, stops the affected runtimes, replaces the client, verifies it and restores the services. If replacement or restoration fails and a backup exists, it rolls back. `client restore` is an older alias for `client rollback`.

Only the configured executable is replaced or restored; an external client keeps its folder and filename, and unrelated sibling files are untouched. The previous executable stays recoverable until the new client passes its capability checks and every intended active service is back. Restoration tries every eligible service even if one fails and never reactivates a service you stopped with `--session-only`. If a runtime refuses a safe stop, replacement is refused and the error names the retained fallback file.

Automatic downgrades are refused. A published SHA-256 digest is always required; nothing in public configuration can switch verification off, and a valid code signature is an extra check, not a replacement. Capability checks confirm the commands TunnelTend relies on, not every upstream behavior or every service's compatibility.

## Where the limits of --force are

`--force` can skip a confirmation, a debounce or a recovery backoff where that is documented. It never bypasses process identity, secret-reference validation, organization/workspace scope checks, release digest verification or archive safety. If TunnelTend cannot prove it owns a process, it refuses to stop it, with or without `--force`.

## Updating TunnelTend itself

`client update` updates OpenAI's client, not TunnelTend. To update TunnelTend, get the newer release and run its installer for the same installation: either the one-line installer on the [home page](/#install), or download, verify and run `scripts\Install-TunnelTend.ps1` from the extracted release. Read the release notes first and keep your state. Reinstallation preserves the selected state root and a dedicated nested state folder. See [Choose installation policy](/docs/getting-started/#choose-installation-policy).

## Where things live

```text
%LOCALAPPDATA%\TunnelTend\state
```

| Path | Holds |
| --- | --- |
| `registry.json` | Desired state and policy. |
| `runtime.json` | Observations, session intent, source fingerprints, recovery accounting. |
| `logs\` | TunnelTend's JSONL event log. |
| `backups\` | Official client rollback snapshots. |
| `work\` | Temporary operation state. |

[Logging](/docs/logging/) explains the events; [Privacy and data](/docs/privacy-and-data/) explains what is and is not in these files.

## When something fails

One failing service does not stop the rest of a fleet pass. A mutating command records a result per service and returns a degraded status when one of them failed. A timeout or an error does not prove nothing happened: run a read-only observation before repeating anything consequential.

When the recorded process does not match what is running now, TunnelTend refuses to terminate it. Resolve the stale record or use the official client's own runtime commands. It never falls back to killing by process name. [Troubleshooting](/docs/troubleshooting/) walks through the common cases.

## Uninstall

Run the uninstaller from the extracted release or source folder you installed from. Add `-InstallRoot` if you chose a custom program folder; its receipt resolves the saved state root unless you override it.

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Uninstall-TunnelTend.ps1 -Force
```

Normal uninstall removes the three Scheduled Tasks, tries to stop the registered services for this session, removes the program folder and the PATH entry, and **keeps your state**: registrations, logs and backups stay where they are. The official client inside the installation goes with the program folder; an external client is left alone. Your project files, the tunnel objects at OpenAI and your credential source are never touched. Read the warnings: the summary alone does not prove that every runtime stopped.

| Switch | Effect |
| --- | --- |
| `-KeepRunning` | Leave the managed runtimes running while TunnelTend's supervision is removed. |
| `-RemoveOfficialClient` | Explicitly remove the configured client file when it is inside the installation and outside state. At the default location the normal cleanup already removes it. External client paths are never removed. |
| `-PurgeState` | Deliberately delete the registry, logs and backups. Use it only when that state is disposable or already saved elsewhere. |
| `-SkipPath` | Leave your user PATH unchanged. |

State nested below the installation keeps its own top-level folder, including any sibling state. A later installation can adopt preserved state; check its paths and run `tunneltend doctor` before trusting the tasks again.
