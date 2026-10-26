# Official tunnel-client compatibility

## Meaning

This document owns the automatic official-client contract and its evidence boundaries. Compatible newer stable releases require no per-version source edit or approval. Local verified staging remains installation authority; scheduled Windows qualification supplies dated public evidence and maintainer diagnostics independently of local maintenance.

TunnelTend depends on the official client's stable release assets and these command families:

- `--version`
- `runtimes list --json`
- `runtimes status <alias> --json`
- `runtimes connect ... --json`
- `runtimes stop <alias> --json`

The adapter normalizes upstream fields before the rest of the application sees them. Unknown or missing structured targets are refused during import.

`client status` performs live command/flag checks. Cosmetic English help descriptions are not compatibility requirements. Automatic staging additionally exercises an empty `runtimes list --json` and missing-alias status/stop failures in disposable isolated state with no inherited credentials. The observed missing-alias contract is exit 1 with empty stdout and nonempty stderr, even with `--json`; it is not a structured JSON error. These probes do not connect a runtime or create a remote tunnel. Both supported MCP target forms and the adapter's scope, profile, credential-reference and JSON flags must remain available.

## Local installation authority

Maintenance resolves the latest stable release directly from `openai/tunnel-client`. It selects the host architecture, requires a published digest/checksum, guards archive extraction and executable selection, and checks the staged version against the selected release before downtime. The coordinator pins that selected tag for acquisition rather than independently resolving a newer latest release midway through staging. Installed capability/fleet failure retains transactional rollback and explicit incomplete-recovery reporting. No central report, allowlist or website availability is consulted.

Automatic same-version maintenance keeps installed bytes, including when upstream republishes that tag with a different digest. The central reader preserves the old/new official identity for maintainer judgment; a changed digest alone is not a compromise verdict. New installations use the current official asset and checksum. A deliberately forced reinstall remains explicit and cannot bypass checks or permit downgrade. A genuinely newer compatible release resumes ordinary maintenance.

## Isolated scheduled qualification

`Upstream compatibility watch` runs daily, manually, and on relevant adapter/harness/test changes. Its separate disposable Windows jobs test a built source package and the current published TunnelTend package independently. There are no secrets, OIDC, reusable caches, persisted checkout credentials or credentialed publication in these jobs. Before downloaded execution, the dedicated harness process replaces its environment with OS necessities and disposable profile/state paths. The production publisher consumes only validated metadata on another runner.

The report binds the actual TunnelTend ZIP digest/version/kind, the adapter bytes extracted from that package, the harness bytes and source commit, official tag/asset/digest, architecture, timestamps and run/artifact identity. The released package's source commit remains null unless proven; current-source adapter success never claims the public package has that implementation. Acquisition and fixture checks do not prove a connected control-plane session.

The fixed [schema](../schemas/client-qualification.schema.json) and shared [Node validator](../scripts/lib/client-qualification.mjs) reject unknown fields, missing checks, inconsistent aggregates and unsupported fleet/consumer claims. `passed`, `failed`, `not exercised` and `unavailable` remain distinct. Every report carries distribution, credential-free CLI, local owned fleet and connected consumer separately. x64 execution is separate from ARM64 digest/archive verification; ARM64 version and execution checks remain unexercised on x64 runners. A credential-free job's empty fleet is never a restoration pass.

Each `client-qualification-source` / `client-qualification-release` native artifact contains only `report.json` and requests 90-day retention. Failures retain their fixed check outcomes without arbitrary binary output, private state, paths or binaries. Actual expiry and workflow provenance belong to the retained consumer. Unavailable/expired evidence cannot become green, and copying identity history cannot renew qualification. Failure notification is ordinary per-run GitHub Actions delivery and Lead stewardship, not deduplicated incident delivery or a stopped-agent wake; actual account notification delivery must be established before activation is claimed.

## Maintained upstream context

`docs/research/openai-tunnel-client-release.json` remains an optional dated generated release coordinate, refreshed explicitly with `scripts/Update-UpstreamSnapshot.ps1`. The watch no longer fails because that tracked snapshot changed. `docs/research/openai-tunnel-client-current.md` preserves useful authored semantic context and historical evidence; neither file is a version allowlist, permanent latest-version claim or installation gate. Actual upstream contract failure earns focused adapter work and, when needed, a separately authorized TunnelTend patch.
