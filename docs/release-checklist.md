# Windows release checklist

## Meaning

This checklist qualifies Windows behavior that portable source tests cannot prove. It is a disposable-host evidence route for one exact candidate, not a claim that source presence or Linux tests establish logon, task, locking, process, or resume behavior.

Use disposable installation, state, profile, log, backup and test-service paths on a current Windows 11 host. A separate VM is not required. Run current-user tasks at their normal limited privilege. Keep the operator's real services and credentials outside the specimen.

Bind each observation to its actual source/package and environment. Reuse evidence only while the relevant bytes and boundary are unchanged; name an unobserved boundary instead of promoting a source test to lived Windows proof.

1. Install PowerShell 7 and extract the release ZIP.
2. Run guided install and noninteractive install in separate snapshots.
3. Register command, HTTP-host, and imported services.
4. Verify `status`, `health`, `doctor`, repair plan, and reconcile plan do not change state-file hashes.
5. Sign out and in; verify only autostart services run.
6. Stop one service session-only; verify watchdog does not resurrect it and next logon does.
7. Kill a managed runtime; verify threshold, backoff, recovery, and budget exhaustion.
8. Replace a stored PID with an unrelated process; verify termination is refused.
9. Change watched source repeatedly; verify debounce and one clean restart.
10. Validate sleep/resume and missed-task startup.
11. Install an older verified official client, update, verify restore, then exercise rollback.
12. Simulate checksum, malicious ZIP, ambiguous asset, and incompatible-binary failures.
13. Reconfigure task intervals idempotently.
14. Uninstall; verify tasks and PATH are removed while state is preserved by default.
15. Run all tests and build the final artifact from the exact tagged commit.
