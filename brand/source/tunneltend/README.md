# TunnelTend identity source

## Meaning

This directory holds the authored masters of TunnelTend's approved identity (The Fold and the Moonpool After Dark palette) and the recipe that exports them. `../../bundle/tunneltend/` is generated from it. [Branding](../../../docs/branding.md) owns what the identity means and how to use it.

## Provenance

The SVGs and tokens are the exact bytes approved by Wolf on 2026-10-17 and deposited at `Wolfsblvt/emergency-meeting@e185f340f673614f79902f5214f955fa08bd0aa1`, under `workbench/nyxara/tunneltend-identity-2026-10-17/`. Path data is not redrawn or normalized.

| Here | Origin (`assets/` or `tokens/` there) | SHA-256 |
| --- | --- | --- |
| `tunneltend-fold.svg` | `tunneltend-fold.svg` (byte-identical to its `-mono` twin, kept once) | `f0b34ebf99cc899c559e8e4992985caca8e01f3f455d45c1e45759ef8262b77c` |
| `tunneltend-fold-dark.svg` | same name | `1184c5b945eea088a2d21ed9754812160cd73ea2035d6f911995923cab72771e` |
| `tunneltend-fold-light.svg` | same name | `76bb5a404918211f94df50131e59ea9d82c6ab6c96e4f6195ec8fd55f3e0ff37` |
| `favicon.svg` | same name | `86a75a31cb78d2208bcd7c2352d862bf9959cd702f416cd13fe29519b5bf0f35` |
| `favicon-dark.svg` | same name | `cf002a605b944e0e29c20cb48a527b39866664e2b10759e9e464fea24f9f73bc` |
| `favicon-light.svg` | same name | `05ec92f2bae401237af35f3e4d137a94cde19a9cbc98b565054287c9a4578a5a` |
| `palette.css` | same name | `cf0ce56cb2632d50dfbd61b4d6751306f14e3f44cd20a2e29065f85b656e68a6` |
| `palette.json` | same name | `eaca8414b42bcedf6fb36155439a51eef174152c838f154cc1fb9d44efda40b6` |

The comments and `status` field inside the two palette files say "pending product adoption". They are kept verbatim as source bytes and no longer describe standing; the values are unchanged and now adopted.

`export.py` is a repository-owned export recipe derived from the deposit's optional `render-assets.py`: it keeps that script's graphite ICO and padded-ground choices, writes into the canonical bundle layout, and renders the contact sheet. Its two Python dependencies are deliberately not installed by this repository.
