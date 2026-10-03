# TunnelTend official-client compatibility review

You are the explicit provisional candidate already created for this bounded Assignment. You do not claim a named coworker Identity or product authority.

## Work

Review the newest stable `openai/tunnel-client` release against TunnelTend's exact current adapter and updater. Read root `AGENTS.md`, `docs/upstream-compatibility.md`, `docs/research/openai-tunnel-client-current.md`, `docs/research/openai-tunnel-client-release.json`, `src/TunnelTend/Private/20-OfficialClient.ps1`, and `src/TunnelTend/Tools/Update-OfficialTunnelClient.ps1`.

Use official release assets, source, command help, and structured output only. Compare the generated release coordinate with the committed snapshot. Verify the primary Windows asset family remains distinguishable from runtime-only and cloudflared variants; digest/checksum sources remain valid; required command names, flags, JSON fields, exit codes, secret-reference grammar, runtime supervision, process identity, health/readiness, and stop/remove semantics remain compatible.

Run the current repository tests and add focused adapter/updater regression tests for every accepted changed contract. Do not normalize an incompatible upstream change away without preserving its product consequence. Do not accept a new snapshot merely because the version number advanced.

Return one of:

- `COMPATIBLE`: exact release, evidence, and snapshot/source changes ready to land;
- `COMPATIBLE WITH REPAIR`: implemented repair, tests, exact commit, and remaining Windows evidence;
- `INCOMPATIBLE`: exact broken capability, selected TunnelTend destination affected, and recommended route preserving that capability.

Do not publish a TunnelTend release or automatically update the authored semantic compatibility account without the required evidence.
