# TunnelTend identity source

## Meaning

This directory holds the authored masters of TunnelTend's approved identity (The Fold, the wordmark and lockup, and the Moonpool After Dark palette) and names the exporter that turns them into the bundle. `../../bundle/tunneltend/` is generated from it as a Works-standard brand bundle and is never edited by hand. [Branding](../../../docs/branding.md) owns what the identity means and how to use it.

## Provenance

The Fold SVGs, the favicon masters and the palette tokens are the exact bytes approved by Wolf on 2026-10-17 and deposited at `Wolfsblvt/emergency-meeting@e185f340f673614f79902f5214f955fa08bd0aa1`, under `workbench/nyxara/tunneltend-identity-2026-10-17/`. Path data is not redrawn or normalized.

| Here | Origin | SHA-256 |
| --- | --- | --- |
| `tunneltend-fold.svg` | deposit `assets/tunneltend-fold.svg` (byte-identical to its `-mono` twin, kept once; exported as the tintable `on-dark` and `on-light` projections) | `f0b34ebf99cc899c559e8e4992985caca8e01f3f455d45c1e45759ef8262b77c` |
| `tunneltend-fold-dark.svg` | same name | `1184c5b945eea088a2d21ed9754812160cd73ea2035d6f911995923cab72771e` |
| `tunneltend-fold-light.svg` | same name | `76bb5a404918211f94df50131e59ea9d82c6ab6c96e4f6195ec8fd55f3e0ff37` |
| `favicon.svg` | same name; exported as the adaptive projection of the universal favicon | `86a75a31cb78d2208bcd7c2352d862bf9959cd702f416cd13fe29519b5bf0f35` |
| `favicon-dark.svg` | same name | `cf002a605b944e0e29c20cb48a527b39866664e2b10759e9e464fea24f9f73bc` |
| `favicon-light.svg` | same name | `05ec92f2bae401237af35f3e4d137a94cde19a9cbc98b565054287c9a4578a5a` |
| `favicon-universal.svg` | Authored here: the approved dark favicon geometry, unchanged, on an opaque graphite square (the deposit's ICO ground recipe as SVG). It carries the ICO frames and the universal PNG. | derived, 2026-10-22 |
| `application-icon.svg` | Authored here: the approved dark mark's path data, unchanged, scaled to 62% and centred on a graphite square (the deposit's avatar recipe) | `39575c1d504f25336127b42e75b0573a3c5a2afe11fa86fc32b07cc48567d423` |
| `palette.css`, `palette.json` | same names; their `status` comments still say "pending product adoption" verbatim, which no longer describes standing | `cf0ce56c…`, `eaca8414…` |

### Wordmark and lockup, 2026-10-22

Wolf chose the wordmark on 2026-10-22 from three in-site candidates: "TunnelTend" set in **Manrope 700** (Manrope 4.504, SIL Open Font License 1.1, obtained as `@fontsource/manrope@5.2.6`), tracking −0.025 em, outlined to paths with fontkit at 100 units per em and rounded to two decimals. No font file is distributed; `manrope-ofl.txt` travels with the bundle as provenance.

| Master | Content |
| --- | --- |
| `tunneltend-wordmark.svg` | The outlined lettering with a 2-unit margin, `currentColor` (the tintable master) |
| `tunneltend-wordmark-dark.svg`, `-light.svg` | The same paths in the class text ink, `#F0EDF3` and `#25222D` |
| `tunneltend-lockup.svg` | The Fold at the header ratio (a 26 px mark beside a 17 px wordmark, 9 px gap), vertically centred on the lettering, `currentColor` |
| `tunneltend-lockup-dark.svg`, `-light.svg` | The same with the approved mark stroke (`#79CAD9` / `#167B91`) and text ink |

The lockup is the approved title treatment (`titleCompatible`). Do not re-set the lettering in another face or weight, retrace it, or change the mark-to-wordmark ratio; a change is a new identity decision.

## Export

`website/scripts/export-brand.mjs` is the exporter named in the bundle manifest. From `website/`:

```powershell
npm run brand:export
npm run brand:check
```

It copies every SVG master byte for byte into the canonical role paths, renders the PNG renditions with sharp, composes the ICO from PNG frames, writes `tokens/reference.json`, `tokens/semantic.json` and `css/tokens.css` from `palette.json`, records `source.commit` as the current `HEAD`, seals `bundleSha256`, and validates the result with the vendored Brand Bundle Contract validator in `tools/brand-bundle/`. Export from a committed input (masters, exporter and validator), then commit the bundle in a later carrier commit; the manifest must never name its own carrier. Fix a wrong asset in its master or the exporter, then export again.
