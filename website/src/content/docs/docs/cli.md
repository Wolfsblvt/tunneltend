---
title: "CLI reference"
description: "Every tunneltend command with what it reads, plans or changes, the global options, the JSON output envelope and the exit codes."
---

Every command is `tunneltend` followed by a verb. Commands that only read never save anything; commands that change state say so in their name or need an explicit flag. `tunneltend --help` prints the same grammar in the terminal.

For your first connection, follow [Get started](/docs/getting-started/). This page is a reference: `ID`, `PATH`, `FILE` and `URL` stand for your values; square brackets mark optional parts, and `...` means a value may be repeated. Do not type the brackets or the dots.

**Reads** means read-only: it may probe processes and endpoints but does not persist observations, budgets or repairs. **Plans** means it computes and shows what would change, and changes nothing. **Changes** means it mutates desired state, running processes, files or Windows tasks.

## Fleet facts, planning and convergence

| Command | Kind | What it does |
| --- | --- | --- |
| `tunneltend status [SERVICE...]` | Reads | Desired and observed facts per service, the official client version, the Windows tasks and the current session. |
| `tunneltend health [SERVICE...]` | Reads | Live probes: process, official runtime, configured health and readiness endpoints. |
| `tunneltend doctor [SERVICE...]` | Reads | Diagnostic codes and messages, or `No problems detected.` Add `--json` for structured repair suggestions. |
| `tunneltend repair [SERVICE...]` | Plans | The repair it would make. |
| `tunneltend repair [SERVICE...] --apply [--force]` | Changes | Applies a freshly computed repair plan. `--force` can bypass the recovery backoff for this manual action. |
| `tunneltend reconcile [SERVICE...] --plan` | Plans | What converging every selected service to its desired state would change. |
| `tunneltend reconcile [SERVICE...] [--context CONTEXT]` | Changes | Converges to desired state. Context is `manual` (default), `startup`, `watchdog` or `maintenance`. |

Without `SERVICE` arguments a command covers every registered service. An applied manual repair or reconciliation can resume an enabled, desired-running service that is inactive or suppressed for this session; see [Stop a service on purpose](/docs/operations/#stop-a-service-on-purpose).

## Services

### Register, inspect, remove, import

| Command | Kind | What it does |
| --- | --- | --- |
| `tunneltend service register PATH [OPTIONS]` | Changes | Registers a project folder, using its descriptor or conservative discovery, and starts it. |
| `tunneltend service register --command FILE [--arg VALUE...] [--working-directory PATH] [OPTIONS]` | Changes | Registers an explicit stdio launch command and starts it. |
| `tunneltend service register --url URL [--health-url URL] [OPTIONS]` | Changes | Registers an already reachable HTTP MCP endpoint and connects it. |
| `tunneltend service list` | Reads | Every registered service and its ID. |
| `tunneltend service show ID` | Reads | The complete saved definition of one service. |
| `tunneltend service remove ID [--keep-running]` | Changes | Stops and unregisters the service; `--keep-running` leaves its processes up. |
| `tunneltend service import [ALIAS...] [--force]` | Changes | Imports existing official client aliases; with no alias, all available ones. `--force` deliberately adopts an alias that already exists upstream. |

Registration options: `--id`, `--alias`, `--tunnel-id`, `--organization-id` (repeatable), `--workspace-id` (repeatable), `--runtime-key-ref`, `--admin-profile`, `--working-directory` for command targets, `--health-url`, `--ready-url`, `--no-start`, `--no-autostart`, `--no-watchdog`, `--no-source-watch`, `--disabled`, and `--force` for deliberate replacement. [Register a service](/docs/registration/) explains argument quoting and the difference between the immediate first start and later sign-in policy.

### Intent and lifecycle

| Command | Kind | What it does |
| --- | --- | --- |
| `tunneltend service start ID` | Changes | Enables, restores running intent, activates for this session, starts. |
| `tunneltend service stop ID` | Changes | Saves durable stopped intent and stops. |
| `tunneltend service stop ID --session-only` | Changes | Suppresses automatic startup and recovery until the next sign-in; durable intent is unchanged. |
| `tunneltend service restart ID` | Changes | Restores running intent and restarts. |
| `tunneltend service enable ID` | Changes | Enables and starts. |
| `tunneltend service disable ID` | Changes | Stops and disables. |
| `tunneltend service autostart ID on\|off` | Changes | Sign-in startup policy; the current runtime is not touched. |
| `tunneltend service watchdog ID on\|off` | Changes | Watchdog recovery policy for this service. |

## Official client

| Command | Kind | What it does |
| --- | --- | --- |
| `tunneltend client status` | Reads | Installed client path, version and update standing. |
| `tunneltend client update --check-only` | Reads | Whether a verified newer stable release is available, without replacing anything. |
| `tunneltend client update [--force]` | Changes | Verified, staged, backed-up replacement of OpenAI's client with fleet restoration and rollback on failure. |
| `tunneltend client rollback [--backup PATH]` | Changes | Restores the previous client from the most recent or the named backup. |

## Windows automation

| Command | Kind | What it does |
| --- | --- | --- |
| `tunneltend automation status` | Reads | The three Scheduled Tasks: desired, installed, state, last and next run. |
| `tunneltend automation install` | Changes | Registers the tasks for the current user. |
| `tunneltend automation uninstall` | Changes | Removes the tasks. |
| `tunneltend automation startup [--skip-update]` | Changes | Runs the Startup work now: new session, optional client update check, autostart activation, reconciliation. Clears the previous session's suppressions. |
| `tunneltend automation watchdog` | Changes | Runs one Watchdog pass now. |
| `tunneltend automation maintenance [--skip-client-update] [--skip-service-updates]` | Changes | Runs one Maintenance pass now. |

[The three Windows tasks](/docs/operations/#the-three-windows-tasks) explains what each pass may do.

## Setup, configuration and version

| Command | Kind | What it does |
| --- | --- | --- |
| `tunneltend setup [--autostart on\|off] [--auto-update on\|off] [--watchdog on\|off]` | Changes | Changes the automation policy and task registration. Also accepts `--organization-id`, `--workspace-id`, `--runtime-key-ref`, `--import-all`, `--import-alias` and `--non-interactive`. |
| `tunneltend config show` | Reads | The current configuration. |
| `tunneltend config set PATH VALUE` | Changes | One configuration value, for example `settings.automation.watchdog false`. |
| `tunneltend version` | Reads | The installed TunnelTend version. |

First-time program and official client acquisition belong to the installer, not to `setup`; see [Choose installation policy](/docs/getting-started/#choose-installation-policy). Prefer installer switches and service commands over `config set`.

## Global options

| Option | Effect |
| --- | --- |
| `--state-root PATH` | Use a non-default state directory instead of `%LOCALAPPDATA%\TunnelTend\state`. |
| `--json` | Emit the structured envelope instead of plain text. It changes the format, never whether a command mutates. |
| `--help` | Show the command grammar. |

## JSON output

With `--json`, every command prints one versioned envelope: `status`, `data`, `diagnostics` and, where applicable, proposed `actions`, so a script or a local coding agent reads the same facts you would. The exact shape is the [output schema](https://github.com/Wolfsblvt/tunneltend/blob/main/schemas/output.schema.json).

```json
{
  "schema_version": 1,
  "product": "tunneltend",
  "command": "status",
  "status": "ok",
  "data": { "services": [] },
  "diagnostics": [],
  "actions": []
}
```

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | Command completed; status may be `ok`, `noop`, `planned` or `changed`. |
| 2 | Command completed with degraded or error facts. |
| 4 | Command failed validation or execution. |
| 10 | Launcher or install dependency failure. |

Applied repair, reconciliation and the automation passes combine their per-service and update outcomes. One failed operation gives a degraded status and exit code 2 while the successful results are kept. A normal recovery deferral is `noop` (or `changed` when other work succeeded) with exit code 0 and an `operation.skipped` diagnostic; it does not claim the deferred service converged. Startup's new session counts as a change. Maintenance with nothing to update or reconcile returns `noop`.
