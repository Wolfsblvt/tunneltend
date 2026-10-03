# Test fixtures

## Meaning

This directory is reserved for small synthetic, credential-free fixtures that preserve meaningful parser, archive, state, and recovery behavior. It must never contain copied user state, live identifiers, secrets, or an official client binary.

Keep fixtures synthetic and credential-free. Release and malicious-archive fixtures belong here only when they are small and reviewed. Never commit copied user state or an official client binary.

## Included fixture

`mcp-stdio-echo.ps1` is a dependency-free MCP stdio server for disposable Windows qualification. It implements initialization, ping, tool discovery, and one deterministic `echo` tool. It writes protocol messages only to stdout and requires no credentials or network access.
