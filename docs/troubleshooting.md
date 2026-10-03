# Troubleshooting

## Meaning

This guide maps common TunnelTend diagnostics to safe operator actions. It begins with read-only observation and avoids turning symptoms into broad process termination, state deletion, or verification bypass.

Start with:

```powershell
tunneltend status --json
tunneltend health --json
tunneltend doctor --json
```

Common diagnostics:

- **client.missing:** run `tunneltend client update --force`.
- **service.scope-missing:** register an organization, workspace, or existing tunnel id.
- **runtime-key-unavailable:** set the referenced environment variable or file.
- **automation.task-missing:** run `tunneltend automation install`.
- **recovery-budget-exhausted:** inspect the service and logs before `repair --apply --force`.
- **source-missing:** update the registered project path or disable source watch.

Logs live under `%LOCALAPPDATA%\TunnelTend\state\logs` unless the state root is overridden.
