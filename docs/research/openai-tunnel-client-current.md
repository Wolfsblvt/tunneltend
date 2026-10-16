# OpenAI tunnel-client current snapshot

## Meaning

This record pins the stable official-client release and command surface used while qualifying the current TunnelTend adapter. The release coordinate, verified Windows amd64 download, version output, and six help-based capability probes were observed on 2026-10-16. Remote control-plane and consumer behavior remain unobserved without credentials; this is not a claim of complete compatibility.

- Repository: `openai/tunnel-client`
- Stable release: `v0.0.16`
- Published: 2026-10-06
- Source commit/tag: `v0.0.16`, `5f99daabd4aa4a77049e6d81d54a0d8c18335397`
- Release checksum asset: `SHA256SUMS.txt`
- Windows release assets: architecture-specific ZIPs with published SHA-256 material
- Generated release coordinate: [`openai-tunnel-client-release.json`](openai-tunnel-client-release.json)
- Downloaded asset: `tunnel-client-v0.0.16-windows-amd64.zip`
- Archive SHA-256: `edef7241b0c647fcb30f1a80ff376b6b25c51927960f257a3f01e21b17c2aba6`, verified against the GitHub release-asset digest.

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

## Launch context source check

On 2026-10-16, the stable release remained [v0.0.16](https://github.com/openai/tunnel-client/releases/tag/v0.0.16). Its [native process starter](https://github.com/openai/tunnel-client/blob/v0.0.16/pkg/codexplugin/session/session.go#L1168-L1194) and [stdio command transport](https://github.com/openai/tunnel-client/blob/v0.0.16/pkg/mcpclient/stdio_command.go#L81-L92) do not replace the inherited working directory. TunnelTend supplies the registered directory when invoking `runtimes connect` and resolves the command executable against that same directory. Fixture process tests exercise directory inheritance through detachment and repeated launch for Node and npm; they double the official-provider boundary and do not establish connected upstream behavior.

## Acceptance boundary

TunnelTend still requires live compatibility qualification for the exact downloaded Windows binary. Source inspection and release metadata support adapter design but do not prove Windows process, control-plane, or runtime behavior.
