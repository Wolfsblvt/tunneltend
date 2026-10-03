# Security policy

## Meaning

This policy gives security researchers a private reporting route and identifies the currently supported source. It is an intake contract, not the product threat model or a response-time promise.

Report vulnerabilities through GitHub private vulnerability reporting when it is available, or email `contact@wolfsblvt.com` with a subject beginning `Security: TunnelTend`. Do not open a public issue for credential exposure, archive traversal, updater verification bypass, process-identity bypass, command injection, or unsafe privilege behavior.

Supported source:

- `main` until the first public release;
- after release, the latest tagged release and current `main`.

Include a minimal reproduction, affected version/commit, consequence, and redacted evidence. Never include live credentials or copied private state.

TunnelTend treats registry files, descriptors, release metadata, archives, command arguments, health endpoints, process records, and official-client JSON as untrusted input. See [the security model](docs/SECURITY.md) for the threat model and current limitations.
