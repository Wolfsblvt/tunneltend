# Project map

## Meaning

This map explains where TunnelTend's product behavior, contracts, tooling, and evidence live. It is the fastest route from repository root to the code or document that owns a question; it does not carry active Work state.

## Root entry points

| Path | Purpose |
|---|---|
| `README.md` | Human project entrance and quick start. |
| `AGENTS.md` | Repository-local agent contract and canonical commands. |
| `tunneltend.ps1` | Source-checkout CLI entry point. |
| `tunneltend.cmd` | Windows command wrapper. |
| `Install-TunnelTend.cmd` | Double-click installer launcher. |
| `LICENSE` | AGPL-3.0-only legal text. |
| `brand/` | Approved identity: authored masters in `brand/source/tunneltend/`, the exported Works-standard bundle in `brand/bundle/tunneltend/`. |
| `website/` | The product website and user manual (Astro + Starlight) published at tunneltend.com; see `website/README.md`. |

## Implementation

| Path | Purpose |
|---|---|
| `src/TunnelTend/Public/10-Service.ps1` | Service registration, import, policy, and direct lifecycle commands. |
| `src/TunnelTend/Public/20-Operations.ps1` | Status, health, doctor, repair, reconcile, startup, watchdog, maintenance, and client operations. |
| `src/TunnelTend/Public/30-Setup.ps1` | Guided setup behavior. |
| `src/TunnelTend/Public/90-Cli.ps1` | CLI grammar, dispatch, envelopes, and exit codes. |
| `src/TunnelTend/Private/00-Utilities.ps1` | Shared paths, atomic I/O, secret handling, process execution, ownership, and CLI helpers. |
| `src/TunnelTend/Private/05-WindowsProcess.ps1` | Stable PowerShell selection, alias resolution, and unattended interpreter options. |
| `src/TunnelTend/Private/10-State.ps1` | Registry/runtime defaults, validation, persistence, and schema-shape repair. |
| `src/TunnelTend/Private/11-InstallerSettings.ps1` | Omitted-option continuity, locked installer settings publication and scoped failure recovery. |
| `src/TunnelTend/Private/12-InstallationPath.ps1` | Ownership and rollback of the installer's user/process PATH additions. |
| `src/TunnelTend/Private/20-OfficialClient.ps1` | Narrow adapter around official `tunnel-client` runtime commands. |
| `src/TunnelTend/Private/30-Discovery.ps1` | Descriptors, conservative project discovery, glob matching, and source fingerprints. |
| `src/TunnelTend/Private/40-Health.ps1` | Health probes, observations, recovery budgets, and source debounce decisions. |
| `src/TunnelTend/Private/50-Reconciler.ps1` | Desired-state planning and convergence. |
| `src/TunnelTend/Private/60-Updater.ps1` | Fleet-aware official-client update and rollback coordination. |
| `src/TunnelTend/Private/70-Automation.ps1` | Windows Scheduled Task definitions and readback. |
| `src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1` | Hardened release download, verification, extraction, replacement, backup, and rollback implementation. |
| `src/TunnelTend/Native/HiddenTaskLauncher.cs` | Native GUI entry point for console-free scheduled scripts and their cancellation lifetime. |

## Operator and maintainer tooling

| Path | Purpose |
|---|---|
| `scripts/Install-TunnelTend.ps1` | Guided and deterministic current-user installation. |
| `scripts/Uninstall-TunnelTend.ps1` | Task, program, optional client, and optional state removal. |
| `scripts/Invoke-Tests.ps1` | Canonical parser, portable, Pester, and analyzer gate. |
| `scripts/Invoke-RepositoryValidation.ps1` | Repository invariants, links, schemas, and dangerous-pattern checks. |
| `scripts/Build-Release.ps1` | Version-stamped release-layout ZIP, checksum, and manifest. |
| `scripts/Build-WindowsLauncher.ps1` | Build the native task launcher with the existing Windows Framework compiler. |
| `scripts/Update-UpstreamSnapshot.ps1` | Refresh current stable official-client release metadata. |
| `scripts/Install-TunnelTend-Online.ps1` | The one-line online installer served at `tunneltend.com/install.ps1`: download, verify, extract, run the installer. |
| `tools/brand-bundle/` | Vendored Brand Bundle Contract validator and schema used by `website/scripts/export-brand.mjs`. |

## Contracts and evidence

| Path | Purpose |
|---|---|
| `schemas/` | Versioned registry, runtime, service, and output JSON contracts. |
| `examples/` | Credential-free service descriptor examples. |
| `tests/` | Pester behavior tests and dependency-free fallback tests. |
| `docs/research/` | Dated or upstream-bound compatibility evidence. |
| `carriers/` | Copy-ready bounded co-design, validation, and integration assignments. |
| `.github/workflows/` | Hosted CI, compatibility observation, release-candidate build, and the website build/publish route. |

## Documentation map

Use `docs/README.md` for the maintained documentation index.
