# TunnelTend documentation

## Meaning

This is the maintained map of TunnelTend product, operator, development, compatibility, security, and release documentation. It helps readers find the one source that owns a question and prevents the root README from becoming the complete manual.

## Product and design

- [Vision](VISION.md): durable product promise, experience, and boundaries.
- [Current direction](DIRECTION.md): selected near-term movement and release sequence.
- [Product model](product-model.md): registered services, desired state, session intent, and operations.
- [Decisions](DECISIONS.md): durable choices and rationale.
- [Branding](branding.md): the approved Fold identity, palette, voice, and asset use rules.

## System and data

- [Architecture](ARCHITECTURE.md): components, data flow, adapters, and invariants.
- [Project map](PROJECT-MAP.md): repository layout and entry points.
- [Data model](DATA-MODEL.md): registry/runtime schemas and compatibility boundary.
- [Privacy and data](PRIVACY-AND-DATA.md): local data, purpose, retention, and deletion.
- [Logging](LOGGING.md): event meaning, contents, retention, and redaction.

## Use and operation

- [Getting started](getting-started.md): installation, policy switches, credentials, agent setup, and uninstall.
- [Registration](registration.md): descriptors, discovery, explicit targets, and import.
- [CLI reference](cli-reference.md): command grammar and structured output.
- [Operations](OPERATIONS.md): startup, watchdog, maintenance, recovery, and ordinary use.
- [Troubleshooting](troubleshooting.md): diagnostic routes and common failures.
- [Security](SECURITY.md): trust boundaries and threat model.

## Development and release

- [Development](DEVELOPMENT.md): prerequisites, verification commands, and local workflows.
- [Official-client compatibility](upstream-compatibility.md): adapter contract and compatibility process.
- [Current upstream snapshot](research/openai-tunnel-client-current.md): pinned current release facts.
- [Releasing](RELEASING.md): candidate, tag, publication, and rollback procedure.
- [Windows release checklist](release-checklist.md): disposable-host lifecycle qualification.

## Agent carriers

`carriers/` contains copy-ready bounded assignments for branding co-design, local Windows qualification, compatibility review, security/recovery review, and release integration. They are assignment inputs, not current product truth.
