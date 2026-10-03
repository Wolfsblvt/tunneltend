# Data model

## Meaning

TunnelTend persists a small schema-versioned desired-state registry and a separate runtime observation store. This document explains entity relationships, authority, invariants, compatibility, and recovery. The JSON Schemas in `schemas/` are the machine-readable shape.

## Files

```text
registry.json   durable configuration and desired state
runtime.json    session intent, observations, ownership evidence, fingerprints, and recovery accounting
```

Both are UTF-8 JSON written through same-directory temporary files and atomic replacement.

## Registry

Top-level fields:

- `schemaVersion`: current persisted contract version.
- `product`: product identity and created/updated timestamps.
- `settings.automation`: startup, watchdog, maintenance, and update cadence.
- `settings.officialClient`: repository, channel, install paths, and update policy.
- `settings.defaults`: new-service policy and recovery defaults.
- `services`: map keyed by normalized stable service ID.

A service carries MCP target, optional host process, tunnel configuration, probes, source policy, recovery policy, explicit update policy, and lifecycle timestamps.

## Runtime store

Top-level fields:

- `schemaVersion`.
- `session`: current logon/session ID, activation, and suppression sets.
- `officialClient`: last update observation/result.
- `services`: per-service current observation and operation state.

Per-service runtime records may contain:

- health/readiness/state and last error;
- tunnel and host-process observations;
- canonical process identity evidence;
- source applied/pending fingerprints;
- recovery attempts, next eligible time, exhaustion, and last result; and
- last operation data.

## Authority

Registry state is desired truth. Runtime state never silently changes desired truth. Read-only commands may normalize absent fields in memory but do not write either file.

## Identity and keys

Service IDs are lowercase ASCII slugs with letters, numbers, dots, and hyphens. They are stable keys across registry, runtime, logs, tasks, and structured output. Display names may change without changing identity.

Secrets are references, not secret values.

## Compatibility

Version 1 is the only accepted persisted schema in the initial release. Missing fields within version 1 receive current defaults in memory. An unknown schema version is rejected.

Before a public release creates real persisted consumers, development state may be reset. After release, a schema change that cannot preserve registered services and operator intent requires an explicit migration and rollback story.

## Recovery

A corrupt JSON file is not overwritten automatically. The command reports the invalid file. Recovery should preserve the original bytes, repair from a known backup or explicit operator input, validate the result, and only then replace the damaged file.

Official-client backups are separate from registry/runtime recovery.
