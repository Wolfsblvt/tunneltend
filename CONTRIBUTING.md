# Contributing

## Meaning

This guide defines the supported public contribution path for TunnelTend. It names the repository entry point, verification expectations, safety context, and prohibited material without promising support or review timing.

Read `AGENTS.md` first. Create a focused branch from `main`, preserve the operational grammar, and explain the user or operator consequence.

Before opening a pull request:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-Tests.ps1 `
  -RequirePester `
  -RequireAnalyzer
pwsh -NoProfile -NonInteractive -File .\scripts\Invoke-RepositoryValidation.ps1
```

Also run `docs/release-checklist.md` for installer, updater, process ownership, Scheduled Task, logon, sleep/resume, or lifecycle changes.

Include:

- the behavior changed and why;
- tests or qualification at the risk-bearing seam;
- security, compatibility, state, and migration consequences;
- a changelog entry for user-visible changes; and
- exact evidence boundaries, including what did not run.

Do not submit generated official binaries, credentials, captured user state, private identifiers, weakened verification defaults, broad process termination, or inferred project-update behavior.
