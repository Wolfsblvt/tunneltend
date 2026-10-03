# Privacy and data

## Meaning

TunnelTend is local-first and does not operate a central service. This document states what local data it stores, why it exists, where it travels, retention defaults, and deletion routes. It does not describe data handled independently by the registered MCP service, OpenAI, or the official tunnel client.

## Local data

TunnelTend may store:

- service IDs and display names;
- local executable, project, working-directory, and source paths;
- command arguments that passed inline-secret checks;
- environment **reference names** and secret file paths;
- tunnel alias, ID, organization/workspace scope;
- desired state and automation policy;
- process ID, executable path, and start time;
- health/readiness status, errors, and timestamps;
- source fingerprints;
- recovery attempts and operation results;
- logs; and
- official-client backup files.

Raw runtime/admin secrets are not intentionally persisted in the registry or runtime store.

## Network data

TunnelTend itself contacts:

- GitHub's public API and release asset hosts to discover/download official `openai/tunnel-client` releases; and
- configured local or remote health/readiness URLs.

The official client separately communicates with OpenAI's control plane according to its own configuration and policies. Registered MCP services have their own network behavior.

TunnelTend includes no analytics, telemetry service, advertising, or central operator database.

## Storage

Default state is under `%LOCALAPPDATA%\TunnelTend\state`. Program files default to `%LOCALAPPDATA%\Programs\TunnelTend`.

The current Windows user controls filesystem access. Operators should apply appropriate ACLs to secret files, state, logs, and backups.

## Retention

- Registry/runtime files persist until uninstall with purge or manual removal.
- Operational log files currently rotate by date but are not automatically deleted by the core manager.
- The hardened updater retains a bounded number of logs and backups according to its configuration.
- Build/test artifacts are development output and are not installed as user state.

A future retention change must preserve diagnostics and rollback value while avoiding indefinite sensitive path/error accumulation.

## Deletion

Normal uninstall preserves state so a later installation can adopt it. Explicit purge removes TunnelTend state. Optional client removal deletes only the managed official-client directory when it is inside the selected installation boundary.

Deleting TunnelTend state does not delete registered project files, remote OpenAI tunnel objects, official control-plane history, or data owned by MCP services.

## Support and reports

Before sharing `status`, `health`, `doctor`, registry, runtime, or log output, remove organization/workspace/tunnel identifiers, local paths, hostnames, and any secret material that escaped ordinary redaction. Security reports should use a private route.
