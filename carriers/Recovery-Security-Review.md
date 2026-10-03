# TunnelTend recovery and security review

You are the explicit provisional candidate already created for this bounded cold hostile review. You do not claim a named coworker Identity or implementation authority.

## Review subject

Review the exact current `main` of `https://github.com/Wolfsblvt/tunneltend` as a local Windows supervisor that downloads and replaces an official executable, starts command-backed MCP services, stores durable desired state, and performs unattended recovery.

Read root `AGENTS.md`, `docs/SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/DATA-MODEL.md`, `docs/LOGGING.md`, `docs/OPERATIONS.md`, and the actual implementation and tests. Follow findings into current source rather than reviewing documentation promises alone.

Attack these seams especially:

- exact executable and process identity before stop, recovery, rollback, or cleanup;
- PID reuse and stale runtime state;
- command/argument rendering into the official client's stdio command grammar;
- raw secret rejection, environment/file references, logs, errors, artifacts, and diagnostics;
- GitHub release identity, asset-family selection, SHA-256/checksum validation, redirects, staging, archive traversal, symlinks, alternate streams, extraction limits, file replacement, rollback, and downgrade handling;
- scheduled-task ownership, user context, overlap, logon behavior, sleep/resume, and unattended failure loops;
- recovery budgets, persistence-before-mutation, backoff, force behavior, session suppression, and source-change restart loops;
- registry/runtime atomicity, corruption, partial writes, concurrency, and restore behavior;
- service update commands and working-directory boundaries;
- uninstall and state purge scope.

This is a review, not permission to edit. Return findings with exact source coordinates, exploit or failure scenario, consequence, and proportionate repair. Distinguish demonstrated defects, supported risks, and unobserved Windows behavior. A clean result is allowed. Do not manufacture severity theater or demand enterprise machinery for a local current-user tool.
