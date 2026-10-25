---
title: "Security"
description: "The trust boundaries TunnelTend keeps on your PC: process ownership before termination, credential references, verified client downloads, current-user scope, and what it deliberately does not protect."
---

TunnelTend starts processes, downloads an executable from the internet, stores durable configuration, and runs unattended after you sign in. Each of those deserves a plain statement of what it will and will not do. This page is that statement. It is not a claim that TunnelTend makes your MCP service secure; that service, and OpenAI's side of the tunnel, keep their own responsibilities.

## A process is owned before it is touched

TunnelTend never stops a process by name. Before it terminates a process it recorded, it checks all the evidence it has:

- the process ID (PID) still exists;
- the executable path matches the one TunnelTend started; and
- the process start time matches, where Windows provides it.

Windows reuses PIDs, so a stale record can point at an unrelated program. Any mismatch, and any missing evidence, blocks termination. A blocked repair is reported as such; it is never an excuse to kill something else. Official tunnel runtimes are stopped and restarted through the official client's own runtime commands rather than by broad operating-system termination. If you ever hit this refusal, [Troubleshooting](https://docs.tunneltend.com/troubleshooting/#tunneltend-refuses-to-stop-a-process) explains how to resolve the stale record.

## Credentials are references, and inline secrets are refused

Durable configuration accepts `env:NAME` and `file:PATH` references only. Values that look like an API key, a bearer token, a credential embedded in a URL, or a named secret assignment are rejected in commands, arguments, environment values, and descriptors. Logs redact common token shapes and do not intentionally record resolved secrets.

This is defense in depth. It is not a general secret scanner, and it does not replace file permissions on your secret file or the ordinary rule that processes running as your user can read your environment. [Privacy and data](https://docs.tunneltend.com/privacy-and-data/) lists exactly what is stored.

## The official client is downloaded carefully

TunnelTend's updater has one fixed source: the `openai/tunnel-client` releases on GitHub. It accepts only the allowed HTTPS release hosts and selects one exact Windows architecture asset. Then, in order:

1. **Digest verification.** Acquisition always requires the published SHA-256 evidence. Nothing is extracted before the downloaded archive matches it. Public configuration, `--force`, the standalone updater's emergency override, and a valid Authenticode signature are all additional checks or irrelevant; none of them bypasses the checksum.
2. **Guarded extraction.** The archive is rejected or bounded when it contains absolute or parent-traversal paths, alternate data streams, symlink-like entries, too many entries, an excessive expanded size, an ambiguous executable, or a payload whose version does not match.
3. **Staged checks before downtime.** Version and capability checks run on the staged client while your fleet keeps running.
4. **Backup, then transactional replacement.** The current executable is backed up, then replaced; files are staged and swapped transactionally where practical.
5. **Verification and restoration.** The installed client's capabilities are checked, and every intended service is restored.
6. **Rollback on failure.** A failed replacement or restoration rolls back to the recorded backup. The previous executable remains recoverable until the whole sequence succeeds.
7. **No automatic downgrade.** An older release is never installed automatically.

The update and rollback commands are described in [Everyday operation](https://docs.tunneltend.com/operations/#official-client-updates). TunnelTend never bundles the official client; it is OpenAI's separate program under OpenAI's licence.

## Everything runs as you, without elevation

The Scheduled Tasks run as the current Windows user in the signed-in, limited-privilege context, with explicit `pwsh` paths, `-NoProfile`, and `-NonInteractive`. They do not request elevation unless you chose an installation path that genuinely requires it. Task names and paths are fixed under `\TunnelTend\` and are read back after registration. Nothing runs before you sign in, and nothing runs as a system service.

Registered commands are stored as an executable plus an argument array wherever possible. Processes are started without a shell, with typed argument lists, no visible window for unattended operations, and an explicit working directory. Where the official client expects a stdio MCP command as one string, TunnelTend quotes each registered argument into the client's documented grammar inside its adapter rather than passing your text through a shell.

## What `--force` never bypasses

`--force` may skip a confirmation, a debounce, or a recovery backoff where the documentation says so. It never bypasses:

- process identity and ownership checks;
- credential-reference validation and inline-secret rejection;
- organization or workspace scope checks;
- release digest verification; or
- archive safety during extraction.

## What TunnelTend does not protect

Be clear-eyed about the boundary:

- **Your MCP service's own authentication and behavior.** TunnelTend cannot make an unsafe registered command safe, and a tunnel does not change how an HTTP service you already run listens or authenticates.
- **OpenAI's side.** Tunnel access, organization and workspace permissions, and consumer configuration belong to OpenAI. Read [OpenAI's guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels).
- **A compromised user account.** Anything running as your Windows user can change TunnelTend's state and binaries and can read your environment variables.
- **Health endpoints.** They prove only that the configured endpoint answered, not that your tool works for ChatGPT.
- **Upstream defects.** A signed, checksum-verified official client can still contain bugs.

TunnelTend treats service descriptors, CLI values, registry and runtime files, process records, official-client output, GitHub release metadata, checksum files, archives, health endpoints, watched file trees, and credential references as untrusted input.

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/Wolfsblvt/tunneltend/security/advisories/new) when it is available, or email `contact@wolfsblvt.com` with a subject beginning `Security: TunnelTend`. Do not open a public issue for credential exposure, archive traversal, updater verification bypass, process-identity bypass, command injection, or unsafe privilege behavior.

Include a minimal reproduction, the affected version or commit, the consequence, and redacted evidence. Never include live credentials or copied private state. The repository's [security policy](https://github.com/Wolfsblvt/tunneltend/security/policy) names the currently supported source: the latest tagged release and current `main`.
