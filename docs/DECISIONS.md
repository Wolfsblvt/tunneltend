# Decisions

## Meaning

This record preserves TunnelTend choices whose rationale cannot be reconstructed safely from the current code alone. Each entry separates the accepted outcome from its current implementation and keeps meaningful rejected alternatives visible. Routine implementation details and active Work do not belong here.

## D-001: TunnelTend is the incumbent product name

**Decision:** Use **TunnelTend** for the product and `tunneltend` for the CLI and repository slug.

**Why:** The name expresses the core promise of quietly tending durable tunnel connections rather than presenting another orchestration platform. It supports understandable operational language without implying OpenAI affiliation.

**Rejected or superseded:** Keeping the first updater-only framing; publishing under an official-sounding “OpenAI Tunnel Updater” name.

**Current consequence:** Product names, commands, state paths, task names, schemas, documentation, and release artifacts use TunnelTend. The branding co-design may recommend a rename only if one alternative is materially stronger and its migration cost is explicit.

**Source:** Wolf's owner direction in the TunnelTend co-design conversation, 2026-10-04.

## D-002: Registered desired state is the product core

**Decision:** Manage named registered services with durable desired state, rather than remember whichever processes happen to be running.

**Why:** Automatic startup, recovery, updates, deliberate stops, and one-to-many operation need stable service identity and operator intent. Process discovery alone cannot distinguish desired state from accidental state.

**Rejected or superseded:** A client-only updater; process-name-based restart scripts; restoring every official alias automatically.

**Current consequence:** `registry.json` stores service definitions and policy. `runtime.json` stores observations, session intent, fingerprints, ownership evidence, and retry accounting.

**Source:** Owner expansion from updater to autonomous MCP lifecycle manager, 2026-10-04.

## D-003: Keep durable registry and runtime observations separate

**Decision:** Use schema-versioned atomic JSON with separate registry and runtime files for the first release.

**Why:** The expected state set is small, local, inspectable, agent-friendly, dependency-free, and cheap to replace atomically. Durable intent and ephemeral observations have different ownership and failure meaning.

**Rejected or superseded:** SQLite before scale or query needs exist; one mixed file where observations can accidentally rewrite desired state.

**Current consequence:** Read-only commands may shape data in memory but never persist it. A database remains a future migration only if real state size, concurrency, or query requirements earn it.

**Source:** Product architecture co-design, 2026-10-04.

## D-004: The official client remains external and authoritative

**Decision:** Download and invoke OpenAI's official `tunnel-client`; do not copy its protocol implementation or bundle its binary.

**Why:** The official client owns control-plane and runtime semantics and is changing actively. A narrow adapter minimizes compatibility spread and licensing confusion.

**Rejected or superseded:** Reimplementing the protocol; embedding the official executable in TunnelTend releases; duplicating its native supervisor state.

**Current consequence:** Version-specific behavior belongs in the official-client adapter and compatibility snapshot. Update assets are fetched directly from `openai/tunnel-client` and verified.

**Source:** Owner direction and upstream compatibility research, 2026-10-04.

## D-005: Autonomous behavior is the default

**Decision:** Enable logon startup, watchdog recovery, and stable official-client updates by default.

**Why:** The product exists to remove recurring manual handling. Requiring users to discover and enable each useful behavior would preserve the burden under a more attractive CLI.

**Rejected or superseded:** Opt-in automation as a “safer” default; one updater task that cannot distinguish startup from maintenance; infinite restart loops.

**Current consequence:** Startup, watchdog, and maintenance are separate task contexts. Recovery is bounded, persisted, and observable. Users can disable each behavior explicitly.

**Source:** Wolf's direct default-behavior selection, 2026-10-04.

## D-006: Facts, plans, and mutations remain distinct

**Decision:** `status`, `health`, `doctor`, `repair`, and `reconcile --plan` are read-only; mutations require explicit apply/reconcile commands.

**Why:** Humans and agents need reliable diagnostic commands that cannot change the state they are trying to understand. Explicit operation receipts preserve consequence and post-operation verification.

**Rejected or superseded:** Helpful read commands that normalize files, reset budgets, or repair state silently.

**Current consequence:** The CLI exposes a versioned structured envelope. Repository validation and tests protect the no-persistence boundary.

**Source:** Wolf Ops grammar adoption for TunnelTend, 2026-10-04.

## D-007: Application updates are explicit, never inferred

**Decision:** A registered service may carry an explicit typed application-update command, but TunnelTend never infers one from a project directory.

**Why:** `git pull`, dependency upgrades, builds, migrations, and container pulls have project-specific consequences and credentials. Source presence is not consent to mutate it.

**Rejected or superseded:** Automatic update heuristics based on `.git`, package manifests, or container files.

**Current consequence:** Official-client maintenance and registered-service application updates remain separate. The default application-update policy is disabled.

**Source:** Product safety and automation co-design, 2026-10-04.

## D-008: Quiet Windows tasks enter through a product-owned native launcher

**Decision:** Use a small C# GUI executable to create the scheduled PowerShell process without a console. Include the helper in packages; source installations compile it with Windows' existing .NET Framework compiler. Keep the interpreter selection in the installation receipt, with a normal installation/user alias by default and an explicit portable override.

**Why:** A real reinstall restored visible Terminal launches after a host-local repair. PowerShell's later window option does not control console creation by its parent. The native entry point repairs that seam while preserving streams, exit status, script cancellation and deliberately detached service lifetimes.

**Rejected or superseded:** Capturing the installer's cached interpreter; depending on a private Leitsatz launcher; treating disabled startup/watchdog tasks as the solution; adding a separate service or SDK/NuGet toolchain.

**Current consequence:** TunnelTend owns the native source/build boundary and its process-lifetime regression tests. Task and receipt configuration retain a stable interpreter coordinate; owned WindowsApps child identities resolve the installed executable before launch. Actual scheduler and installed behavior require their own lifecycle qualification.

**Sources:** [Wolf's installer direction relayed by Tala](https://github.com/Wolfsblvt/emergency-meeting/issues/878#issuecomment-6223290730); [Katja's native-boundary judgment](https://github.com/Wolfsblvt/emergency-meeting/issues/878#issuecomment-6223620155); [Eira's source/package Return](https://github.com/Wolfsblvt/emergency-meeting/issues/878#issuecomment-6224774034).


## D-009: Windows qualification uses disposable paths on the existing host

**Decision:** Qualify the first stable release on Windows 11 with isolated disposable current-user installation, state, profile, log, backup and test-service paths. A VM is not a prerequisite.

**Why:** Wolf explicitly rejected a VM requirement on 2026-10-21 after real sign-in, resume, connected recovery and remote MCP proof had already been collected on the existing Windows host. Isolation and exact observations protect the real estate without adding a separate machine requirement.

**Rejected or superseded:** The release checklist's blanket disposable-VM/account requirement. Portable tests still do not substitute for Windows behavior, and a missing observation is not recorded as a pass.

**Current consequence:** Reuse source-bound evidence for unchanged boundaries, exercise remaining meaningful behavior in disposable paths, and state exact limits. Website authorship/co-design follows separately with Wolf; it is not a dependency on source branding and release preparation.

**Source:** Wolf's direct product direction, 2026-10-21: “we do not need a VM. I don't want that.” Katja carries the resulting qualification and release delivery.
