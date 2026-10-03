# Product model

## Meaning

This document defines TunnelTend's user-facing state model and operational relationships. It explains what a registered service means, how durable desired state differs from current observations, and how startup, watchdog, maintenance, and manual actions interact. Schemas remain the machine-readable contract.

## Registered service

A service has a stable normalized identifier and records:

- command-backed or HTTP MCP target;
- optional host process and working directory;
- official tunnel alias, tunnel identifier, and organization/workspace scope;
- secret references, never raw runtime keys;
- enabled and desired-state policy;
- logon autostart and watchdog policy;
- health and readiness probes;
- source-watch paths, exclusions, and debounce;
- bounded recovery policy; and
- optional explicit application-update command.

Registration is durable even if the first start fails. This lets the service remain visible and repairable instead of disappearing because one dependency was unavailable during setup.

## Desired state and current session

`desiredState=running` expresses durable intent. Current-logon intent refines it:

- startup activates eligible autostart services;
- a manual start activates a service in the current session;
- a manual stop suppresses it for the current session;
- maintenance restores only services intended to remain active; and
- a new logon creates a new session boundary.

Disabled services and services with `desiredState=stopped` remain inactive until explicitly changed.

## Observation

An observation keeps independent dimensions rather than compressing everything into “up”:

- host process configured/running and ownership evidence;
- official tunnel runtime known/running;
- endpoint reachability;
- readiness;
- health;
- last error and last observed time; and
- source fingerprint standing.

The CLI projects these facts into Wolf Ops-compatible summaries while retaining protected native detail in structured output.

## Recovery

Watchdog recovery occurs only when the service is registered, intended to be active, configuration-ready, and within its recovery budget. An attempt is persisted before disruption. Success resets the budget; repeated failure produces backoff and eventual exhaustion that remains visible to `doctor`.

`--force` can bypass the budget for an explicit operator action, but cannot bypass process ownership or other hard safety boundaries.

## Source change

Source watching establishes an initial applied fingerprint, detects a different stable candidate, waits for the configured debounce, and restarts only after the change remains stable. Generated, dependency, VCS, state, log, and likely secret paths are excluded by default.

## Official-client lifecycle

The official binary has a separately configured install path and update cadence. Client maintenance snapshots the intended fleet, performs a verified staged replacement, checks compatibility, restores the fleet, and rolls back if replacement or restoration fails.

## Application lifecycle

TunnelTend may start a configured host process before connecting the official runtime. It may run a configured update command during maintenance only when the service explicitly enables that behavior. It never derives update behavior from repository contents.

## Operation records

Mutating operations record requested action, result, effect, and post-operation verification where available. Failure or timeout does not imply unchanged effect; unknown remains unknown until observed.
