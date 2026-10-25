---
title: "Use TunnelTend through an agent"
description: "TunnelTend is designed to be installed, watched and operated by a local coding agent: what makes that safe, the sentences that work, and where the agent must stop."
identity:
  social:
    eyebrow: Documentation
---

You do not have to learn TunnelTend's commands to use it. A local coding agent, such as Codex running on the Windows PC where your tools live, can install it, register a service, read what it observes and change what you ask for. You say what you want in plain words; the agent runs the commands and reports the facts. This page explains why that is safe, what to say, and where the agent must stop.

## Why TunnelTend is comfortable with agents

TunnelTend was built from the ground up to be operated by software as well as by people:

- **Reading, planning and changing have separate commands.** `status`, `health`, `doctor`, `repair` and `reconcile --plan` only look; they persist nothing. Changing anything needs a command such as `service start`, `repair --apply` or `client update`. The agent must choose the command that matches what you asked for. See [Service state](https://docs.tunneltend.com/service-state/).
- **Every command answers in one stable JSON envelope** with `--json`: `schema_version`, `command`, `status` (`ok`, `degraded`, `error`, `planned`, `changed`, `noop`), `data`, `diagnostics` and `actions`. An agent reads the same facts a person reads as text. See the [CLI reference](https://docs.tunneltend.com/cli/#json-output).
- **It refuses to guess.** Ambiguous project discovery reports candidate types and reasons, then asks for a descriptor or explicit command. It does not generate the correct command; the agent needs the server's launch instructions. Missing required scope or an unavailable credential reference is reported rather than invented.
- **Secrets use references.** Give the agent `env:CONTROL_PLANE_API_KEY` or `file:C:\secure\runtime-key.txt`, never the key. The supported workflow lets it install and operate TunnelTend without reading the raw value.
- **Ownership is proven before anything is stopped.** A recorded PID is only touched when its executable path and start time still match. An agent asked to "fix it" cannot make TunnelTend kill an unrelated process. See [Security](https://docs.tunneltend.com/security/).
- **Exit codes mean something.** `0` success, `2` degraded or failed operations, `4` a command that failed validation or execution, so a script or an agent can tell them apart without parsing prose.

## Things you can say

Give the agent the task in your own words. These sentences map to real commands; the agent will fill in the details it can observe and ask you for the ones it cannot (your tunnel ID, your credential reference, which service you mean).

If you know the app but not its MCP details yet, start with [Find your MCP service](https://docs.tunneltend.com/getting-started/#find-your-mcp-service) and hand the agent the app's setup instructions. The service names and paths below are examples, not bundled integrations or a claim that any particular add-on has been tested with TunnelTend.

| Say | The agent runs |
| --- | --- |
| "Install TunnelTend for my current Windows user and register the MCP service I identify, following https://docs.tunneltend.com/install-with-an-agent/" | The [install handoff](https://docs.tunneltend.com/install-with-an-agent/): the one-line installer, registration, the read-only checks. |
| "Connect my Blender MCP add-on to ChatGPT through TunnelTend: register it from `C:\src\blender-mcp` with my existing tunnel ID, start it, and show me status and doctor." | `tunneltend service register C:\src\blender-mcp --id blender-mcp --tunnel-id … --runtime-key-ref env:…`, then `status` and `doctor` with `--json`. |
| "My notes-search service shows as unhealthy. Find out why and fix what you safely can." | `tunneltend doctor notes-search --json`, `tunneltend repair notes-search` (the plan), then `tunneltend repair notes-search --apply` only if the plan is sensible. |
| "Stop my photo-tagger service until I sign in again." | `tunneltend service stop photo-tagger --session-only`. Without the flag, the stop is durable. |
| "Turn off automatic restarts for my database tool, I will start it by hand." | `tunneltend service watchdog db-tool off` and, if asked, `tunneltend service autostart db-tool on` or `off`. |
| "Check whether OpenAI's tunnel client has a newer stable release and update it." | `tunneltend client update --check-only`, then `tunneltend client update`, then `tunneltend client status --json`. |
| "Show me everything TunnelTend is managing and whether it is healthy." | `tunneltend status --json`, `tunneltend health --json`, `tunneltend automation status --json`. |
| "Remove TunnelTend but keep my registrations in case I come back." | The uninstaller without `-PurgeState`; see [Uninstall](https://docs.tunneltend.com/operations/#uninstall). |

The [home page](/#agents) has copy buttons for the most common sentences.

## Where the agent must stop

These are boundaries for the agent's workflow. TunnelTend's command checks help enforce its own rules; they do not control everything an agent can do on your computer:

- **Your OpenAI access.** Creating a tunnel, getting a runtime key, adding a connector in ChatGPT: those happen in your OpenAI organization and in ChatGPT, under your account. You sign in yourself; an agent carries one of these steps only when you explicitly authorize that exact step. See [Prepare your OpenAI access](https://docs.tunneltend.com/getting-started/#prepare-your-openai-access).
- **Any secret.** The agent asks you to put the key in an environment variable or a protected file and uses only the reference. If it ever asks you to paste a key into the chat, refuse.
- **Anything it cannot verify.** `status` showing `running` is a local fact. Whether ChatGPT can actually use your tool is proven by [one real tool call](https://docs.tunneltend.com/getting-started/#verify-the-whole-connection), and a careful agent says so instead of declaring success.
- **Your intent.** A deliberate stop stays stopped. An agent should not "repair" a service you stopped on purpose, and TunnelTend's watchdog will not either.

A cloud-only chat without access to your computer can explain all of this but cannot run it. The agent has to be on the Windows PC where your tools live.
