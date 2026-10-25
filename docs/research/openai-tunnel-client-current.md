# OpenAI tunnel-client current snapshot

## Meaning

This maintained record separates the latest stable official-client release observed upstream from the latest release actually acquired and exercised through TunnelTend's compatibility path. As of 2026-10-25, v0.0.18 is the latest stable release. Its `runtimes` command implementation is byte-identical in source to v0.0.17, but the exact Windows binary, generated release coordinate, and six capability probes have not been refreshed in this pass. v0.0.17 therefore remains the last accepted binary compatibility evidence. Earlier connected runtime and remote-consumer proof still covers v0.0.16; it is not relabeled as a connected run on either later release.

- Repository: `openai/tunnel-client`
- Latest stable release observed: `v0.0.18`
- Published: 2026-10-23
- Latest source tag/commit: `v0.0.18`, `274a5588414819f063d27100a4fb1096aae3830f`
- Latest official checksum asset digest observed: `sha256:63f9996246424301c8b0680c943c67d0ea7fe2f0853a234649104f8062c67329`
- Latest official Windows amd64 asset digest observed: `sha256:8d0da1ce79532d44ccc5ed5d8bd36cdfffba37dfd287c602d69635c8bb5db2b2`
- Latest official Windows arm64 asset digest observed: `sha256:b73237513d50bf7acbeb960d80d9cbb6513879292f80ec1bd04b886fac1fe1c8`
- Last accepted generated release coordinate: [`openai-tunnel-client-release.json`](openai-tunnel-client-release.json), still `v0.0.17`
- Last downloaded and exercised asset: `tunnel-client-v0.0.17-windows-amd64.zip`
- Last verified archive SHA-256: `b89074637596262067061308cf174959561a1a8bcffe2db956650dad7303052b`

The v0.0.18 digests above are release-page metadata, not a claim that TunnelTend downloaded or independently hashed those assets. The generated JSON remains at the last performed snapshot rather than being hand-edited from rounded web presentation.

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

## v0.0.18 upstream observation

The official release adds three optional capability families: AWS workload identity for production control-plane authentication, explicit loopback HTTP access in Harpoon templates, and per-attempt response-upload tracing. Existing API-key deployments remain supported. The AWS route introduces provider identity, STS and authentication-network assumptions that are not part of TunnelTend's current local Windows registration model; the Harpoon and tracing additions are official-client behavior outside the adapter surface TunnelTend currently configures. No product expansion is selected by observing them.

At tags `v0.0.17` and `v0.0.18`, `cmd/client/runtimes_command.go` resolves to the same Git blob, `728fed65c0619ba70e9057327b62dae28f41028f`. The command implementation behind TunnelTend's six help-based probes is therefore unchanged in source. This narrows compatibility risk but does not prove the compiled Windows binary, bundled dependencies, release packaging, process behavior, or control-plane journey.

The exact next compatibility movement is already supported by the repository's existing route: refresh the generated release snapshot from the authoritative API, acquire the real Windows amd64 asset through TunnelTend's updater, verify the published digest, exercise all six capability probes, and retain the transactional replacement or rollback result. A connected remote session is useful additional evidence but is not silently required for a command-surface compatibility claim.

## Acceptance boundary

Actual Windows acquisition and the required capability surface were exercised for the exact downloaded v0.0.17 binary. Live connected control-plane behavior on that binary remains unobserved. For v0.0.18, the stable release, published asset digests, and unchanged `runtimes` command source are observed; generated snapshot refresh, Windows acquisition, independent hashing, executable probes, updater replacement, and connected behavior remain unobserved. Source inspection and release metadata support adapter judgment but do not prove Windows process, control-plane, or runtime behavior.
