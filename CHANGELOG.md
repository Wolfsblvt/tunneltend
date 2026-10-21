# Changelog

## Meaning

This changelog records user-visible TunnelTend changes by release line. The first stable release account is [TunnelTend 1.0.0](docs/releases/1.0.0.md); downloadable availability is established by the matching GitHub Release.

## [Unreleased]

## [1.0.0]

### Added

- Durable registration for command-backed and HTTP MCP services.
- Desired-state reconciliation across manual, startup, watchdog, and maintenance contexts.
- Current-session activation and suppression so deliberate manual stops remain respected.
- Process, official-runtime, health, and readiness observation.
- Bounded recovery budgets, persisted backoff, and safe restart ordering.
- Optional stable source-change detection and configured restarts.
- Verified official `openai/tunnel-client` updates with backup and rollback.
- Current-user Windows Scheduled Tasks for startup, watchdog, and maintenance.
- Guided and deterministic agent-friendly installation without hand-written JSON.
- Read-only `status`, `health`, `doctor`, `repair`, and reconcile-plan operations.
- Stable JSON output envelopes for agents and automation.
- Versioned schemas, Pester tests, portable fallback tests, CI, release-candidate packaging, and Windows qualification guidance.
- The approved Fold identity, Moonpool palette, and public installation guidance.

### Fixed

- Non-interactive uninstall now honors `-Force` while preserving `-WhatIf` and retained state.
- Release packaging stamps module, CLI and installer versions consistently, including prerelease candidates built from stable source.

[Unreleased]: https://github.com/Wolfsblvt/tunneltend/commits/main

[1.0.0]: https://github.com/Wolfsblvt/tunneltend/releases/tag/v1.0.0
