---
title: "TunnelTend Docs"
description: "Register and operate the MCP services on your Windows PC with TunnelTend, from first install to everyday control, diagnostics and honest connection checks."
identity:
  home: true
  social:
    eyebrow: Documentation
---

TunnelTend keeps the tools on your Windows PC connected to ChatGPT through OpenAI’s official tunnel client, and keeps them that way: started at sign-in, watched, recovered within limits, and updated through verified releases. These pages explain how to set it up, what it does on its own, and how to read what it tells you.

## Pick your start

- **New to all of this?** Read [How it works](https://docs.tunneltend.com/how-it-works/) first. It explains MCP, tunnels and the pieces on your PC in plain words, in about five minutes.
- **Ready to install?** Go to [Get started](https://docs.tunneltend.com/getting-started/): prerequisites, OpenAI access, installation, your first service and the one real check that proves ChatGPT can reach it.
- **Have a local coding agent?** Hand it the [agent guide](https://docs.tunneltend.com/install-with-an-agent/). It uses the same installer and the same read-only checks.
- **Looking for a command?** The [CLI reference](https://docs.tunneltend.com/cli/) lists every command, what it reads and what it changes.

## What you will find here

| Page | Answers |
| --- | --- |
| [How it works](https://docs.tunneltend.com/how-it-works/) | What MCP, a tunnel and the official client are, and what TunnelTend adds |
| [Get started](https://docs.tunneltend.com/getting-started/) | Install, prepare OpenAI access, register a service, connect it in ChatGPT |
| [Register a service](https://docs.tunneltend.com/registration/) | A project folder, a command, an HTTP endpoint or an existing official alias |
| [Service state](https://docs.tunneltend.com/service-state/) | What “registered”, “desired”, “observed”, “healthy” and “ready” mean |
| [Everyday operation](https://docs.tunneltend.com/operations/) | Sign-in startup, deliberate stops, the watchdog, source watching, client updates, uninstall |
| [Troubleshooting](https://docs.tunneltend.com/troubleshooting/) | A service will not start, recovery stopped, the client update failed, ChatGPT cannot connect |
| [Privacy and data](https://docs.tunneltend.com/privacy-and-data/) · [Security](https://docs.tunneltend.com/security/) · [Logging](https://docs.tunneltend.com/logging/) | What is stored where, how keys are handled, what the logs contain |

The [FAQ](/faq/) answers the questions people ask before installing: fit, cost, the OpenAI relationship, what happens when the PC sleeps.

## Current release

The current release line is **1.0.1** for Windows 11 with PowerShell 7.4 or newer; [GitHub Releases](https://github.com/Wolfsblvt/tunneltend/releases/latest) carries downloadable availability. The patch fixes plain-text diagnostics and installation argument forwarding. Sign-in startup, sleep/resume recovery and a real remote tool call from ChatGPT were observed during the original 1.0 qualification; the [1.0.0 release notes](https://github.com/Wolfsblvt/tunneltend/releases/tag/v1.0.0) name the tested client versions and limits. TunnelTend is an independent open-source project and is not affiliated with OpenAI.
