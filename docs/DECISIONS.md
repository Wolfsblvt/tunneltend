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

## D-010: The website authors its own user-facing manual

**Decision:** The public manual at `tunneltend.com/docs/` is written for its readers inside `website/src/content/docs/` (Starlight). The repository's `docs/` tree remains maintainer and contributor documentation and is not generated into the site.

**Why:** Wolf's direction on 2026-10-22: pages that begin with a source-description section are maintainer documents, and the site's first reader is someone using ChatGPT who does not yet know what MCP or a tunnel is. Rewriting for that reader is a different document from the repository contract, so one writable copy per audience is the honest shape.

**Rejected or superseded:** Generating the site from the repository `docs/` allowlist at build time (the earlier integration note's plan).

**Current consequence:** Product facts changed in `docs/` must be carried into the matching website page in the same change. The FAQ keeps its stable answer ids. D-013 supersedes the original `/docs/` public address; the reader-content ownership selected here remains unchanged.

**Source:** Wolf's website direction, 2026-10-22, carried by Tala.

## D-011: One-line installation is served from the product domain

**Decision:** `scripts/Install-TunnelTend-Online.ps1` is served verbatim at `https://tunneltend.com/install.ps1`. It resolves the selected GitHub release, downloads the ZIP and its `.sha256`, refuses a checksum mismatch, extracts into `%LOCALAPPDATA%\TunnelTend\downloads\tunneltend-<version>\`, and runs the ordinary installer in the same console.

**Why:** Wolf selected the one-liner for the website on 2026-10-22. The route keeps the release ZIP and the published digest as the only trust anchors and reuses the existing installer, so it adds no second installation path.

**Rejected or superseded:** A separate bootstrap that extracts and copies files itself; hosting the installer or the release assets anywhere but GitHub Releases.

**Current consequence:** The script never bundles the official client, uses no expression evaluation itself, and is part of the website's publish inputs. Changing its download root or release source is a product decision.

**Source:** Wolf's website direction, 2026-10-22, carried by Tala.

## D-012: The wordmark is outlined Manrope beside the Fold

**Decision:** The TunnelTend wordmark is “TunnelTend” set in Manrope 700 at −0.025 em tracking, outlined to paths; the default lockup is the Fold at the header ratio beside it. Both are exported with the identity as a Works-standard brand bundle.

**Why:** Wolf chose it on 2026-10-22 from three in-site candidates (Nunito lowercase, Manrope, Sora): it reads the same as the product name in prose and serves both the ChatGPT reader and the developer. Outlining removes any runtime font dependency.

**Rejected or superseded:** Nunito lowercase (warmer, more consumer-app), Sora (more overtly technical); a text-only header.

**Current consequence:** `brand/source/tunneltend/tunneltend-wordmark*.svg` and `tunneltend-lockup*.svg` are masters; the lockup carries `titleCompatible` for README and site use. Manrope's OFL licence travels in the bundle as provenance; no font file is distributed.

**Source:** Wolf's selection, 2026-10-22, carried by Tala.

## D-013: The manual has a canonical Docs Home

**Decision:** `https://docs.tunneltend.com/` is the canonical TunnelTend Docs Home. Existing `https://tunneltend.com/docs/*` addresses remain a direct permanent bridge to the matching manual paths with queries preserved. The product site, installer and legal pages stay on the apex.

**Why:** Wolf selected `docs.<product-domain>` as the Works default for substantial public documentation. His first use of the published manual also exposed misaligned navigation and a TOC divider running through the footer. The manual needs its own honest host identity while retaining the approved shared shell and every supported reader/agent journey.

**Rejected or superseded:** D-010's original same-host public path, which established content ownership without comparing host choices. Two separately operated builds or publication rituals are unnecessary: one host-aware Worker can serve the existing single content artifact.

**Current consequence:** Canonical metadata, links, agent handoffs and search select the Docs host. One relevant-main workflow deploys the artifact and Worker together. Per-host robots and sitemaps contain only their own indexable pages. Katja owns product deployment through admitted hosting, product reader/install readback and rollback choice. Wolf Ops owns hosting/estate prerequisites, domain admission, www bridge ordering, DNS/TLS readiness, the recovery interface and provider/monitoring/Search Console follow-through. This custody correction preserves the one product deployment responsibility rather than creating a second Ops deployment assignment.

**Source:** Wolf's selected Docs default returned by Nyxara on 2026-10-24 and accepted for implementation by Katja on 2026-10-25, including Wolf's FAQ-grid repair. Local source/build evidence remains distinct from live publication.
