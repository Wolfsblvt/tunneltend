# Troubleshooting

Start with observations, then choose a specific action. A failed command may have changed something before it failed; inspect the current state before repeating it.

## Start with read-only checks

Replace `my-mcp` with the ID from `tunneltend service list`, or omit the ID to inspect all registered services:

```powershell
tunneltend status my-mcp --json
tunneltend health my-mcp --json
tunneltend doctor my-mcp --json
tunneltend automation status --json
```

These checks do not repair or save state. They may inspect processes and contact configured endpoints. Keep the distinction between a saved registration, intended running state, an observed runtime, and a successful call from your consumer.

## The command is not found

Open a new terminal after installation so it sees the user PATH change. If you selected `-SkipPath`, invoke `tunneltend.cmd` from the installation directory or by its full path. Verify that you are using the same Windows account and installation you configured.

PowerShell 7.4 or newer is required. For a portable installation, rerun the installer with the intended `-PowerShellPath`; do not assume the shell used during setup is the one later tasks will use. See [installation policy](getting-started.md#choose-installation-policy).

## Registration was saved, but startup failed

Run `tunneltend service show my-mcp --json` and `tunneltend doctor my-mcp --json`. A retained registration after a failed start is expected.

| What the evidence points to | Next action |
| --- | --- |
| Missing official client | Inspect `tunneltend client status`. Use the installer for first acquisition, or the supported client update path for an existing installation. Do not substitute an unverified binary download. |
| Missing launch executable or working directory | Check the service's own runtime/dependencies and registered paths. Run its normal local setup, then correct the explicit registration. |
| Ambiguous project discovery | Choose the intended command or descriptor from the reported candidates. Do not force an arbitrary choice. |
| Missing tunnel ID or scope | Use your existing tunnel ID or authorized upstream scope. Confirm the remote tunnel and permissions through [OpenAI setup](getting-started.md#prepare-your-openai-tunnel). |
| Unavailable runtime key reference | Make the referenced environment variable or file available to the account running TunnelTend. Do not paste a raw key into the registration. |
| Existing upstream alias | Inspect the upstream target and use [deliberate alias import](registration.md#import-an-existing-official-alias). Ordinary registration does not silently adopt it. |
| Host is running but probes fail | Check the actual MCP, health, and readiness URLs and whether the service provides them. A health URL is not assumed to exist on every MCP server. |

After resolving the cause, use `tunneltend service start my-mcp` and inspect the result again. Replacing a registration with `--force` replaces its definition; it is not a generic startup repair.

## It works in my terminal, but not in automation

Compare the account, working directory, configured PowerShell path, executable paths, and credential source. A runtime key exported only in your current shell is not automatically available to a later Scheduled Task. Use the account-visible reference described in [credential setup](getting-started.md#prepare-your-openai-tunnel).

Inspect `automation status`. If a task is missing and the installation policy is correct, `tunneltend automation install` reinstalls task registration. It is a mutation; observe the resulting tasks afterward. Do not use `automation startup` as a harmless check: it creates a new session and clears previous suppression.

## It did not start after sign-in

Check whether the service is enabled, desired-running, and configured for autostart. A normal `service stop` saves durable stopped intent, so signing in again will not undo it. `service autostart my-mcp on` changes future sign-in policy; `service start my-mcp` starts it now.

Check global startup policy and task registration as well. Startup is scoped to the current Windows user and runs after sign-in, not before anyone logs in. Task presence alone does not establish that a real sign-in cycle succeeded. See [automation](OPERATIONS.md#automation-modes).

## Recovery has stopped

First determine whether recovery is **ineligible** or **deferred**. A disabled, desired-stopped, inactive, or session-suppressed service is not selected for watchdog recovery. A selected service can still be blocked by incomplete configuration, ownership checks, backoff, or its rolling retry budget.

The default budget allows four attempts within twenty minutes. Exhaustion is visible, but older attempts eventually leave that window and later recovery can become eligible again. Diagnose a repeated failure while it is deferred; do not use the retry loop as a substitute for fixing a missing dependency or credential.

Preview a focused repair:

```powershell
tunneltend repair my-mcp --json
```

If the proposed work is appropriate, apply a fresh plan with `tunneltend repair my-mcp --apply`, then rerun the observations. Manual repair can resume an enabled, desired-running service that was only session-suppressed or inactive. Use a durable stop if that service must stay stopped.

`--force` does not override process identity, secret validation, scope, checksums, or archive safety. If process ownership does not match, inspect the recorded and actual process identity. Do not kill every process with a matching name or delete the state directory to make the warning disappear.

## Source changes do not trigger the expected restart

Check the registered source path, whether watching is enabled, and whether the changed file is included or excluded. Project-path registration enables watching by default; command-only and URL-only registration do not infer a project path.

The first observation establishes a baseline. A later changed fingerprint must remain stable through the debounce period and be observed on the watchdog cadence. Ten-second debounce is not a ten-second delivery guarantee. Watching does not compile or deploy the changed code; an explicit build may still be your responsibility. See [watching and application updates](OPERATIONS.md#source-watching-and-application-updates).

## An official-client update failed

Inspect `tunneltend client status`, `doctor`, and the relevant logs before retrying. Missing verification data, an unsupported asset or capability, an unsafe archive, a process that cannot safely stop, or failed service restoration are different failure boundaries.

Use [the supported update and rollback commands](OPERATIONS.md#update-operation). Keep any retained fallback path named by the error until recovery is complete. Do not bypass verification or overwrite an executable still owned by a running process to turn a failed update into an apparent success.

## Local checks pass, but the consumer cannot connect

Check the same tunnel ID end to end: the registered service, running official runtime, and consumer configuration must refer to the intended tunnel. Verify that the OpenAI organization/workspace associations and permissions allow the intended consumer to find and use it.

Then verify the service's actual MCP behavior and make a harmless representative tool call. A live process, a successful HTTP health response, and consumer access answer different questions. Read [OpenAI's current guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for provider-side access and consumer setup; TunnelTend does not grant or repair those permissions.

## Collect a useful report

Include the TunnelTend and official-client versions, relevant Windows/PowerShell versions, the command you ran, the expected result, the observed diagnostic, and a minimal reproduction. Logs live under `%LOCALAPPDATA%\TunnelTend\state\logs` unless you selected another state root.

Read [logging](LOGGING.md) before sharing diagnostics. Inspect the actual output for sensitive paths, identifiers, or service content even when redaction is applied. Submit ordinary reproducible problems through the [bug report form](https://github.com/Wolfsblvt/tunneltend/issues/new?template=bug.yml); use the [security reporting route](../SECURITY.md) for a vulnerability.
