# Changelog

## Meaning

This changelog records user-visible TunnelTend changes by release line. The current source is pre-release, so implemented v0.1 capabilities remain under Unreleased until an authorized GitHub Release is published.

## [Unreleased]

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
- Branding, local-validation, compatibility, security/recovery, and release-integration carriers.

[Unreleased]: https://github.com/Wolfsblvt/tunneltend/commits/main
