# CLI reference

## Meaning

This reference describes TunnelTend command grammar, read versus mutation semantics, structured output, and exit behavior. The executable help and output schema remain the machine-facing contract.

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

`repair` without `--apply` and `reconcile --plan` are read-only. Context is one of `manual`, `startup`, `watchdog`, or `maintenance`.

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

Registration options include `--id`, `--alias`, `--tunnel-id`, repeated `--organization-id`, repeated `--workspace-id`, `--runtime-key-ref`, `--health-url`, `--ready-url`, `--no-autostart`, `--no-watchdog`, `--no-source-watch`, and `--disabled`.

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

## Configuration

```text
tunneltend config show
tunneltend config set settings.automation.watchdog false
```

Normal users should prefer installer switches and service commands over direct configuration paths.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | command completed; status may be `ok`, `noop`, `planned`, or `changed` |
| 2 | command completed with degraded or error facts |
| 4 | command failed validation or execution |
| 10 | launcher/install dependency failure |

Applied repair, reconciliation, and automation aggregate their per-service and update outcomes. A failed operation returns degraded status and exit 2 while retaining successful fleet results. A normal recovery-policy deferral returns `noop` (or `changed` when other work succeeded), exit 0, and an `operation.skipped` diagnostic; it does not claim that the deferred service converged. Startup's persisted session reset counts as a state change. Maintenance with no update or reconciliation change returns `noop`.
