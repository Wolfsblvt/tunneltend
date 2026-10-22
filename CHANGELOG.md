# Changelog

## Meaning

This changelog records user-visible TunnelTend changes by release line. The first stable release account is [TunnelTend 1.0.0](docs/releases/1.0.0.md); downloadable availability is established by the matching GitHub Release.

## [Unreleased]

### Added

- The product website at `website/` (tunneltend.com): the front door, a user-facing manual at `/docs/`, the FAQ, legal pages, and the TunnelTend brand bundle mirrored at `/brand/tunneltend/`.
- `scripts/Install-TunnelTend-Online.ps1`, served as `https://tunneltend.com/install.ps1`: one PowerShell line downloads the latest release, verifies its published SHA-256, extracts it and runs the ordinary installer.
- The TunnelTend wordmark and default lockup (outlined Manrope lettering beside the Fold), exported with the identity as a Works-standard brand bundle with `manifest.json`, tokens and CSS.

### Fixed

- Plain `status`, `health` and `doctor` output no longer fails with a string-formatting error once a service or diagnostic exists; `--json` was unaffected.

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
- The approved TunnelTend identity: The Fold mark, Moonpool After Dark palette, voice, and README entrance, with generated SVG, PNG, and ICO assets under `brand/`.
- Public first-connection instructions, a local-agent route and an operational FAQ.

### Fixed

- Non-interactive uninstall now honors `-Force` while preserving `-WhatIf` and retained state.
- Release packaging stamps module, CLI and installer versions consistently, including prerelease candidates built from stable source.

[Unreleased]: https://github.com/Wolfsblvt/tunneltend/commits/main

[1.0.0]: https://github.com/Wolfsblvt/tunneltend/releases/tag/v1.0.0
