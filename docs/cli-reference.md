# CLI reference

Look up command grammar, read versus mutation semantics, and exit behavior. Use `tunneltend --help` for executable help and [getting started](getting-started.md) for the first installation.

## Fleet facts

```text
tunneltend status [SERVICE...] [--json]
tunneltend health [SERVICE...] [--json]
tunneltend doctor [SERVICE...] [--json]
```

These commands are read-only. They may perform network and process probes but do not save observations.

## Planning and convergence

```text
tunneltend repair [SERVICE...] [--apply] [--force]
tunneltend reconcile [SERVICE...] [--plan] [--context CONTEXT] [--force]
```

`repair` without `--apply` and `reconcile --plan` are read-only. Context is one of `manual`, `startup`, `watchdog`, or `maintenance`; the default is `manual`. An applied manual repair or reconciliation can resume an enabled, desired-running service that is inactive or temporarily suppressed. See [manual intent](OPERATIONS.md#manual-intent).

## Registry

```text
tunneltend service register PATH [OPTIONS]
tunneltend service register --command FILE --arg VALUE... [OPTIONS]
tunneltend service register --url URL [OPTIONS]
tunneltend service list
tunneltend service show ID
tunneltend service remove ID [--keep-running]
tunneltend service import [ALIAS...] [--force]
```

Registration options include `--id`, `--alias`, `--tunnel-id`, repeated `--organization-id`, repeated `--workspace-id`, `--runtime-key-ref`, `--admin-profile`, `--working-directory` for command targets, `--health-url`, `--ready-url`, `--no-start`, `--no-autostart`, `--no-watchdog`, `--no-source-watch`, `--disabled`, and `--force` for deliberate replacement. See [registration](registration.md) for argument quoting and the distinction between immediate startup and later sign-in policy.

Import without an alias selects the available official aliases. `--force` allows deliberate replacement/adoption of an existing definition; inspect the upstream target first.

## Intent and lifecycle

```text
tunneltend service start ID
tunneltend service stop ID [--session-only]
tunneltend service restart ID
tunneltend service enable ID
tunneltend service disable ID
tunneltend service autostart ID on|off
tunneltend service watchdog ID on|off
```

An ordinary stop is durable. `--session-only` is temporary. Start, restart, and enable restore running intent; enable also starts the service. Autostart policy changes do not stop the current runtime.

## Official client

```text
tunneltend client status
tunneltend client update [--check-only] [--force]
tunneltend client rollback [--backup PATH]
```

## Windows automation

```text
tunneltend automation install
tunneltend automation uninstall
tunneltend automation status
tunneltend automation startup
tunneltend automation watchdog
tunneltend automation maintenance
```

`automation startup` creates a fresh session and clears previous session suppression. `automation install` changes task registration; `automation status` inspects it. `startup` accepts `--skip-update`; `maintenance` accepts `--skip-client-update` and `--skip-service-updates`. See [operations](OPERATIONS.md#automation-modes).

## Setup policy

```text
tunneltend setup [--autostart on|off] [--auto-update on|off] [--watchdog on|off]
```

Setup also accepts `--organization-id`, `--workspace-id`, `--runtime-key-ref`, `--import-all`, `--import-alias`, and `--non-interactive`. It changes configuration and automation; use the [installer](getting-started.md#choose-installation-policy) for first-time program and official-client acquisition.

## Configuration

```text
tunneltend config show
tunneltend config set settings.automation.watchdog false
```

Normal users should prefer installer switches and service commands over direct configuration paths.

## Global options and structured output

`--state-root PATH` selects a non-default state directory. `--json` emits the versioned envelope defined in the [output schema](../schemas/output.schema.json), including status, data, diagnostics, and proposed actions where applicable. It changes formatting, not whether a command mutates. `tunneltend version` reports the installed version.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | command completed; status may be `ok`, `noop`, `planned`, or `changed` |
| 2 | command completed with degraded or error facts |
| 4 | command failed validation or execution |
| 10 | launcher/install dependency failure |

Applied repair, reconciliation, and automation aggregate their per-service and update outcomes. A failed operation returns degraded status and exit 2 while retaining successful fleet results. A normal recovery-policy deferral returns `noop` (or `changed` when other work succeeded), exit 0, and an `operation.skipped` diagnostic; it does not claim that the deferred service converged. Startup's persisted session reset counts as a state change. Maintenance with no update or reconciliation change returns `noop`.
