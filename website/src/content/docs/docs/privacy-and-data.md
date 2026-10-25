---
title: "Privacy and data"
description: "What the TunnelTend program stores on your computer, what it never stores, what leaves your PC and through which program, and what uninstall keeps or removes."
---

This page is about the TunnelTend program on your Windows PC: what it writes to disk, what it keeps out, and what travels where. The website you are reading, tunneltend.com, has its own [privacy page](/privacy/).

TunnelTend keeps its settings and operational records on your PC. It has no account, cloud, telemetry or central database. MCP traffic passes through OpenAI's official client and infrastructure. TunnelTend also fetches releases and checks the health/readiness addresses you configured; your MCP service may have its own network traffic. [What leaves your computer](#what-leaves-your-computer) separates those paths.

## What is stored locally, and where

By default, everything TunnelTend keeps lives under one directory:

```text
%LOCALAPPDATA%\TunnelTend\state
```

Program files live separately, by default under `%LOCALAPPDATA%\Programs\TunnelTend`. You can choose other locations during installation.

| Path | Contents |
| --- | --- |
| `registry.json` | Your registered services and their policy: the desired state and what the automation may do. |
| `runtime.json` | Observations, the current sign-in session's intent, source fingerprints, and recovery accounting. |
| `logs\` | Daily JSON Lines event logs. See [Logging](https://docs.tunneltend.com/logging/). |
| `backups\` | Snapshots of the official client taken before an update, so it can be rolled back. |
| `work\` | Temporary state for an operation in progress. |

Inside those files, TunnelTend may store:

- service IDs and display names;
- local executable, project, working-directory, and source paths;
- command arguments that passed the inline-secret check;
- the **names** of environment variables and the **paths** of secret files, never their contents;
- the tunnel alias, tunnel ID, and organization/workspace scope;
- desired state and automation policy;
- the process ID, executable path, and start time of processes it started;
- health and readiness results, errors, and timestamps;
- source fingerprints (a digest of the watched files, not the files);
- recovery attempts and operation results;
- logs; and
- official-client backup files.

Access to that directory is controlled by your Windows user account. Apply appropriate file permissions to secret files, the state directory, logs, and backups, as you would for any configuration that names your tools and tunnels.

## Credentials: references only

TunnelTend never asks for your OpenAI key as a value. A registration stores a **reference**, in one of two forms:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

The secret source stays in your environment variable or file. TunnelTend checks whether a reference is available during diagnosis and startup, and passes the runtime-key reference to the official client. It does not intentionally persist the resolved value in the registry, the runtime store, or the logs. Use [credential setup](https://docs.tunneltend.com/getting-started/#prepare-your-openai-access) to make the reference available to your Windows account and later Scheduled Tasks without pasting the value into a command or chat.

Commands, arguments, descriptors, and environment values that look like an inline key, a bearer token, or a credential inside a URL are refused. Logs redact common secret shapes. This is defense in depth, not a general secret scanner; the permissions on your environment and your secret file remain yours to set.

## What leaves your computer

TunnelTend itself contacts exactly two kinds of destination:

- **GitHub's public API and release hosts**, to discover and download official `openai/tunnel-client` releases when a verified update is due or during installation; and
- **the health and readiness URLs you configured**, which may be local or remote, to check whether your service answers.

Everything else is not TunnelTend's traffic. The official client talks to OpenAI's control plane according to its own configuration and OpenAI's policies, and it carries your MCP requests and responses. Your registered MCP service has its own network behavior. TunnelTend neither inspects nor stores the content of those requests.

There is no analytics, no telemetry service, no advertising, and no operator database anywhere in TunnelTend.

## Retention

- Registry and runtime files persist until you uninstall with purge or remove them yourself.
- Daily operational logs rotate by date but are not deleted automatically by TunnelTend.
- The hardened updater keeps a bounded number of its own logs and client backups according to its configuration.

If you want a smaller footprint, delete old files under `logs\` and `backups\` deliberately; keep the most recent backup until you are sure the current client works.

## What uninstall keeps or removes

| Action | What happens to your data |
| --- | --- |
| Normal uninstall | Scheduled Tasks, program files, and the PATH entry are removed. The state directory is **kept**, so a later installation can adopt your registrations. |
| `-PurgeState` | The selected registry, runtime store, logs, and backups are deleted. This is destructive and uses PowerShell's confirmation semantics. |
| `-RemoveOfficialClient` | The managed official-client directory is deleted only when it is inside the installation and outside the state root. |

Deleting TunnelTend state never deletes your project files, your remote OpenAI tunnel objects, OpenAI's own control-plane history, or any data owned by your MCP service. Those live elsewhere and belong to their owners. The exact switches are in [Everyday operation](https://docs.tunneltend.com/operations/#uninstall).

## Before you share diagnostics

The output of `status`, `health`, and `doctor`, the registry and runtime files, and the logs are useful for a bug report, and they also describe your setup. Before sharing any of them, remove:

- organization, workspace, and tunnel identifiers;
- local paths and hostnames that identify you or your machine;
- anything that looks like a key or token, even if redaction should have caught it.

Inspect the actual text rather than trusting the redaction. For a security problem, use the private reporting route in [Security](https://docs.tunneltend.com/security/#report-a-vulnerability) and never include live credentials or private state.
