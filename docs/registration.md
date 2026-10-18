# Service registration

Register the target you want TunnelTend to manage. A registration survives a failed first start, so you can inspect and fix its configuration without losing the service definition.

[Get started](getting-started.md) covers installation, an existing OpenAI tunnel ID, and runtime credential references. The examples below assume those prerequisites. Replace every example path, URL, and tunnel ID with your own.

## Choose a registration method

| You have | Use |
| --- | --- |
| A project directory with one clear launch target | [Project registration](#register-a-project) |
| An exact stdio MCP launch command | [Command registration](#register-a-command) |
| A reachable HTTP MCP endpoint | [HTTP registration](#register-an-http-endpoint) |
| A runtime already configured in the official client | [Alias import](#import-an-existing-official-alias) |
| A project that ships a reusable service definition | [A project descriptor](#use-a-project-descriptor) |

## Service IDs, aliases, and tunnel IDs

| Name | Meaning |
| --- | --- |
| Service ID | TunnelTend's local identifier, used in commands such as `service stop my-mcp`. Inspect it with `service list`. |
| Official alias | The official client's local runtime name. It defaults from the registration unless you select `--alias`. TunnelTend will not silently take over an existing alias. |
| Tunnel ID | The OpenAI-hosted tunnel's identifier. Supply an existing one with `--tunnel-id`; it is not the service ID. |
| Organization/workspace IDs | Upstream scope selectors. They must describe an authorized OpenAI context; passing them does not grant access. |

## Register a project

```powershell
tunneltend service register 'C:\src\my-mcp' --id my-mcp `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

TunnelTend prefers a `tunneltend.service.json` descriptor when present. Otherwise it conservatively inspects known package scripts and likely .NET, Python, PowerShell, or executable entry points. It requires explicit input when there is no clear candidate or more than one candidate. Discovery does not install dependencies or establish that the selected program implements MCP correctly.

Normal registration saves and starts the service. Add `--no-start` when you want to inspect the saved definition first, then use `service show my-mcp`, `doctor my-mcp`, and an explicit `service start my-mcp` when ready.

## Register a command

For a stdio MCP service, name the executable and pass each argument separately:

```powershell
tunneltend service register --id my-mcp --command pwsh `
  --arg=-NoProfile --arg=-NonInteractive --arg=-File `
  --arg 'C:\src\my-mcp\server.ps1' `
  --working-directory 'C:\src\my-mcp' `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

The official client launches a command-backed MCP service. Set its working directory explicitly when relative paths or project files matter. A restart uses that registered directory, not whichever directory you happen to be in later.

Repeat `--arg` for each argument. Values preserve whitespace, commas, quotes, and backslashes. Use `--arg=VALUE` for a value beginning with `--`, and `--arg=` for an empty argument. Quote a whole value containing spaces; do not combine the executable and every argument into one shell command string.

## Register an HTTP endpoint

```powershell
tunneltend service register --id docs-mcp `
  --url http://127.0.0.1:3001/mcp `
  --health-url http://127.0.0.1:3001/health `
  --tunnel-id YOUR_EXISTING_TUNNEL_ID `
  --runtime-key-ref env:CONTROL_PLANE_API_KEY
```

Use the service's MCP endpoint, not an ordinary home page. The example health URL assumes that service actually provides a suitable health endpoint; omit it if it does not. A distinct readiness endpoint can be selected with `--ready-url`.

A URL-only registration connects to an already reachable server. It does not infer how to start that HTTP server. The endpoint can be local or reachable elsewhere from this host. When TunnelTend should also start a local HTTP host process, use a descriptor with an explicit host command. See the [HTTP descriptor example](../examples/tunneltend.service.http.json).

## Choose startup and watching

| Registration option | Effect |
| --- | --- |
| `--no-start` | Save the definition without the immediate first start. |
| `--no-autostart` | Do not automatically start this service at later sign-ins. It does not prevent immediate registration startup. |
| `--no-watchdog` | Disable watchdog recovery for this service. |
| `--no-source-watch` | Disable source watching for this registration. |
| `--disabled` | Register it disabled. |

Project-path registration enables source watching by default. Command-only and URL-only registration do not infer a project path to watch. A descriptor can specify source policy explicitly.

Watching detects stable local changes and can restart the service. It does not infer a build, dependency update, migration, or deployment. Read [source watching and application updates](OPERATIONS.md#source-watching-and-application-updates) before relying on either behavior.

## Import an existing official alias

Inspect the official client's existing runtime configuration and your TunnelTend registry before importing. To import one known alias:

```powershell
tunneltend service import existing-alias
tunneltend service list
tunneltend doctor --json
```

Import without an alias selects the available official aliases. Use that broader operation only when all of them should be managed. An imported running runtime can be recognized as active; import itself is not proof of a remote MCP call.

If an alias already exists upstream when a new registration tries to start, TunnelTend refuses silent adoption. After reviewing the upstream target, use `tunneltend service import existing-alias --force` to deliberately adopt it and replace the corresponding local definition. This preserves an existing service ID associated with that alias; it does not authorize two services to control the same alias.

Choose one lifecycle owner. In particular, do not leave a manually managed stdio runtime running while starting another official runtime for the same tunnel ID. [The official client](https://github.com/openai/tunnel-client#readme) owns the upstream concurrency rules.

## Use a project descriptor

A project can ship `tunneltend.service.json` to make its intended launch and policy explicit. Project registration reads that descriptor before discovery. Maintainers can use the [command example](../examples/tunneltend.service.command.json), [HTTP example](../examples/tunneltend.service.http.json), and [service schema](../schemas/service.schema.json) to author a reusable definition.

Descriptors can describe a host command, probes, source paths and exclusions, recovery settings, and an explicit application-update command. Replace sample paths and scope IDs. Keep secrets as `env:` or `file:` references; likely inline credentials in commands, arguments, environment values, or URLs are rejected before saving.

Do not edit the installed registry JSON as the normal setup workflow. Use registration, policy commands, and supported configuration. If you replace an existing definition, review the complete new target and policy; `--force` is deliberate replacement, not a general fix for failed startup.

## Verify or remove a registration

Use `service show ID`, `status ID`, `health ID`, and `doctor ID` to inspect the result. Follow [the consumer verification step](getting-started.md#verify-the-whole-connection) before calling the connection complete.

`service remove ID` stops the service and unregisters it; a failed safe stop prevents removal. `service remove ID --keep-running` removes TunnelTend's supervision while leaving its processes running. Neither command deletes your project source or removes the remote OpenAI tunnel object. [Operations](OPERATIONS.md#manual-intent) covers stop, disable, and restart when you want to keep the registration.
