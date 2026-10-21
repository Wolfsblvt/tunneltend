# Releasing TunnelTend

## Meaning

This document defines TunnelTend's local release-candidate, qualification, publication, and rollback sequence. It keeps source acceptance, hosted CI, Windows lifecycle evidence, tag creation, GitHub Release publication, and end-user installation as separate facts. It grants no publication authority.

## Release standing

`main` is the public integration line. The first stable release line is `v1.0.0`; publication requires the isolated-Windows checklist and current hosted CI for the exact candidate.

## Release communication

The release audience is the Windows user or local agent operating registered MCP services. The leading audience account belongs in `docs/releases/<version>.md` when a release is actually prepared; the GitHub Release projects that account rather than keeping a separate history. No audience release is asserted by a local candidate build.

Lead with what changes in installation, routine operation, recovery, or compatibility. Distinguish source availability, a tested package, Windows qualification, and publication. Credit accepted material contributors, and call out any remaining operator action or limitation that changes whether users should update. Follow the shared Works release-communication standard; do not substitute a file inventory or internal Work chronology for the user-facing account.

The first official public release moves material maintainer work to the PR-preferred posture declared in `AGENTS.md`. It does not create a `next` branch or add a required-approval gate.

## Prepare the candidate

1. Read current `AGENTS.md`, Vision, Direction, and upstream compatibility sources.
2. Verify the current stable official `openai/tunnel-client` release and adapter surface.
3. Run:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-Tests.ps1 `
  -RequirePester `
  -RequireAnalyzer
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-RepositoryValidation.ps1
```

4. Build the exact version:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Build-Release.ps1 `
  -Version 1.0.0 `
  -SkipTests
```

5. Inspect the ZIP contents, manifest, SHA-256 file, version stamping, and absence of official binaries/secrets.

## Qualify on Windows

Run `docs/release-checklist.md` against the exact candidate commit and package using isolated disposable current-user paths on Windows 11. A separate VM is not required. Preserve command output and resulting observations without copying secrets or user state into the repository.

Any repair produces a new commit and invalidates affected evidence. Rerun only the boundaries changed by that repair plus the final root gate.

## Consume hosted CI

For the exact candidate SHA, inspect every applicable GitHub Actions run and job. A local pass does not replace hosted Windows CI. A pending, skipped, wrong-SHA, unexpectedly absent, or red run is incomplete evidence.

## Tag and publish

Tag creation and GitHub Release publication are public retained effects. Perform them only under current publication authority after candidate and Windows qualification are accepted.

The repository workflow builds a release candidate and uploads artifacts. It does not silently publish a GitHub Release. A publishing actor must use the exact qualified ZIP, checksum, manifest, changelog/release account, and source commit.

## Readback

After publication, verify:

- immutable tag points to the accepted commit;
- GitHub Release assets match local SHA-256 values;
- source archive and license are reachable;
- README install route points at the real release;
- a fresh disposable current-user installation can download, verify, install, run `doctor`, and uninstall; and
- no workflow or package claims a deployment that did not occur.

## Rollback and correction

Do not move or recreate a published tag. If a release is defective, preserve it as history, mark or withdraw its audience meaning as appropriate, publish a corrected version, and state the affected behavior. Existing installations use client rollback for the managed official client; TunnelTend release rollback is a separate product operation.
