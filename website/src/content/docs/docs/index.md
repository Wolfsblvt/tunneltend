---
title: "TunnelTend Docs"
description: "Register and operate the MCP services on your Windows PC with TunnelTend, from first install to everyday control, diagnostics and honest connection checks."
identity:
  home: true
  social:
    eyebrow: Documentation
---

TunnelTend looks after the connection between a tool on your Windows PC and ChatGPT. After setup, it starts registered services when you sign in, checks them, recovers within limits, and keeps OpenAI’s official tunnel client updated. These pages take you from choosing what to connect to getting a useful answer back.

You do not need to be a developer to follow the guide. You do need a working **MCP server** (the program that offers your tool to ChatGPT), Windows 11 with PowerShell 7.4 or newer, and access to OpenAI’s Secure MCP Tunnels. TunnelTend does not supply the MCP server or grant OpenAI access. [Check what you have before installing](https://docs.tunneltend.com/getting-started/#before-installation).

## Pick your start

- **New to all of this?** Read [How it works](https://docs.tunneltend.com/how-it-works/) first. It explains MCP, tunnels and the pieces on your PC in plain words.
- **Know the app you want to use, but not its MCP details?** [Find your MCP service](https://docs.tunneltend.com/getting-started/#find-your-mcp-service) explains what to look for and what to ask its maintainer or a local coding agent.
- **Ready to install?** Go to [Get started](https://docs.tunneltend.com/getting-started/): prerequisites, OpenAI access, installation, your first service and the one real check that proves ChatGPT can reach it.
- **Have a local coding agent?** Hand it the [agent guide](https://docs.tunneltend.com/install-with-an-agent/). It uses the same installer and the same read-only checks.
- **Already installed, but stuck?** [Troubleshooting](https://docs.tunneltend.com/troubleshooting/) starts from what you see on screen.
- **Looking for a command?** The [CLI reference](https://docs.tunneltend.com/cli/) lists every command, what it reads and what it changes.

Setup is complete when ChatGPT uses your chosen tool and returns a result you can check—for example, finding a known note through a notes-search MCP server. Installing TunnelTend or seeing a green status is a useful step along that route, not the final check.

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

[GitHub Releases](https://github.com/Wolfsblvt/tunneltend/releases/latest) carries the latest available TunnelTend version, its downloads and change notes. TunnelTend supports Windows 11 with PowerShell 7.4 or newer. Sign-in startup, sleep/resume recovery and a real remote tool call from ChatGPT were observed during the original 1.0 qualification; the [1.0.0 release notes](https://github.com/Wolfsblvt/tunneltend/releases/tag/v1.0.0) name the tested client versions and limits. TunnelTend is an independent open-source project and is not affiliated with OpenAI.
