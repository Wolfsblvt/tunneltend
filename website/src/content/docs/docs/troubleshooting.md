---
title: "Troubleshooting"
description: "Diagnose a service that will not start, recovery that has stopped, missing automation, a failed client update, an ownership refusal, or a connection ChatGPT cannot make."
---

Start with observations, then choose a specific action. A failed command may have changed something before it failed, so look at the current state before you repeat it. Every section below follows the same shape: what you see, what it means, what to run, and what to read in the result.

## Find the symptom

| What you see or need | Start here |
| --- | --- |
| You do not know which program to open, or `pwsh` is not found | [Open and check PowerShell 7](/docs/getting-started/#open-powershell-7). Windows PowerShell is the older app. |
| You know the app you want, but not its MCP command or URL | [Find your MCP service](/docs/getting-started/#find-your-mcp-service). A folder or app name alone is not a server. |
| `tunneltend` is not recognized | [The command is not found](#the-command-is-not-found) |
| Registration says there are no candidates, or several | [Registration was refused or ambiguous](#registration-was-refused-or-ambiguous) |
| The service is registered but stopped, or the runtime key is unavailable | [Registration was saved, but the service will not start](#registration-was-saved-but-the-service-will-not-start) |
| It works by hand but fails after sign-in | [It works in my terminal, but not in automation](#it-works-in-my-terminal-but-not-in-automation) |
| Local checks look good, but ChatGPT cannot use the tool | [Local checks pass but the consumer cannot connect](#local-checks-pass-but-the-consumer-cannot-connect) |

## Start with the read-only checks

These four commands change nothing. They read saved state, inspect processes, and may contact the health URLs you configured. Replace `my-mcp` with an ID from `tunneltend service list`, or leave the ID out to inspect every registered service.

```powershell
tunneltend status my-mcp
tunneltend health my-mcp
tunneltend doctor my-mcp
tunneltend automation status
```

Plain output is a useful first look. `doctor` prints `No problems detected.` when it finds nothing to report; otherwise read the diagnostic code and message. Add `--json` for the complete structured fields and repair suggestions, as used in some of the detailed steps below.

Keep four things apart while you read: a **saved registration** (TunnelTend knows the service), **desired state** (you want it running), an **observed runtime** (a process and a tunnel are actually there), and a **successful call from ChatGPT** (the only proof that the whole chain works). [Service state](/docs/service-state/) explains each word.

## The command is not found

**What you see:** PowerShell says `tunneltend` is not recognized.

**What it means:** The terminal was opened before installation added TunnelTend to your user PATH, or you chose `-SkipPath` during installation, or you are signed in as a different Windows account than the one you installed with.

**What to do:** Close the terminal app completely, then open **PowerShell 7** from Windows Start. A new tab inside an already-running terminal can still inherit the old environment. Check that you are using the Windows account that installed TunnelTend.

For the default installation, you can check it directly without relying on PATH:

```powershell
& "$env:LOCALAPPDATA\Programs\TunnelTend\tunneltend.cmd" version
```

If this works, the installation exists and the problem is command discovery. If you selected `-SkipPath`, keep using the full path or rerun the installer with PATH setup enabled. If you chose a custom install directory, use that path instead. If the program is absent, return to [installation](/docs/getting-started/#install-tunneltend) and read the installer's result rather than assuming it completed.

PowerShell 7.4 or newer is required. For a portable PowerShell, rerun the installer with the intended `-PowerShellPath`, because the shell you used during setup is not automatically the one later tasks use. See [installation policy](/docs/getting-started/#choose-installation-policy).

## Registration was saved, but the service will not start

**What you see:** `service register` or `service start` reports a failure, and `status` shows the service as desired `running` but observed `stopped`.

**What it means:** This is expected behavior, not a lost registration. TunnelTend keeps what you registered so you can fix the cause and start again.

**What to run:**

```powershell
tunneltend service show my-mcp --json
tunneltend doctor my-mcp --json
```

**What to read:** Match the diagnostic code and message against this table. A general `service.unhealthy` message describes the symptom and may not identify its cause. Read the original start error, `tunneltend health my-mcp --json` for runtime/probe details, and the [logs](#where-to-look-in-the-logs) when more context is needed.

| What the evidence points to | Next action |
| --- | --- |
| Missing official client | Inspect `tunneltend client status`. Use the installer for first acquisition, or `tunneltend client update` for an existing installation. Do not drop in an unverified download. |
| Missing launch executable or working directory | The service's own runtime or dependencies are not set up. Run its normal local setup, then correct the explicit registration. |
| Missing tunnel ID or scope | Use your existing tunnel ID or the organization/workspace you are authorized for. Confirm the tunnel and its permissions on [OpenAI's side](/docs/getting-started/#prepare-your-openai-access). |
| Unavailable runtime key reference | Confirm the reference's name/path and use [credential setup](/docs/getting-started/#prepare-your-openai-access) to make it available to your Windows account and later processes. Never paste the raw key into the registration or print the variable to diagnose it. |
| Existing official alias | The official client already has a runtime for this alias. Use [deliberate alias import](/docs/registration/#import-an-existing-official-alias); ordinary registration does not adopt it silently. |
| Host is running but probes fail | Check the actual MCP, health, and readiness URLs and whether your service provides them. Not every MCP server has a health URL, and TunnelTend does not assume one. |

After resolving the cause, run `tunneltend service start my-mcp` and read the observations again. Replacing a registration with `--force` replaces its definition; it is not a generic startup repair.

## Registration was refused or ambiguous

**What you see:** `service register` finds no launch candidate, lists several candidates, or refuses a value.

**What it means:** Discovery is deliberately conservative. No candidate can mean the folder is not an MCP project or its launch method is not recognized. Several candidates mean the error lists their types and reasons instead of picking one; it does not generate the correct command for you. Read a refused value's error message too: values that look like inline secrets—a key, bearer token or credential inside a URL—are rejected before saving.

**What to do:** Find the launch instructions supplied with your MCP server. Use that exact target with `--command`, or a descriptor, and supply credentials only as `env:NAME` or `file:PATH` references. [Register a service](/docs/registration/) covers each method. A local coding agent can help translate those instructions; if the tool does not offer MCP, installing TunnelTend cannot add it.

## It works in my terminal, but not in automation

**What you see:** `tunneltend service start` works when you run it, but the service is down after a sign-in or a watchdog pass.

**What it means:** The Scheduled Tasks run in a different context than your terminal: possibly a different working directory, a different PowerShell, or without an environment variable you exported only in your current shell.

**What to run:**

```powershell
tunneltend automation status --json
```

**What to read:** Compare the account, working directory, configured PowerShell path, executable paths, and credential source between your shell and the tasks. A runtime key exported only in your current session is not available to a later task; use an account-visible reference as described in [credential setup](/docs/getting-started/#prepare-your-openai-access). If a task is missing and your installation policy is correct, `tunneltend automation install` reinstalls the task registration; that is a mutation, so observe the resulting tasks afterwards.

:::caution
Do not run `tunneltend automation startup` as a harmless check. It creates a new session and clears every session-only stop. See [Everyday operation](/docs/operations/#stop-a-service-on-purpose).
:::

## It did not start after sign-in

**What you see:** You signed in, waited, and the service is not running.

**What it means:** One of four policies kept it down, or the Startup task did not run.

**What to run:**

```powershell
tunneltend status my-mcp --json
tunneltend automation status --json
```

**What to read:** The service must be `enabled`, desired `running`, and have `autostart` on. A normal `service stop` saves a durable stopped state, and signing in again does not undo it. `tunneltend service autostart my-mcp on` changes future sign-ins; `tunneltend service start my-mcp` starts it now. Then check that the `TunnelTend Startup` task is installed. Startup is scoped to the current Windows user and runs after sign-in, not before anyone logs in. A task being present does not prove that a real sign-in cycle succeeded; the task's last run time and result in `automation status` do.

## Recovery has stopped

**What you see:** `doctor` reports an exhausted retry budget, or a service stays stopped although the watchdog is installed.

**What it means:** Decide first whether recovery is **ineligible** or **deferred**. A disabled, desired-stopped, inactive, or session-suppressed service is not selected for watchdog recovery at all. A selected service can still be blocked by incomplete configuration, an ownership check, backoff, or its rolling retry budget. The default budget allows four attempts within twenty minutes, with backoff growing from ten seconds to five minutes. Exhaustion is visible in `doctor` and is not a permanent lockout: as older attempts leave the window, later recovery becomes eligible again.

**What to run:** Preview a focused repair before applying anything.

```powershell
tunneltend doctor my-mcp --json
tunneltend repair my-mcp --json
```

**What to read:** The repair plan lists what would be done. If it is appropriate, apply a fresh plan with `tunneltend repair my-mcp --apply`, then rerun the observations. Diagnose a repeated failure while it is deferred; the retry loop is not a substitute for fixing a missing dependency or credential. Note that manual repair can resume a service that was only session-suppressed or inactive; use a durable stop if that service must stay stopped.

`--force` does not override process identity, secret validation, scope, checksums, or archive safety. If process ownership does not match, read the section on [ownership refusals](#tunneltend-refuses-to-stop-a-process) below.

## Automation tasks are missing or never ran

**What you see:** `automation status` lists a task as missing, or its last run time stays empty.

**What it means:** Either the tasks were never installed for this user and installation, or they are installed but have not had an occasion to run yet. `TunnelTend Startup` runs after sign-in; `TunnelTend Watchdog` runs every two minutes; `TunnelTend Maintenance` runs daily at 05:15 with up to twenty minutes of random delay. None of them wakes a sleeping computer.

**What to run:**

```powershell
tunneltend automation status --json
```

**What to read:** Confirm the installation policy you chose. If a task is wanted and missing, `tunneltend automation install` registers it again, then read `automation status` to confirm. If a task is present but shows no run, wait for its trigger or sign in again rather than forcing a run. Task presence and task runs are different facts; Windows Task Scheduler's history shows the latter.

## Source changes do not trigger a restart

**What you see:** You edited files in the registered project folder, but the service kept running the old code.

**What it means:** Watching may be off, the file may be excluded, or the change has not yet been observed as stable. Project-path registration enables watching by default; command-only and URL-only registrations do not infer a project path. The first observation establishes a baseline, and a changed fingerprint must stay stable through the ten-second debounce and be seen on the watchdog's two-minute cadence. Ten seconds of debounce is not a ten-second delivery promise.

**What to read:** Check the registered source path, whether watching is enabled, and whether the changed file falls under an include or exclude rule. Watching restarts the service; it does not build, install dependencies, or deploy anything, so an explicit build may still be your job. See [source watching and application updates](/docs/operations/#source-watching-and-application-updates).

## An official-client update failed, or needs rollback

**What you see:** `client update` reports a failure, or the fleet did not come back after an update.

**What it means:** Each failure boundary is different: missing verification data, an unsupported asset or capability, an unsafe archive, a process that cannot be stopped safely, or a failed restoration of your services. The previous executable stays recoverable until the new client passes its capability checks and every intended service is restored. A failed replacement or restoration rolls back to the recorded backup automatically when one exists.

**What to run:**

```powershell
tunneltend client status
tunneltend doctor --json
tunneltend client update --check-only
```

**What to read:** `client status` shows which executable is installed and from where. If the error names a retained fallback file, keep it until recovery is complete. To roll back deliberately, use `tunneltend client rollback`, or `tunneltend client rollback --backup PATH` to select a specific backup. Do not bypass verification or overwrite an executable that a running process still owns to make a failed update look like a success. See [official client updates](/docs/operations/#official-client-updates).

## TunnelTend refuses to stop a process

**What you see:** A stop, restart, repair, or update is refused with a message about process identity or ownership.

**What it means:** TunnelTend never stops a process by name. Before it stops a recorded process ID (PID), it checks that the PID still exists, that the executable path matches what it started, and that the process start time matches when that evidence is available. Windows reuses PIDs, so a mismatch means the recorded process is gone and something else now has that number. Refusing is the correct outcome: it protects whatever is running there now.

**What to do:** Inspect the recorded and actual process identity through `tunneltend doctor my-mcp --json`. Resolve the stale record through the official runtime operations or by restarting the service deliberately. Do not kill every process with a matching name, and do not delete the state directory to make the warning disappear. `--force` does not bypass this check. [Security](/docs/security/) describes the rule in full.

## Local checks pass but the consumer cannot connect

**What you see:** `status` and `health` are fine, but ChatGPT (or another consumer) cannot find or use your tool.

**What it means:** A live process, a successful health response, and consumer access answer three different questions. TunnelTend proves the first two on your PC. The third depends on OpenAI's side: the tunnel ID, the organization or workspace it belongs to, the permissions of your runtime key, and the connector configuration in the consumer.

**What to check:** Follow the same tunnel ID end to end: the registered service, the running official runtime, and the consumer's connector must all refer to the intended tunnel. Confirm that the OpenAI organization/workspace associations and permissions allow the intended consumer to see and use it. Then verify your service's actual MCP behavior by making one harmless, representative tool call from the consumer. Read [OpenAI's current guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for provider-side access and consumer setup; TunnelTend does not grant or repair those permissions. The [verification steps](/docs/getting-started/#verify-the-whole-connection) list what counts as done, and the FAQ explains [why "healthy" is not the same as reachable](/faq/#health-and-readiness).

## Where to look in the logs

Logs live under `%LOCALAPPDATA%\TunnelTend\state\logs` unless you selected another state root. They are daily JSON Lines files, one event per line, and they explain why a service was started, stopped, skipped, or recovered, and how an update or rollback went. [Logging](/docs/logging/) describes the fields, what is redacted, and what is never written.

## Collect a useful report

Include the TunnelTend and official-client versions, your Windows and PowerShell versions, the command you ran, the expected result, the observed diagnostic, and a minimal reproduction. Read [Privacy and data](/docs/privacy-and-data/) before you share output: remove organization, workspace, and tunnel identifiers, local paths, hostnames, and any secret that escaped ordinary redaction.

Submit reproducible problems through the [bug report form](https://github.com/Wolfsblvt/tunneltend/issues/new?template=bug.yml). For a vulnerability, use the private route described in [Security](/docs/security/#report-a-vulnerability), never a public issue.
