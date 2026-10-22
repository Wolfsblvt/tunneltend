---
title: "Service state"
description: "What registered, enabled, desired, observed, healthy and ready mean, what status, health and doctor each read, and why a green check on your PC is not proof that ChatGPT can reach your tool."
---

A service can be registered, intended to run, actually running, and usable from ChatGPT. Those are four different facts, and TunnelTend keeps them apart on purpose. Reading its output is mostly a matter of knowing which fact each word describes.

## The words, in order

| Word | Means | Set by |
| --- | --- | --- |
| Registered | TunnelTend has a definition for the service. | `service register`, `service import` |
| Enabled | The service may be managed at all. A disabled service stays inactive until you enable it. | `service enable`, `service disable`, `--disabled` |
| Desired state | What you want over time: `running` or `stopped`. This survives sign-outs and restarts. | `service start`, `service stop`, `service restart` |
| Session intent | What you want *during this sign-in*. A service can be desired running yet suppressed for now. | sign-in startup, `service start`, `service stop --session-only` |
| Observed state | What TunnelTend last saw: is the host process there, is the official runtime there, is the endpoint reachable. | `status`, `health`, the watchdog |
| Healthy | The configured health probe gives the expected answer. | `health`, the watchdog |
| Ready | The configured readiness probe gives the expected answer. Separate from healthy. | `health` |

## Registered

A registered service has a stable identifier and records what TunnelTend needs to run it and reason about it:

- the MCP target: a command to launch, or an HTTP endpoint;
- an optional host process and its working directory;
- the official tunnel alias, tunnel ID and organization/workspace scope;
- credential references, never raw keys;
- whether it is enabled and what its desired state is;
- its sign-in autostart and watchdog policy;
- health and readiness probes;
- watched source paths, exclusions and debounce;
- a bounded recovery policy; and
- an optional, explicit application-update command.

Registration is kept even when the first start fails. The service stays visible and repairable instead of vanishing because one dependency was missing during setup.

## Desired state and the current session

`desiredState=running` is durable intent. On top of it, TunnelTend tracks what should happen in the sign-in session you are in right now:

- sign-in startup activates the services whose autostart is on;
- a manual start activates a service for this session;
- an ordinary manual stop saves durable *stopped* intent;
- `service stop ID --session-only` keeps the durable intent but suppresses automatic startup and recovery for this session;
- official-client maintenance restores the intended active fleet; and
- a new sign-in starts a new session, which clears the previous session's suppressions.

Disabled services and services with `desiredState=stopped` stay inactive until you change them.

:::note
Manual `repair --apply` and a plain `reconcile` act on enabled, desired-running services even when they are inactive in this session or suppressed with `--session-only`. They respect a durable stop and a disabled flag. An application-update command, if you enabled one, can run during maintenance even for a stopped or disabled service. See [Everyday operation](/docs/operations/#stop-a-service-on-purpose) before treating a session-only stop as a full pause.
:::

## Observed state

An observation keeps several independent dimensions instead of collapsing them into one word:

- host process: configured, running, and whether TunnelTend can prove it owns it;
- official tunnel runtime: known, running;
- endpoint reachability;
- readiness;
- health;
- last error and the time of the last observation; and
- the source fingerprint, if the service is watched.

The plain-text output is a readable summary; `--json` keeps every dimension separate. An absent probe is not a passed probe, and a reachable endpoint is not a tool call.

## What each read-only command reads

| Command | Reads | Saves anything? |
| --- | --- | --- |
| `tunneltend status` | Desired and observed facts per service, the official client version, the Scheduled Tasks, the current session. | No |
| `tunneltend health` | Live probes right now: process, runtime, health and readiness endpoints. | No |
| `tunneltend doctor` | A diagnosis: what is wrong, why, and the next useful command. Prints `No problems detected.` when there is nothing to report. | No |

These commands may contact your endpoints and inspect processes, but they do not write observations, budgets or repairs. A `--json` flag changes only the format.

## Why healthy is not a ChatGPT proof

`healthy` means your configured health probe answered as expected on your PC. It does not say that OpenAI accepted the tunnel, that your ChatGPT connector points at it, or that the tool itself answers an MCP request correctly. A readiness probe adds one more local fact, nothing more.

The only proof of the whole chain is a real, harmless tool call from ChatGPT. [Get started](/docs/getting-started/#verify-the-whole-connection) ends with exactly that step, and [Troubleshooting](/docs/troubleshooting/) starts from the case where local checks pass and the consumer still cannot connect.

## Recovery, budget and backoff

The watchdog may recover a service only when it is registered, enabled, desired running, active in this session, not suppressed, configuration-ready and within its recovery budget. Before anything disruptive, the attempt is written down; a crash in the middle leaves a record, not a mystery.

The default budget allows four attempts within a rolling twenty-minute window, with exponential backoff from ten seconds to five minutes between attempts. A service that is running but unhealthy normally needs two unhealthy observations before recovery; a missing runtime can be started without that wait. Success resets the budget.

When the budget is spent, `doctor` says so. That is a visible condition, not a permanent lock: as older attempts age out of the window, new attempts become eligible again. Look at `doctor`, the [logs](/docs/logging/), the command path, the credential reference and the tunnel scope before forcing another attempt. `--force` can override the budget for an explicit manual action; it can never override process ownership or the other hard safety boundaries.

## Source changes

Source watching records an initial fingerprint of the watched files, notices when a different stable state appears, waits for the configured debounce, and restarts only if the change is still stable afterwards. Generated, dependency, version-control, state, log and likely secret paths are excluded by default. Watching is on by default for project registrations and off with `--no-source-watch` or an explicit descriptor policy. It never infers a build or an update.

## The official client's lifecycle

OpenAI's tunnel client has its own install path and its own update cadence. Client maintenance takes a snapshot of the intended fleet, performs a verified, staged replacement, checks that the new client still offers the commands TunnelTend needs, restores the fleet, and rolls back if replacement or restoration fails. [Official client updates](/docs/operations/#official-client-updates) has the details.

## What an operation records

Every mutating operation records what was requested, what happened, what effect it had and, where possible, what TunnelTend observed afterwards. A failure or timeout does not mean nothing changed. Unknown stays unknown until a fresh read-only observation says otherwise.
