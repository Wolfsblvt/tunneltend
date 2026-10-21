# Operations

Control what runs, understand what the watchdog may restart, and choose how updates happen. Use [getting started](getting-started.md) for installation and [troubleshooting](troubleshooting.md) when an observation does not match your intent.

## Automation modes

TunnelTend uses current-user Windows Scheduled Tasks under `\TunnelTend\`. They run with the signed-in user's interactive, limited-privilege context. This is sign-in automation, not a system service that makes MCP available before login. The default configuration does not wake the computer. Tasks use `StartWhenAvailable` and ignore overlapping instances; neither setting establishes availability while asleep, signed out, or offline.

Scheduled actions run through the product-owned `TunnelTend.TaskHost.exe` GUI executable. It creates PowerShell without a console, preserves command streams and exit status, and terminates its script on cancellation. Deliberately detached hosts keep their independent lifetime after normal task completion or cancellation. Configured PowerShell child processes use non-interactive, profile-free hidden launches; script arguments remain separate from interpreter options.

The stable PowerShell selection is stored in `install.json`. When the selection is a WindowsApps alias, owned child processes resolve its current package executable before launch so their persisted PID/path/generation identity refers to the actual process. Task and installation configuration keep the stable alias across package updates.

### Startup

The Startup task runs after logon with a configurable delay. It creates a new session boundary, optionally checks the official client for a due verified update, activates eligible autostart services, reconciles them, and verifies observations.

A service with autostart disabled is not activated by sign-in startup. A new logon clears prior session suppression by design; durable stopped or disabled state remains. The Startup task can still be installed with service autostart off when the watchdog needs a new session boundary.

Running `tunneltend automation startup` manually also establishes a fresh session and clears the previous session's suppression. It is a consequential action, not a harmless task-registration check.

### Watchdog

The Watchdog task runs every two minutes by default. It can observe registered services whether or not they are active, record source state, and stop an unwanted observed runtime. It starts or recovers a service only when the service is eligible for the current session and the recovery policy permits it.

It never resurrects disabled, desired-stopped, or current-session-suppressed services.

### Maintenance

Maintenance runs daily at 05:15 with up to twenty minutes of randomized delay by default. Official-client maintenance restores the intended active fleet. Explicitly enabled application-update commands have a separate selection rule in this release: they can run for a stopped or disabled registration. Read [source watching and application updates](#source-watching-and-application-updates) before enabling that policy.

## Ordinary operator commands

```powershell
tunneltend status
tunneltend health
tunneltend doctor
tunneltend repair
tunneltend reconcile --plan
```

Apply changes deliberately:

```powershell
tunneltend repair --apply
tunneltend reconcile
tunneltend service restart <id>
tunneltend client update
```

Use `--json` when another tool will consume the result.

## Recovery standing

A service must be enabled, desired-running, active in the current session, not suppressed, configuration-ready, and within its retry budget before watchdog recovery. Default policy allows four attempts within a rolling twenty-minute window, with exponential backoff from ten seconds to five minutes. A running but unhealthy service normally needs two unhealthy observations; a missing runtime can be started without waiting for that threshold.

Exhaustion is a visible diagnostic condition, not a permanent lockout. Attempts can become eligible again as older attempts leave the rolling window. Inspect `doctor`, logs, command paths, credential references, and tunnel scope before forcing another attempt. The watchdog enforces this durable recovery budget; do not assume every manual, startup, or maintenance action is governed by the same retry window.

Health and readiness are separate. Startup waits for the required runtime and configured health/readiness conditions. Watchdog recovery uses health; a readiness-only failure does not by itself select the same restart action. HTTP probes check endpoint responses, not an MCP tool invocation from a consumer.

## Manual intent

Replace `my-mcp` with the registered service ID:

| Command | Intent and effect |
| --- | --- |
| `service stop my-mcp` | Save durable stopped intent and stop the service. Later sign-in startup and the watchdog respect it. |
| `service stop my-mcp --session-only` | Keep durable intent but suppress this session's automatic startup/recovery for the service. |
| `service start my-mcp` | Enable the service, restore running intent, activate it for this session, and start it. |
| `service restart my-mcp` | Restore running intent and restart, including after a deliberate stop. |
| `service enable my-mcp` | Enable and start the service; it is not only a flag change. |
| `service disable my-mcp` | Stop and disable the service. |
| `service autostart my-mcp off` | Change future sign-in policy without stopping the current runtime. |
| `service watchdog my-mcp off` | Change the service's watchdog policy. |

Prefix these commands with `tunneltend`. A failed start/restart retains running intent; a failed stop retains the requested stopped or suppressed intent. Inspect the resulting observation rather than assuming a failed command had no effect.

**Explicit manual repair is different from the watchdog.** `repair --apply` and the default manual `reconcile` consider enabled, desired-running registrations without requiring current-session activity or respecting session-only suppression. They can therefore resume a temporarily stopped service or one not activated by sign-in startup. They respect durable stopped and disabled state. Preview with `repair my-mcp` or `reconcile my-mcp --plan`; apply deliberately to the selected service. Applying repair computes a fresh plan, not a frozen copy of an earlier preview.

To keep a service stopped through both routine automation and later manual convergence, use the ordinary durable stop. To remove its registration, use `service remove ID`; `--keep-running` deliberately leaves the runtime without TunnelTend supervision.

## Source watching and application updates

Project-path registration enables source watching by default unless the descriptor or `--no-source-watch` disables it. Command-only and URL-only registrations do not infer a project path. Watching establishes a baseline, detects a changed fingerprint, and waits for a stable candidate before restarting. The default debounce is ten seconds, but observation happens on the watchdog cadence; it is not a promise to restart ten seconds after a save.

Includes and exclusions control what is watched. Generated, dependency, VCS, state, log, and likely secret paths are excluded by default. Watching does not run a build, install dependencies, pull from Git, or deploy anything.

An application-update command is separate and disabled by default. It runs only when explicitly configured and enabled. In this release, maintenance considers **all update-enabled registrations**, including disabled, desired-stopped, and session-suppressed ones. Those states do not disable the update command. Its stop/start decision uses enabled, desired-running, and not-suppressed state, but does not require membership in the session's active-service list; an update can activate such a service.

Keep application updates disabled unless that behavior matches your workflow. Manage the explicit update policy in the service definition; do not treat `service stop` as a pause button for application maintenance. See [project descriptors](registration.md#use-a-project-descriptor).

## Update operation

Client update preparation occurs while the current fleet remains running. Downtime begins only after release metadata, checksum, extraction, payload, version, and capability preconditions pass. TunnelTend snapshots intended state, stops affected runtimes, replaces the client, verifies it, and restores services. Failure invokes rollback when a backup exists.

Update and explicit `client rollback` replace only the configured executable. An external path keeps its selected directory and filename; unrelated sibling files are neither backed up nor replaced. New backups contain the executable and a manifest. Existing directory backups remain usable, but only their selected executable is restored. `client restore` is a compatibility alias for rollback.

The previous executable remains recoverable until installed-client capability checks and restoration of all intended active services succeed. Restoration attempts every eligible service even if one fails, and never reactivates current-session-suppressed services. A failure restores previous bytes and retries the intended fleet. If a possibly started runtime refuses a safe stop, replacement is refused and the error names the retained fallback file for recovery; ownership protections remain in force.

Automatic downgrade is refused. TunnelTend always requires a published SHA-256 digest/checksum for acquisition. Public configuration cannot enable unverified automatic updates; valid code signatures are an additional check, not a substitute for the published checksum. The bundled updater's separate manual emergency switch does not override TunnelTend's automatic requirement.

Use `tunneltend client update --check-only` to inspect an available client update without replacing the executable. `tunneltend client rollback` selects a backup; `--backup PATH` selects one explicitly. Capability checks verify the adapter's expected command surface, not every upstream behavior or every service's compatibility.

This update policy covers the official client. TunnelTend's own source-preview installation is updated by obtaining the intended source and rerunning its installer; project dependency updates are not inferred. See [reinstallation](getting-started.md#custom-paths-and-reinstallation).

## Official alias admission

No-start registration works without an installed or reachable official client. Before first start, TunnelTend checks whether the alias already exists. An existing upstream alias must be imported deliberately with `tunneltend service import <alias> --force`; this replaces its registered definition with the upstream target. The import preserves the existing registered service ID when that ID differs from the alias. Ordinary registration and `--force` cannot give a second service control of an already registered alias.

Command registrations resolve their executable relative to the registered working directory and launch the official client there. Native detachment inherits that directory; each TunnelTend restart supplies it again, regardless of the caller's current folder.

## State and logs

Default state root:

```text
%LOCALAPPDATA%\TunnelTend\state
```

Important paths:

- `registry.json`: desired state and policy.
- `runtime.json`: observations, session intent, fingerprints, and recovery accounting.
- `logs\`: TunnelTend JSONL events.
- `backups\`: official-client rollback snapshots.
- `work\`: temporary operation state.

See [logging](LOGGING.md) for event contents and [privacy and data](PRIVACY-AND-DATA.md) for data handling.

## Failure handling

One service failure does not stop the remainder of a fleet pass. A mutating command records per-service results and returns degraded status when appropriate. Timeout or failure does not prove no effect occurred; rerun read-only observation before repeating a consequential operation.

When process ownership evidence does not match, TunnelTend refuses termination. Resolve the stale record or use official runtime operations; never fall back to process-name killing.

## Uninstall and recovery

Normal uninstall removes Scheduled Tasks and program files, including the default client inside the installation, while preserving state. It attempts to stop registered services unless `-KeepRunning` is selected. Inspect warnings: uninstall's summary is not proof that every runtime stopped. An external client installation is left alone. Optional state purge is destructive and uses PowerShell confirmation semantics. See [uninstall options](getting-started.md#uninstall-or-preserve-state).

A preserved state root may be adopted by a later installation. Verify paths and run `doctor` before restoring autonomous tasks.
