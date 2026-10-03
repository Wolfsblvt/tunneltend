# OpenAI tunnel-client current snapshot

## Meaning

This record pins the stable official-client release and command surface used while qualifying the current TunnelTend adapter. It is compatibility evidence captured from primary GitHub release/source data on 2026-10-04, not an assertion that every future release remains compatible.

- Repository: `openai/tunnel-client`
- Stable release: `v0.0.15`
- Published: 2026-09-25
- Source commit/tag: `v0.0.15`
- Release checksum asset: `SHA256SUMS.txt`
- Windows release assets: architecture-specific ZIPs with published SHA-256 material
- Generated release coordinate: [`openai-tunnel-client-release.json`](openai-tunnel-client-release.json)

## Runtime command surface used by TunnelTend

```text
tunnel-client runtimes list --json
tunnel-client runtimes status <alias> --json
tunnel-client runtimes connect --alias <alias> ... --json
tunnel-client runtimes stop <alias> --json
tunnel-client runtimes rm <alias> --json
```

The current `connect` surface includes organization/workspace scope, existing tunnel ID, profile/profile directory, MCP server URL or MCP command, runtime API-key reference, admin profile/key, and control-plane overrides.

## Structured behavior relied upon

- Managed aliases have stable local records.
- Status reports runtime/process/health state in JSON.
- Native supervision records PID plus process start time and executable identity.
- Stop verifies owned process identity rather than signaling a bare reused PID.
- Runtime profiles support `server_url` and `command` MCP targets.
- Stdio MCP commands are parsed by the official client's command-string parser, so TunnelTend renders registered executable/argument arrays into that grammar inside its adapter.
- `env:NAME` and `file:path` are accepted secret-reference forms.

## Acceptance boundary

TunnelTend still requires live compatibility qualification for the exact downloaded Windows binary. Source inspection and release metadata support adapter design but do not prove Windows process, control-plane, or runtime behavior.
