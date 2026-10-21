# OpenAI tunnel-client current snapshot

## Meaning

This record pins the stable official-client release and command surface used while qualifying the current TunnelTend adapter. The release coordinate, verified Windows amd64 download, version output, and six help-based capability probes were refreshed on 2026-10-21 for v0.0.17. Acquisition and capability evidence covers that binary. Earlier connected runtime and remote-consumer proof covers v0.0.16; it is not relabeled as a connected v0.0.17 run.

- Repository: `openai/tunnel-client`
- Stable release: `v0.0.17`
- Published: 2026-10-21
- Source commit/tag: `v0.0.17`, `a248b7f725fc989c1eb26680cf4351ee33421f61`
- Release checksum asset: `SHA256SUMS.txt`
- Windows release assets: architecture-specific ZIPs with published SHA-256 material
- Generated release coordinate: [`openai-tunnel-client-release.json`](openai-tunnel-client-release.json)
- Downloaded asset: `tunnel-client-v0.0.17-windows-amd64.zip`
- Archive SHA-256: `b89074637596262067061308cf174959561a1a8bcffe2db956650dad7303052b`, verified against the GitHub release-asset digest.

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

## Startup admission source check

On 2026-10-16 the stable release remained v0.0.16. Its [connect manager](https://github.com/openai/tunnel-client/blob/v0.0.16/pkg/codexplugin/manager.go#L473-L480) returns structured payload error code 2 when launch health is not yet established; the [command](https://github.com/openai/tunnel-client/blob/v0.0.16/cmd/client/runtimes_command.go#L106-L130) writes that payload even on failure. Connect has no startup-wait option. The payload can report a newly launched, running process in `starting` state.

TunnelTend admits only that specific code-2 transition, with boolean launch/running flags, the requested alias and the explicit tunnel identity when configured, to its existing bounded observation. Other nonzero results remain failures. Startup, restart, recovery and client fleet restoration require observed health, readiness and a running official runtime before reporting success. A launch acknowledgement alone is insufficient; stopped or mismatched process identity and readiness timeout remain failures.

Credential-free regressions exercise this transition and the updater's restoration/rollback path through the real adapter and reconciler, with the external CLI boundary doubled.


## v0.0.17 compatibility refresh

The official release strengthens retry behavior during startup discovery and MCP initialization, and keeps readiness false until its startup catalog is ready. These startup retries do not replay MCP tool calls. Existing configurations retain their defaults; optional tracing and expanded request-ID forwarding are not enabled by TunnelTend. The full-client package updates its bundled cloudflared companion.

The public TunnelTend updater acquired the primary Windows amd64 archive with published-checksum verification, guarded extraction, staged version/capability checks and transactional installation into isolated disposable paths. All six existing capability probes passed against the actual executable. Runtime list/status/connect/stop/remove help remains available; the adapter continues to require a running, healthy and ready runtime rather than treating a launch acknowledgement as success. No runtime adapter change was required by these probes.

This refresh does not claim a newly credentialed remote session on v0.0.17. The October 19 real sign-in, resume recovery and remote Unicode echo retain their v0.0.16 execution boundary. See the [official release account](https://github.com/openai/tunnel-client/releases/tag/v0.0.17) for its changed readiness semantics and optional flags.

## Acceptance boundary

Actual Windows acquisition and the required capability surface were exercised for the exact downloaded v0.0.17 binary. Live connected control-plane behavior on that new binary remains unobserved. Source inspection and release metadata support adapter design but do not prove Windows process, control-plane, or runtime behavior.
