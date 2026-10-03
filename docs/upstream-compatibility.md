# Official tunnel-client compatibility

## Meaning

This document defines how TunnelTend tracks and verifies the changing official `openai/tunnel-client` surface. It localizes upstream assumptions, distinguishes a new release from an incompatibility, and names the source, CI, and Windows evidence required before accepting changed behavior.

TunnelTend depends on the official client's stable release assets and these command families:

- `--version`
- `runtimes list --json`
- `runtimes status <alias> --json`
- `runtimes connect ... --json`
- `runtimes stop <alias> --json`

The adapter normalizes upstream fields before the rest of the application sees them. Unknown or missing structured targets are refused during import.

`client status` performs live help-based capability checks. A new binary is not accepted after update until those checks pass. The Windows release checklist verifies concrete JSON fields and exit codes against the selected release.

`docs/research/openai-tunnel-client-release.json` is the generated, machine-readable stable-release snapshot. The scheduled watch refreshes only that factual coordinate and fails when it changes. `docs/research/openai-tunnel-client-current.md` remains the authored semantic compatibility account and changes only after the new release is actually reviewed. Neither file is a forever contract.
