---
title: "How it works"
description: "What MCP, a tunnel and OpenAI’s official client are, which pieces run on your Windows PC, and what TunnelTend looks after for you."
identity:
  social:
    eyebrow: Documentation
---

You have an app, a folder of files, a database or a script on your Windows PC, and you want ChatGPT to use it. An MCP server makes the chosen information or actions available; OpenAI’s tunnel connects it; TunnelTend looks after the local processes. This page explains those pieces in plain words.

For example, suppose you have a notes-search MCP server configured to read a folder you chose. You ask ChatGPT to find a note, the server searches that folder, and the result comes back to the conversation. TunnelTend helps keep the server and its tunnel running after setup. It does not supply a notes-search server or choose which files it can read.

## The chain, from your PC to ChatGPT

| Piece | Where it runs | What it does |
| --- | --- | --- |
| Your app or tool | your PC | The thing you actually want ChatGPT to use: notes, files, a local database, a home server, a script. |
| MCP server | your PC | A small program that offers your tool to AI assistants in a standard way. |
| OpenAI’s official `tunnel-client` | your PC | OpenAI’s own program. It opens one secure connection out to OpenAI and carries the MCP traffic. |
| Secure MCP Tunnels | OpenAI | OpenAI’s hosted side of that connection. No public port on your router is involved. |
| ChatGPT (or another OpenAI consumer) | OpenAI | Uses your tool through a connector you set up once, under your organization’s rules. |

Your tool, its MCP server and the official client are the three local pieces in this example. TunnelTend tends the MCP service and the official client; it does not replace any of the pieces, and it is not an OpenAI product. [See the connection on the home page](/#how).

## MCP, in one paragraph

The Model Context Protocol ([MCP](https://modelcontextprotocol.io/)) is the standard way an AI assistant asks a program for information or actions. The program that answers is called an *MCP server*. It wraps your tool and exposes “tools” (things the assistant can do) and “resources” (things it can read). Many tools already ship an MCP server; others need one written, which is ordinary developer work and outside what TunnelTend does for you.

An MCP server speaks in one of two ways. A **stdio** server is a command: something launches it, and it talks through its standard input and output, like a program inside a terminal. An **HTTP** server listens on a local web address, such as `http://127.0.0.1:3000/mcp`, and answers requests there. TunnelTend can register either: a command it launches for you, or an HTTP endpoint you already run. Either way, you need an MCP server that already works on its own before anything else.

An ordinary folder, app shortcut or website address is not enough. Look for an MCP setup section in your tool’s documentation. If you cannot find one, [Find your MCP service](https://docs.tunneltend.com/getting-started/#find-your-mcp-service) gives you a next step without guessing a command.

## A tunnel, in one paragraph

Your PC normally cannot be reached from the internet, and that is a good thing. A tunnel turns that around safely: OpenAI’s official client on your PC opens one outbound, authenticated connection to OpenAI, and ChatGPT talks to your MCP server through that connection. Nothing is exposed on your router, no port forwarding is needed, and the connection only exists while the client is running and signed in to your OpenAI organization with a valid runtime key.

OpenAI owns this part end to end: the client program, the tunnel protocol, the hosted infrastructure and the access rules. Read OpenAI’s [Secure MCP Tunnels guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) for what it is and which OpenAI products can consume it. The [home page](/#openai) lists exactly what you need from OpenAI before you start.

## What the official client does not do for you

The official client connects. It does not remember which services you wanted, start them when you sign in to Windows, notice when one has quietly died, restart it, or update itself. If you run one tunnel and never restart your PC, you may never miss any of that. Most people restart, sleep, sign out, and forget.

## What TunnelTend owns

| Part | Its job |
| --- | --- |
| Your MCP server | Implements the tools and resources. Runs as a command or serves an HTTP endpoint. |
| OpenAI’s official `tunnel-client` | Carries the MCP connection and owns the upstream runtime and tunnel protocol. The TunnelTend installer downloads and verifies it as a separate program. |
| TunnelTend | Saves service registrations and operating policy; manages configured processes, official runtimes, Windows Scheduled Tasks, bounded recovery and client maintenance. |
| Your consumer (ChatGPT) | Uses the tunnel from an eligible OpenAI product. Its account, connector and permissions remain your setup on OpenAI’s side. |

TunnelTend runs on your PC. There is no TunnelTend account, no TunnelTend cloud and no central control plane. MCP traffic still passes through OpenAI’s infrastructure, so local-first does not mean offline; [Privacy and data](https://docs.tunneltend.com/privacy-and-data/) says what stays where.

TunnelTend does **not** implement the tunnel protocol, host anything, manage secrets for you, run `git pull`, builds, dependency updates or migrations, or promise that every broken dependency can be repaired automatically.

## Register once

You register a service once, with one command. TunnelTend saves what you intend: which program or endpoint, which OpenAI tunnel, where the runtime key lives (as a reference such as `env:CONTROL_PLANE_API_KEY`, never the key itself), and your policy for startup, watching and recovery.

Normal registration starts the service immediately. If that first start fails, the registration is kept so you can read `tunneltend doctor` and fix the cause; it does not vanish because one dependency was missing. [Register a service](https://docs.tunneltend.com/registration/) covers project folders, commands, HTTP endpoints and existing official aliases.

## The words you will see in status

`tunneltend status` separates facts that people often blur into “up”:

| Word | Roughly means |
| --- | --- |
| registered | TunnelTend knows this service and its settings. |
| desired | What you intend: `running` or `stopped`, durably. |
| observed | What TunnelTend actually sees right now: process present, runtime present, stopped, unknown. |
| healthy | The health checks you configured passed on the last look. |
| ready | The readiness check you configured passed, meaning the service says it can take requests. |

A healthy, ready service on your PC still does not prove ChatGPT can reach it; that proof is one real tool call from ChatGPT. [Service state](https://docs.tunneltend.com/service-state/) explains each dimension and why they stay separate.

## Three Scheduled Tasks do the routine

The installer creates three Windows Scheduled Tasks for your user account, under `\TunnelTend\`. Each one can be turned off.

| Task | When | What it does |
| --- | --- | --- |
| TunnelTend Startup | shortly after you sign in to Windows | Starts the registered services you intend to run and opens a fresh session. |
| TunnelTend Watchdog | every two minutes | Checks that intended services are present and healthy; recovers missing or unhealthy ones within a visible attempt budget and backoff. Leaves deliberately stopped services alone. |
| TunnelTend Maintenance | once a day | Checks for a newer stable release of OpenAI’s client, verifies it, stages it, swaps it in with a backup, restores your services, and rolls back if anything fails. |

Because these are current-user tasks, the computer and your signed-in session matter. A sleeping, signed-out or powered-off PC serves nothing, and TunnelTend will not tell you otherwise. [Everyday operation](https://docs.tunneltend.com/operations/) covers deliberate stops, recovery limits, source watching and client updates in detail.

## Next

- [Get started](https://docs.tunneltend.com/getting-started/): prerequisites, OpenAI access, installation, your first service and the one real check.
- [Install with an agent](https://docs.tunneltend.com/install-with-an-agent/): the same setup, handed to a local coding agent.
- [FAQ](/faq/): fit, cost, the OpenAI relationship and what happens when the PC sleeps.
