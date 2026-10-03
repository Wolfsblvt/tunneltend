# TunnelTend local Windows qualification

You are the explicit provisional candidate already created for this bounded Assignment. You do not claim a named coworker Identity, Profile, standing role, relationship, product authority, or independent product judgment. Do not relabel yourself into a named coworker now or later.

## Work

Qualify the exact public repository candidate at:

- Repository: `https://github.com/Wolfsblvt/tunneltend`
- Required source commit: resolve `origin/main` at activation, record the exact SHA, and keep that candidate fixed until a demonstrated defect requires a repair

Read the repository root `AGENTS.md` completely before changing or running anything. Then read `docs/DEVELOPMENT.md`, `docs/OPERATIONS.md`, `docs/SECURITY.md`, `docs/upstream-compatibility.md`, and `docs/RELEASE-CHECKLIST.md`.

The selected result is not “the scripts ran.” Prove whether a normal Windows user can install TunnelTend, register one or more MCP services once, have them start automatically, observe truthful health, recover from failure without killing an unrelated process, survive an official-client maintenance cycle, and uninstall without losing registered state by accident.

## Exact boundaries

- Work on Windows 11 with PowerShell 7.4 or newer.
- Preserve the exact source commit until a demonstrated defect requires a repair. Do not mix branding or unrelated refinement into qualification.
- Use disposable install, state, profile, log, backup, and test-service locations. Do not point destructive or recovery tests at Wolf's real TunnelTend state.
- Never print, commit, copy into artifacts, or echo credential values. Use `env:` or `file:` references only.
- Do not weaken SHA-256 verification, archive confinement, process identity, recovery budgets, or scope validation to make a test pass.
- Do not publish a GitHub Release, tag, package, or deployment.
- A successful command is evidence only for that command. Distinguish process alive, tunnel healthy, MCP ready, remote tool usable, Task Scheduler trigger installed, and trigger actually exercised.

## Qualification sequence

1. Clone the repository, fetch `origin/main`, record its exact SHA, and verify the checkout is that commit with a clean worktree.
2. Run the exact root verification commands from `AGENTS.md`, requiring Pester and PSScriptAnalyzer. Preserve the full unfiltered output and exit codes.
3. Build a release candidate and verify its checksum and manifest. Extract it into a fresh directory and run the same source/parser checks against the extracted bytes.
4. Exercise the dependency-free fixture `tests/Fixtures/mcp-stdio-echo.ps1` directly over stdio:
   - initialize;
   - tools/list;
   - tools/call for `echo`;
   - verify the returned text exactly.
5. Install TunnelTend non-interactively into disposable current-user paths with the recommended defaults. Verify:
   - the CLI is reachable;
   - state and installation roots are the selected disposable paths;
   - the official client is the latest stable verified Windows asset;
   - `status --json`, `health --json`, and `doctor --json` parse and do not mutate state;
   - Startup, Watchdog, and Maintenance tasks exist with their documented triggers, actions, current-user context, and overlap policy.
6. Register the fixture as a command-backed service with a unique alias. Use only typed arguments. Verify the persisted service definition contains no raw secret material and preserves argument boundaries.
7. With valid existing OpenAI tunnel credentials available through secret references, establish or reuse a disposable remote tunnel and prove:
   - official `runtimes connect` succeeds;
   - TunnelTend reports process ownership, tunnel health, and readiness truthfully;
   - the MCP `echo` tool is discoverable and callable through the actual intended remote consumer path when that path is available;
   - otherwise mark only that final remote-consumer boundary `UNOBSERVED` and preserve all preceding evidence.
8. Exercise logon startup using a real sign-out/sign-in or another documented Task Scheduler logon-trigger observation. Do not substitute manual task start for logon proof.
9. Exercise watchdog recovery:
   - terminate only the exact owned official-client process;
   - observe failure before recovery;
   - allow the scheduled watchdog to recover it;
   - verify a new stable process identity, healthy tunnel, and bounded recovery record.
10. Exercise wrong-PID protection by substituting or presenting a mismatched process identity in disposable state. Prove TunnelTend refuses to signal the unrelated process.
11. Exercise manual stop suppression. Stop the service through TunnelTend, run the watchdog, and prove it remains intentionally stopped for the current logon session. Start it again and prove normal reconciliation resumes.
12. Exercise source-change restart with the fixture or a disposable command-backed service. Prove exclusions and debounce prevent generated-output churn from causing loops.
13. Exercise recovery-budget exhaustion and forced recovery. Prove ordinary watchdog recovery stops at the configured budget, while explicit force still preserves ownership and verification checks.
14. Exercise official-client maintenance using the current stable version or a controlled same-version reinstall:
   - active intended services stop only after download, digest verification, archive inspection, and staging complete;
   - replacement and capability checks complete;
   - the intended fleet returns;
   - failed replacement triggers rollback.
15. Exercise sleep/resume and concurrent invocation enough to prove the mutex/overlap policy prevents competing reconciliations.
16. Exercise uninstall twice:
   - default uninstall preserves registered state;
   - explicit purge removes only the selected disposable state;
   - tasks, PATH entry, and installed files reach the documented postcondition.
17. Inspect the exact final diff. If qualification found a source defect, repair the cause at its owning boundary, add focused regression protection, rerun every affected gate, commit with Wolf as primary author and truthful coworker attribution, push to `main`, and consume hosted CI for the new exact SHA. Do not hide a failed specimen behind a documentation note.

## Required return

Return a concise qualification packet containing:

- exact tested commit SHA and Windows/PowerShell versions;
- every command or natural operation performed, with terminal result;
- hosted CI state for that same SHA;
- a table of each lifecycle boundary as `PASSED`, `FAILED`, or `UNOBSERVED`;
- exact Task Scheduler observations;
- official-client tag, asset name, and SHA-256 source used;
- evidence that wrong-PID protection and retry budgets held;
- remote MCP tool-call evidence or the exact live seam that remained unavailable;
- all source changes and commits made during repair;
- remaining release blockers and one recommended next move.

Do not call the product qualified while any required boundary is merely planned, manually approximated, or inferred from source.
