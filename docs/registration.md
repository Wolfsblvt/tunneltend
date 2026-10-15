# Service registration

## Meaning

This guide explains how users create durable registered services through descriptors, explicit command or URL targets, conservative discovery, and official-runtime import. It preserves the no-hand-written-JSON normal journey and ambiguity refusal.

Registration accepts a project path, explicit command, explicit MCP URL, or an existing official runtime.

Project discovery is intentionally conservative. A `tunneltend.service.json` descriptor wins. Otherwise known package scripts and likely .NET, Python, PowerShell, or executable entries are inspected. Zero candidates or multiple candidates require explicit input.

A service may include an optional host command for a local HTTP MCP service. Command MCP services are launched by the official client itself.

Descriptors conform to `schemas/service.schema.json`. Store only `env:` or `file:` secret references.

See `examples/` for reviewed patterns.

## Explicit command and HTTP targets

```powershell
tunneltend service register --id my-mcp --command pwsh --arg -NoProfile --arg -NonInteractive --arg -File --arg C:\src\my-mcp\server.ps1
tunneltend service register --id docs-mcp --url http://127.0.0.1:3001/mcp --health-url http://127.0.0.1:3001/health
```

Repeat `--arg` for each argument so boundaries remain explicit. Use `--no-start` to retain the definition without starting it. Supply `--tunnel-id`, `--organization-id`, or `--workspace-id` as appropriate for your existing OpenAI setup, and keep credentials in secret references.

Import existing official aliases with `tunneltend service import --all`. Inspect `service list` and `doctor` afterward; import does not itself prove a remote MCP call.
