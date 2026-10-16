# Security model

## Meaning

TunnelTend operates processes, downloads executable code, stores durable service configuration, and runs unattended. This document defines the trust boundaries, protected assets, hostile inputs, hard safety invariants, and accepted limitations for the current local-first Windows product. It is not a claim that TunnelTend makes an MCP service itself secure.

## Protected assets

- runtime and admin API keys referenced by the installation;
- registered commands, paths, and environment references;
- current-user process integrity;
- the installed official tunnel-client binary;
- durable desired state and recovery accounting;
- local logs and backup material; and
- operator intent, especially deliberate stop/disable actions.

## Trust boundaries

Potentially hostile or malformed input includes:

- service descriptors and CLI values;
- registry/runtime JSON;
- process IDs and stale ownership records;
- official-client JSON and command errors;
- GitHub release metadata, checksum files, archives, and archive paths;
- HTTP health endpoints;
- filesystem trees used for source watching; and
- environment and file secret references.

The official OpenAI control plane and client are external dependencies, not code owned by TunnelTend.

## Secret handling

Durable configuration accepts `env:NAME` and `file:path` references. It rejects likely inline keys, bearer tokens, credential URLs, and named secret assignments. Logs redact common token shapes and do not intentionally record resolved secret values.

This is defense in depth, not a general secret scanner. Operators remain responsible for permissions on environment sources, secret files, state, logs, and backups.

## Process control

TunnelTend never kills by process name. A destructive host-process operation requires a live PID plus matching canonical executable and process start evidence when available. PID mismatch, path mismatch, missing generation evidence, or stale state blocks termination.

Official runtime stop/restart uses the official client's runtime commands rather than broad OS process termination.

## Download and archive safety

The updater fixes the source repository to `openai/tunnel-client`, accepts only allowed HTTPS release hosts, and selects one exact Windows architecture asset. TunnelTend acquisition always requires published SHA-256 evidence before extraction. Neither public configuration, force, the standalone emergency override, nor trusted Authenticode signatures can bypass that automatic requirement.

Safe extraction rejects or bounds:

- absolute and parent-traversal paths;
- alternate data streams;
- symlink/reparse-like entries;
- excessive entry counts;
- excessive expanded size;
- ambiguous executable discovery; and
- invalid or mismatched payload versions.

All verification and extraction complete before the existing client is stopped.

## Replacement and rollback

The current installation is backed up before replacement. Files are staged and replaced transactionally where practical. Post-update version/capability checks and fleet restoration determine success. A failed replacement or restoration attempts rollback to the recorded backup.

`--force` does not disable checksum, archive, process identity, scope, or secret validation.

## Command execution

Commands are stored as executable plus argument arrays where possible. Process APIs use `UseShellExecute=false`, typed argument lists, no visible window for unattended operations, and explicit working directories/environment overrides.

The official client currently accepts stdio MCP commands as one command string and parses its own documented grammar. TunnelTend quotes each registered argument into that upstream grammar inside the adapter rather than passing user text through `Invoke-Expression`.

## Scheduled Tasks

Tasks run as the current user by default, use explicit `pwsh` paths, `-NoProfile`, and `-NonInteractive`, and do not request elevation unless the chosen install path requires it. Task names and paths are fixed and read back after registration.

## Known limits

- A compromised current user can change TunnelTend state and binaries.
- Environment variables may be visible to processes running as the same user.
- Health endpoints prove only the configured endpoint response.
- An upstream signed/checksummed binary can still contain defects.
- The first release requires Windows lifecycle and hostile-recovery review before publication.
- TunnelTend cannot make an unsafe registered application command safe.

## Reporting

Use GitHub private vulnerability reporting or a private Security Advisory for credential exposure, archive traversal, verification bypass, process-identity bypass, command injection, unsafe privilege behavior, or similar findings. Do not include live credentials or private state in reports.
