---
title: "Register a service"
description: "Register a project folder, a launch command, an HTTP MCP endpoint or an existing official alias, with the credential reference and startup policy you intend."
---

Registering tells TunnelTend what to keep running: which MCP server, how to start it, which OpenAI tunnel it uses, and how it should behave at sign-in. A registration survives a failed first start, so you can inspect and fix it without losing the definition.

[Get started](https://docs.tunneltend.com/getting-started/) covers installation, your existing OpenAI tunnel ID and the runtime credential reference. The examples below assume those are ready. Replace every example path, URL and tunnel ID with your own.

## Choose a registration method

| You have | Use |
| --- | --- |
| A project folder with one clear way to launch it | [Register a project](#register-a-project) |
| An exact command that starts a stdio MCP server | [Register a command](#register-a-command) |
| An HTTP MCP endpoint that is already reachable | [Register an HTTP endpoint](#register-an-http-endpoint) |
| A runtime already set up in the official client | [Import an existing official alias](#import-an-existing-official-alias) |
| A project that ships its own service definition | [Use a project descriptor](#use-a-project-descriptor) |

A *stdio* MCP server is a program that talks to the assistant through its own input and output streams; the official client launches it. An *HTTP* MCP server is one you run yourself, reachable at a URL.

## Service IDs, aliases and tunnel IDs

Four names show up around one service. They are not interchangeable.

| Name | Meaning |
| --- | --- |
| Service ID | TunnelTend's local name for the service, used in commands such as `service stop my-mcp`. See them all with `tunneltend service list`. |
| Official alias | The official client's own local name for the runtime. It is derived from the registration unless you choose one with `--alias`. TunnelTend never silently takes over an alias that already exists. |
| Tunnel ID | The identifier of the tunnel OpenAI hosts for you. Supply an existing one with `--tunnel-id`. It is not the service ID. |
| Organization and workspace IDs | Selectors for the OpenAI scope the tunnel belongs to (`--organization-id`, `--workspace-id`). They describe an authorized context; passing them grants nothing. |

## Register a project

```powershell
tunneltend service register 'C:\src\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

If the folder contains a `tunneltend.service.json` descriptor, TunnelTend uses it. Otherwise it looks, conservatively, at known package scripts and likely .NET, Python, PowerShell or executable entry points. When there is no clear candidate, or more than one, it stops and tells you which explicit command to run instead. It never guesses.

Discovery does not install dependencies and does not check that the program it found actually speaks MCP. Make sure the tool runs on its own first.

Normal registration saves the service and starts it right away. Add `--no-start` if you want to look at the saved definition first, then use `tunneltend service show my-mcp`, `tunneltend doctor my-mcp` and an explicit `tunneltend service start my-mcp` when you are ready.

## Register a command

For a stdio MCP server, name the executable and pass each argument separately:

```powershell
tunneltend service register --id my-mcp --command pwsh `
  --arg=-NoProfile --arg=-NonInteractive --arg=-File `
  --arg 'C:\src\my-mcp\server.ps1' `
  --working-directory 'C:\src\my-mcp' `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

The official client launches the command. Set `--working-directory` whenever relative paths or project files matter: every later restart uses that registered folder, not whichever folder you happen to be in.

Repeat `--arg` for each argument. Values keep their whitespace, commas, quotes and backslashes exactly. Use `--arg=VALUE` for a value that itself begins with `--`, and `--arg=` for an empty argument. Quote a whole value that contains spaces. Do not squash the executable and all its arguments into one shell string.

## Register an HTTP endpoint

```powershell
tunneltend service register --id docs-mcp `
  --url http://127.0.0.1:3001/mcp `
  --health-url http://127.0.0.1:3001/health `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

Use the server's MCP endpoint, not its home page. `--health-url` only makes sense if the server really offers a health endpoint; leave it out otherwise. A separate readiness endpoint can be named with `--ready-url`.

A URL-only registration connects to a server that is already running. TunnelTend does not work out how to start it. The endpoint may be on this PC or anywhere this PC can reach. If TunnelTend should also start the HTTP server for you, use a descriptor with an explicit host command; see the [HTTP descriptor example](https://github.com/Wolfsblvt/tunneltend/blob/main/examples/tunneltend.service.http.json).

## Credential references

TunnelTend never stores a raw runtime key. You register a *reference*, and the key stays in your environment or in a file you protect:

```text
env:CONTROL_PLANE_API_KEY
file:C:\secure\runtime-key.txt
```

The default is `env:CONTROL_PLANE_API_KEY`. The source must be readable by the Windows account that runs the Scheduled Tasks; a variable set only in your current terminal is not. Anything that looks like an inline secret in a command, argument, environment value, descriptor or URL is rejected before it is saved. [Prepare your OpenAI access](https://docs.tunneltend.com/getting-started/#prepare-your-openai-access) explains where the key comes from.

## Choose startup and watching

| Option | Effect |
| --- | --- |
| `--no-start` | Save the definition without the immediate first start. |
| `--no-autostart` | Do not start this service automatically at later sign-ins. It does not stop the immediate start during registration. |
| `--no-watchdog` | Turn off watchdog recovery for this service. |
| `--no-source-watch` | Turn off source watching for this registration. |
| `--disabled` | Register the service disabled. |

Project registration turns source watching on by default: stable changes to the project's files restart the service. Command-only and URL-only registrations have no project folder to watch. A descriptor can set source policy explicitly.

Watching notices local file changes and restarts; it never runs a build, installs dependencies, pulls from Git or deploys anything. Read [source watching and application updates](https://docs.tunneltend.com/operations/#source-watching-and-application-updates) before relying on either.

## Import an existing official alias

If the official client already has a runtime configured for this tunnel, import it instead of starting a competing one. Look at the official client's configuration and `tunneltend service list` first. Then:

```powershell
tunneltend service import existing-alias
tunneltend service list
tunneltend doctor --json
```

`service import` without an alias selects all available official aliases. Use that only when every one of them should be managed by TunnelTend. A runtime that is already running can be recognized as active after import; import itself does not prove that a tool call from ChatGPT works.

When a new registration tries to start and its alias already exists upstream, TunnelTend refuses to adopt it silently. After you have reviewed what that alias points at, adopt it deliberately:

```powershell
tunneltend service import existing-alias --force
```

That replaces the matching local definition with the upstream target and keeps an existing service ID that was associated with the alias. It never lets two services control the same alias.

:::caution
Choose one owner for each runtime. Do not leave a hand-started stdio runtime running while TunnelTend starts another official runtime for the same tunnel ID. The [official client](https://github.com/openai/tunnel-client#readme) owns the rules for concurrent runtimes.
:::

## Use a project descriptor

A project can ship a `tunneltend.service.json` file that states exactly how it should be launched and operated. Project registration reads the descriptor before it tries discovery. The [command example](https://github.com/Wolfsblvt/tunneltend/blob/main/examples/tunneltend.service.command.json), the [HTTP example](https://github.com/Wolfsblvt/tunneltend/blob/main/examples/tunneltend.service.http.json) and the [service schema](https://github.com/Wolfsblvt/tunneltend/blob/main/schemas/service.schema.json) show what it can contain.

A descriptor can describe a host command, health and readiness probes, watched paths and exclusions, recovery settings and an explicit application-update command. Replace the sample paths and scope IDs. Keep secrets as `env:` or `file:` references; likely inline credentials are rejected.

Do not edit TunnelTend's installed registry JSON by hand. Use registration, the policy commands and `tunneltend config`. If you replace an existing definition, review the whole new target and policy: `--force` means deliberate replacement, not a shortcut around a failed start.

## Verify or remove a registration

Inspect the result with `tunneltend service show ID`, `tunneltend status ID`, `tunneltend health ID` and `tunneltend doctor ID`. Then do [the one check that counts](https://docs.tunneltend.com/getting-started/#verify-the-whole-connection): a real, harmless tool call from ChatGPT.

`tunneltend service remove ID` stops the service and unregisters it; if a safe stop fails, removal is refused. `tunneltend service remove ID --keep-running` withdraws TunnelTend's supervision but leaves the processes running. Neither touches your project files or the tunnel object at OpenAI. To keep the registration but stop, disable or restart the service, see [Everyday operation](https://docs.tunneltend.com/operations/#stop-a-service-on-purpose).
