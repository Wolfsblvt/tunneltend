# OpenAI tunnel-client current snapshot

## Meaning

This maintained record separates the latest stable official-client release observed upstream from the release acquired and exercised through TunnelTend's compatibility path. On 2026-10-25, the generated release coordinate and disposable Windows qualification were refreshed to v0.0.18. Earlier connected runtime and remote-consumer proof still covers v0.0.16; it is not relabeled as a connected run on either later release.

- Repository: `openai/tunnel-client`
- Latest stable release observed: `v0.0.18`
- Published: 2026-10-23
- Latest source tag/commit: `v0.0.18`, `274a5588414819f063d27100a4fb1096aae3830f`
- Latest official checksum asset digest observed: `sha256:63f9996246424301c8b0680c943c67d0ea7fe2f0853a234649104f8062c67329`
- Latest official Windows amd64 asset digest observed: `sha256:8d0da1ce79532d44ccc5ed5d8bd36cdfffba37dfd287c602d69635c8bb5db2b2`
- Latest official Windows arm64 asset digest observed: `sha256:b73237513d50bf7acbeb960d80d9cbb6513879292f80ec1bd04b886fac1fe1c8`
- Generated release coordinate: [`openai-tunnel-client-release.json`](openai-tunnel-client-release.json), refreshed from the official latest-stable API to `v0.0.18`
- Last downloaded and exercised asset: `tunnel-client-v0.0.18-windows-amd64.zip`
- Published archive SHA-256, verified by TunnelTend's updater before extraction: `8d0da1ce79532d44ccc5ed5d8bd36cdfffba37dfd287c602d69635c8bb5db2b2`

The amd64 archive digest above matches the official release asset digest that TunnelTend's updater reported verifying before extraction. The separate Windows executable hash below identifies the installed binary after qualification; it is not the archive hash. The generated JSON was refreshed from the official latest-stable API rather than hand-edited from rounded web presentation.

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

## v0.0.18 compatibility refresh on Windows 11

The official release adds three optional capability families: AWS workload identity for production control-plane authentication, explicit loopback HTTP access in Harpoon templates, and per-attempt response-upload tracing. Existing API-key deployments remain supported. The AWS route introduces provider identity, STS and authentication-network assumptions that are not part of TunnelTend's current local Windows registration model; the Harpoon and tracing additions are official-client behavior outside the adapter surface TunnelTend currently configures. No product expansion is selected by observing them.

The existing TunnelTend route refreshed the snapshot directly from the official stable-release API and acquired the real Windows amd64 archive through `tunneltend client update` in disposable current-user paths. The updater reported verification against GitHub's published asset digest before installation. The installed binary reported v0.0.18 / commit `274a5588414819f063d27100a4fb1096aae3830f`; its executable SHA-256 was `9d0a22b7eb64fe7c5e34dfc97273ffcab6a07557855cf9e7f8869068402caf6b`.

`client status` returned `compatible: true`, with exit code 0 for all six existing probes: `version`, `runtimes`, `runtimes-json`, `runtime-status`, `runtime-connect`, and `runtime-stop`. A second forced updater run exercised the Windows replacement transaction against the same v0.0.18 binary. It returned success, retained a v0.0.18 backup, and the backed-up executable hash equalled the active executable hash. No registered service or credential was present, so this proves the isolated installation and replacement path, not stopping/restoring a connected fleet or rollback after a live failure. The run did not exercise an upgrade transition from the v0.0.17 binary.

No adapter change was required by the six probes. A connected control-plane session, runtime fleet, and consumer journey on v0.0.18 remain unobserved. The exact Windows executable and replacement evidence do not establish every upstream behavior or service compatibility.

## Acceptance boundary

Actual Windows acquisition, published-digest verification, installed-binary hashing, all six capability probes, and same-version transactional replacement were exercised for v0.0.18 in disposable paths. A v0.0.17-to-v0.0.18 upgrade, live fleet restoration/rollback, connected control-plane behavior, and consumer journey on v0.0.18 remain unobserved. Earlier connected runtime and consumer evidence remains bounded to v0.0.16. Source and release metadata alone still do not prove those unexercised behaviors.
