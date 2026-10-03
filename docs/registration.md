# Service registration

## Meaning

This guide explains how users create durable registered services through descriptors, explicit command or URL targets, conservative discovery, and official-runtime import. It preserves the no-hand-written-JSON normal journey and ambiguity refusal.

Registration accepts a project path, explicit command, explicit MCP URL, or an existing official runtime.

Project discovery is intentionally conservative. A `tunneltend.service.json` descriptor wins. Otherwise known package scripts and likely .NET, Python, PowerShell, or executable entries are inspected. Zero candidates or multiple candidates require explicit input.

A service may include an optional host command for a local HTTP MCP service. Command MCP services are launched by the official client itself.

Descriptors conform to `schemas/service.schema.json`. Store only `env:` or `file:` secret references.

See `examples/` for reviewed patterns.
