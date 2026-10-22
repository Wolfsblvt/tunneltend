---
title: "Logging"
description: "Where TunnelTend writes its logs, what an event contains, what is redacted or never written, how long logs are kept, and how to share them safely in a bug report."
---

TunnelTend writes local structured logs so you can see why a service was started, stopped, skipped, or recovered, and how an update or rollback went, without any read-only command having to change state to tell you. Logs are evidence of what happened. They are not an audit ledger, not an analytics stream, and never the authority for what you want running; that lives in the registry.

## Where the logs are

Core events are UTF-8 JSON Lines files, one event per line, one file per day:

```text
%LOCALAPPDATA%\TunnelTend\state\logs\tunneltend-YYYY-MM-DD.jsonl
```

If you chose a different state root during installation, the `logs\` directory sits under that root instead. The official client and the hardened updater may keep their own logs in their configured locations.

## What an event contains

Each line is one JSON object with:

- a UTC timestamp;
- a severity;
- a namespaced event name;
- a redacted message; and
- bounded event-specific data, such as the service ID, the action taken, and the context (`startup`, `watchdog`, `maintenance`, or `manual`).

The event families you will meet:

| Family | Tells you |
| --- | --- |
| Registration and policy changes | A service was registered, changed, enabled, disabled, or its policy switched. |
| Startup, watchdog, and maintenance reconciliation | What each automation pass considered, started, stopped, or skipped, and why. |
| Per-service action failure | A start, stop, or restart did not succeed, with the diagnosis. |
| Recovery reservation and result | An attempt was reserved against the retry budget, and how it ended. |
| Official-client update, restoration, rollback, and cleanup | Each step of a client update, including a rollback. |
| Automation installation and readback | Scheduled Tasks were registered and what was read back. |
| State or compatibility errors | A stored file or an official-client response did not match what TunnelTend expects. |

:::note
A line saying a process was started is an acknowledgement, not health. Look for the later health or readiness event, or run `tunneltend health`, before concluding the service is up. [Service state](/docs/service-state/) explains the difference.
:::

## Logs versus command output

The read-only commands `status`, `health`, and `doctor` describe the **current** state when you run them, and they save nothing. The logs describe **what happened over time**, including passes that ran while you were away. When something is down now, start with `doctor`; when you want to know what the watchdog did at 03:14, read the log for that day. Add `--json` to any command when another tool, such as a local coding agent, will read the result.

## What is redacted, and what is never written

TunnelTend does not intentionally log resolved secret values. Common key, bearer, token, password, and secret-assignment shapes are redacted from messages before they are written.

The logs never contain, by design:

- raw environment-variable values;
- secret file contents;
- complete authorization headers;
- OpenAI API keys;
- full, unbounded command output;
- full registry or runtime documents; or
- copied content from your project.

Paths and identifiers can still be sensitive. A log line can name your project folder, your tunnel ID, and your organization scope.

## Retention

Daily log files stay until you uninstall with purge or delete them yourself; TunnelTend does not delete them on a schedule. The updater separately keeps a bounded number of its own logs and client backups. There is no remote export and no automatic upload anywhere. Only your Windows user and local administrators should be able to read the default logs.

Scheduled Task failures also show up in Windows Task Scheduler's history. TunnelTend does not send remote alerts.

## Sharing logs in a bug report

Share only the days and lines that cover the problem. Before you paste or attach anything, remove organization, workspace, and tunnel identifiers, local paths and hostnames, and anything that looks like a secret even though redaction should have caught it. Read the text yourself instead of trusting the redaction, and follow the checklist in [Privacy and data](/docs/privacy-and-data/#before-you-share-diagnostics).

Submit reproducible problems through the [bug report form](https://github.com/Wolfsblvt/tunneltend/issues/new?template=bug.yml) with the versions, the command, the expected result, and the observed diagnostic. For anything that looks like a vulnerability, use the private route in [Security](/docs/security/#report-a-vulnerability).
