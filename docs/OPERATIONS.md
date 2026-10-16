# Operations

## Meaning

This document explains TunnelTend's unattended operating model, ordinary commands, recovery behavior, update cadence, state locations, and operator response to degradation. It is written for the person or agent responsible for a local installation and does not duplicate event-level logging policy.

## Automation modes

### Startup

The Startup task runs after logon with a configurable delay. It creates a new session boundary, optionally checks the official client for a due verified update, activates eligible autostart services, reconciles them, and verifies observations.

A service with autostart disabled remains inactive unless explicitly started. A new logon clears prior session suppression by design.

### Watchdog

The Watchdog task runs every two minutes by default. It observes only registered services intended to be active, records non-disruptive source state, and applies bounded recovery when eligibility and thresholds permit.

It never resurrects disabled, desired-stopped, or current-session-suppressed services.

### Maintenance

Maintenance runs daily at 05:15 with up to twenty minutes of randomized delay by default. It may update the official client when due, execute explicitly enabled service update commands, and restore only the fleet intended to remain active.

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

A service must be enabled, desired-running, active in the current session, configuration-ready, and within its retry budget before watchdog recovery. Default policy allows four attempts in twenty minutes, with exponential backoff from ten seconds to five minutes and an unhealthy threshold of two observations.

Budget exhaustion is a diagnostic condition. Inspect `doctor`, service logs, command paths, secret references, and tunnel scope before forcing another attempt.

## Manual intent

- `service stop` persists desired stopped state unless a session-only path is selected.
- A session-only stop suppresses the service until the next logon or explicit manual start/restart.
- `service start` activates and reconciles the service.
- `service restart` explicitly restores running intent before restarting, including after a deliberate stop. A failed start/restart retains that intent for bounded recovery; a failed stop retains the requested stopped or suppressed intent.
- `service disable` stops and disables it.

These distinctions let the watchdog remain autonomous without overriding current operator intent.

## Update operation

Client update preparation occurs while the current fleet remains running. Downtime begins only after release metadata, checksum, extraction, payload, version, and capability preconditions pass. TunnelTend snapshots intended state, stops affected runtimes, replaces the client, verifies it, and restores services. Failure invokes rollback when a backup exists.

Update and explicit `client restore` replace only the configured executable. An external path keeps its selected directory and filename; unrelated sibling files are neither backed up nor replaced. New backups contain the executable and a manifest. Existing directory backups remain usable, but only their selected executable is restored.

The previous executable remains recoverable until installed-client capability checks and restoration of all intended active services succeed. Restoration attempts every eligible service even if one fails, and never reactivates current-session-suppressed services. A failure restores previous bytes and retries the intended fleet. If a possibly started runtime refuses a safe stop, replacement is refused and the error names the retained fallback file for recovery; ownership protections remain in force.

Automatic downgrade is refused. TunnelTend always requires a published SHA-256 digest/checksum for acquisition. Public configuration cannot enable unverified automatic updates; valid code signatures are an additional check, not a substitute for the published checksum. The bundled updater's separate manual emergency switch does not override TunnelTend's automatic requirement.

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

See `docs/LOGGING.md` for event contents and `docs/PRIVACY-AND-DATA.md` for data handling.

## Failure handling

One service failure does not stop the remainder of a fleet pass. A mutating command records per-service results and returns degraded status when appropriate. Timeout or failure does not prove no effect occurred; rerun read-only observation before repeating a consequential operation.

When process ownership evidence does not match, TunnelTend refuses termination. Resolve the stale record or use official runtime operations; never fall back to process-name killing.

## Uninstall and recovery

Normal uninstall removes Scheduled Tasks and program files while preserving state. Optional switches remove the managed official client or purge state. Purge is destructive and uses PowerShell confirmation semantics.

A preserved state root may be adopted by a later installation. Verify paths and run `doctor` before restoring autonomous tasks.
