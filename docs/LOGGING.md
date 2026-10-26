# Logging and operational evidence

## Meaning

TunnelTend writes local structured operational logs so an operator can understand reconciliation, recovery, updates, and failures without turning read-only commands into state mutation. This document defines event meaning, contents, exclusions, storage, and retention boundaries. Exact event production remains in source and tests.

## Purpose

Logs support:

- explaining why a service was started, stopped, skipped, or recovered;
- diagnosing updater and restoration failures;
- preserving bounded operation context after unattended tasks; and
- distinguishing command failure from observed service state.

Logs are not an audit ledger, analytics stream, or authority for desired state.

## Format and location

Core events are UTF-8 JSON Lines under:

```text
%LOCALAPPDATA%\TunnelTend\state\logs\tunneltend-YYYY-MM-DD.jsonl
```

Typical fields:

- UTC timestamp;
- severity;
- namespaced event name;
- redacted message; and
- bounded event-specific data such as service ID, action, and context.

The official client and hardened updater may maintain separate logs in their configured locations.

## Meaningful event families

- registration and policy changes;
- startup/watchdog/maintenance reconciliation;
- per-service action failure;
- recovery reservation and result;
- official-client update, restoration, rollback, and cleanup;
- automation installation/readback; and
- state or compatibility errors.

A process-start acknowledgement is not health. Operation output should retain that distinction.

## Secret and privacy exclusions

TunnelTend does not intentionally log resolved secret-reference values. Common key, bearer, token, password, and secret assignment forms are redacted from messages.

Do not add:

- raw environment values;
- secret file contents;
- complete authorization headers;
- official API keys;
- full unbounded command output;
- full registry/runtime documents; or
- copied user project content.

Paths and identifiers can still be sensitive. Support bundles must be reviewed and minimized before sharing.

## Retention and cleanup

Core daily logs currently remain until uninstall purge or deliberate operator cleanup. The updater separately keeps bounded log and backup counts. There is no remote export or automatic support upload.

Retention automation should be added only when real accumulation or support needs establish the appropriate window and deletion consequence.

## Access and alerts

Only the current user and local administrators should access default logs. Scheduled Task failure appears through task history and GitHub CI failures appear through GitHub; TunnelTend does not currently send remote alerts.

## Central compatibility metadata

The independent upstream qualification route retains bounded harness-authored reports as public native GitHub artifacts, not local runtime logs. It records package/build, official release/asset/digest, architecture, exact checks/outcomes, source/adapter/harness identity and UTC times, without arbitrary executable output, credentials or local paths. The clean website consumer attaches provider run/attempt/artifact identity, digest and actual expiry. The job summary and generated display bind both the accepted website source and consumed evidence.

Reports and identity-only history request 90 days; the repository's observed setting and maximum are both 90 days. Actual provider expiry governs consumption. History does not extend original report proof. The 48-hour freshness threshold changes public disclosure, not installation or publication eligibility. [Compatibility operations](upstream-compatibility.md#identity-history-and-expiry) owns recovery and explicit lost-history limits. Meaningful incidents must be preserved in ordinary maintainer Work before temporary artifacts expire.

Failure encounter uses GitHub's per-run Actions notification route for `Wolfsblvt`, plus maintainer CI stewardship. A failed run and a delivered notification are separate observations; changed-producer delivery must be exercised before activation is claimed. There is no deduplication service, Issue bot, mailbox wake or new alert credential. This central evidence does not change local log access, retention or upload behavior.
