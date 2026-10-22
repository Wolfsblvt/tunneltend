// SPDX-License-Identifier: AGPL-3.0-only
/**
 * Export the TunnelTend identity bundle: brand/source/tunneltend/ → brand/bundle/tunneltend/
 * in the canonical Brand Bundle Contract layout, with tokens, CSS, licences and manifest.json.
 *
 * SVG masters are copied byte for byte (the tintable master is exported under both background
 * classes); PNG renditions are rendered with sharp; the ICO is composed from PNG frames. Nothing
 * is redrawn. Run from website/: `npm run brand:export`, then `npm run brand:check`.
 *
 * `source.commit` is the pre-export input commit that contains the masters and this exporter.
 * Export from a committed input (or pass --commit <sha> deliberately) and commit the bundle in a
 * later carrier commit; the manifest never names its own carrier.
 */
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { bundleSha256, canonicalAssetPath, validateBrandBundle } from '../../tools/brand-bundle/scripts/validate-brand-bundle.mjs';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const sourceDir = resolve(repo, 'brand/source/tunneltend');
const bundleDir = resolve(repo, 'brand/bundle/tunneltend');
const palette = JSON.parse(readFileSync(resolve(sourceDir, 'palette.json'), 'utf8'));
const ink = { dark: palette.colors.textDark, light: palette.colors.textLight };
const commitOption = process.argv.indexOf('--commit');
const commit = commitOption > 0 ? process.argv[commitOption + 1] : git('rev-parse', 'HEAD');
if (!/^[0-9a-f]{40}$/u.test(commit)) throw new Error(`source.commit must be a full lowercase SHA: ${commit}`);
const dirty = git('status', '--porcelain', '--', 'brand/source/tunneltend', 'website/scripts/export-brand.mjs', 'tools/brand-bundle');
if (dirty && commitOption < 0) console.warn(`[brand] warning: exporter inputs are uncommitted; ${commit} does not reproduce this export until they are committed:\n${dirty}`);

rmSync(bundleDir, { recursive: true, force: true });
mkdirSync(bundleDir, { recursive: true });

const files = []; // every delivered file record, in manifest order
const record = (path, bytes) => {
  const destination = resolve(bundleDir, path);
  mkdirSync(dirname(destination), { recursive: true });
  writeFileSync(destination, bytes);
  const file = { path, byteCount: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
  files.push(file);
  return file;
};
const master = (name) => readFileSync(resolve(sourceDir, name));
const tinted = (svg, colour) => Buffer.from(svg.toString('utf8').replaceAll('currentColor', colour));
const png = async (svg, width, height) => sharp(svg, { density: 384 }).resize(width, height, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer();
const raster = async (role, variant, svg, width, height, pixelDensity, format = 'png', bytes) => {
  const representation = { format, motion: 'static', width, height, pixelDensity };
  const path = canonicalAssetPath(role, variant, representation);
  return { ...representation, file: record(path, bytes ?? await png(svg, width, height)) };
};
const vector = (role, variant, svg, adaptive = false) => {
  const representation = { format: 'svg', motion: 'static', ...(adaptive ? { adaptive: true } : {}) };
  return { ...representation, file: record(canonicalAssetPath(role, variant, representation), svg) };
};
const classes = { 'on-dark': ['dark'], 'on-light': ['light'], universal: ['light', 'dark'] };
const variant = (appearance, colorMode, evidence, minimumWidthPx, representations, tint) => ({
  appearance, colorMode,
  ...(tint ? { allowedTintTokens: tint } : {}),
  qualifiedBackgrounds: classes[appearance],
  qualificationEvidence: { sourcePath: evidence },
  minimumWidthPx,
  representations,
});
const tintTokens = ['--brand-text-primary', '--brand-action-primary'];

/** A tintable master exported under both background classes, with a PNG fallback in each class's text ink. */
async function tintableVariants(role, name, evidence, minimumWidthPx, width, height, density) {
  const svg = master(name);
  const out = [];
  for (const [appearance, colour] of [['on-dark', ink.dark], ['on-light', ink.light]]) {
    const v = { appearance, colorMode: 'tintable' };
    out.push(variant(appearance, 'tintable', evidence, minimumWidthPx, [vector(role, v, svg), await raster(role, v, tinted(svg, colour), width, height, density)], tintTokens));
  }
  return out;
}

async function fullColorVariants(role, masters, evidence, minimumWidthPx, width, height, density) {
  const out = [];
  for (const [appearance, name] of masters) {
    const svg = master(name);
    const v = { appearance, colorMode: 'full-color' };
    out.push(variant(appearance, 'full-color', evidence, minimumWidthPx, [vector(role, v, svg), await raster(role, v, svg, width, height, density)]));
  }
  return out;
}

/** An ICO container of PNG frames (Windows Vista+ and every current browser read PNG-compressed frames). */
async function ico(svg, sizes) {
  const frames = await Promise.all(sizes.map((size) => png(svg, size, size)));
  const header = Buffer.alloc(6 + 16 * frames.length);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(frames.length, 4);
  let offset = header.length;
  frames.forEach((frame, index) => {
    const entry = 6 + index * 16, size = sizes[index];
    header.writeUInt8(size >= 256 ? 0 : size, entry); header.writeUInt8(size >= 256 ? 0 : size, entry + 1);
    header.writeUInt8(0, entry + 2); header.writeUInt8(0, entry + 3);
    header.writeUInt16LE(1, entry + 4); header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(frame.length, entry + 8); header.writeUInt32LE(offset, entry + 12);
    offset += frame.length;
  });
  return Buffer.concat([header, ...frames]);
}

const assets = [];
const evidence = { mark: 'docs/branding.md#the-fold', favicon: 'docs/branding.md#the-fold', application: 'docs/branding.md#the-fold', wordmark: 'docs/branding.md#wordmark-and-lockup', lockup: 'docs/branding.md#wordmark-and-lockup' };

// mark.primary: the Fold on each background, plus the tintable projection.
assets.push({ role: 'mark.primary', label: 'The Fold', variants: [
  ...await fullColorVariants('mark.primary', [['on-dark', 'tunneltend-fold-dark.svg'], ['on-light', 'tunneltend-fold-light.svg']], evidence.mark, 24, 512, 512, 4),
  ...await tintableVariants('mark.primary', 'tunneltend-fold.svg', evidence.mark, 24, 512, 512, 4),
] });

// icon.favicon: the optically heavier small variant on each background; a graphite-ground universal
// projection carries the ICO and the adaptive SVG.
{
  const role = 'icon.favicon';
  const variants = await fullColorVariants(role, [['on-dark', 'favicon-dark.svg'], ['on-light', 'favicon-light.svg']], evidence.favicon, 16, 32, 32, 2);
  const universal = { appearance: 'universal', colorMode: 'full-color' };
  const universalSvg = master('favicon-universal.svg');
  variants.push(variant('universal', 'full-color', evidence.favicon, 16, [
    vector(role, universal, universalSvg),
    await raster(role, universal, universalSvg, 48, 48, 1),
    await raster(role, universal, universalSvg, 48, 48, 1, 'ico', await ico(universalSvg, [16, 32, 48])),
    vector(role, universal, master('favicon.svg'), true),
  ]));
  assets.push({ role, label: 'Favicon', variants });
}

// icon.application: the approved graphite tile.
{
  const role = 'icon.application', v = { appearance: 'universal', colorMode: 'full-color' }, svg = master('application-icon.svg');
  assets.push({ role, label: 'Application icon', variants: [variant('universal', 'full-color', evidence.application, 48, [
    vector(role, v, svg), await raster(role, v, svg, 64, 64, 1), await raster(role, v, svg, 128, 128, 2), await raster(role, v, svg, 192, 192, 1), await raster(role, v, svg, 512, 512, 1),
  ])] });
}

// wordmark and lockup.default: outlined Manrope lettering, and the Fold beside it.
const wordmarkBox = /viewBox="0 0 ([\d.]+) ([\d.]+)"/u.exec(master('tunneltend-wordmark.svg').toString('utf8'));
const lockupBox = /viewBox="0 0 ([\d.]+) ([\d.]+)"/u.exec(master('tunneltend-lockup.svg').toString('utf8'));
const scaled = (box, width) => [width, Math.round((Number(box[2]) / Number(box[1])) * width)];
const [wmW, wmH] = scaled(wordmarkBox, 1600), [luW, luH] = scaled(lockupBox, 1600);
assets.push({ role: 'wordmark', label: 'TunnelTend wordmark', variants: [
  ...await fullColorVariants('wordmark', [['on-dark', 'tunneltend-wordmark-dark.svg'], ['on-light', 'tunneltend-wordmark-light.svg']], evidence.wordmark, 120, wmW, wmH, 4),
  ...await tintableVariants('wordmark', 'tunneltend-wordmark.svg', evidence.wordmark, 120, wmW, wmH, 4),
] });
assets.push({ role: 'lockup.default', label: 'TunnelTend lockup', titleCompatible: true, variants: [
  ...await fullColorVariants('lockup.default', [['on-dark', 'tunneltend-lockup-dark.svg'], ['on-light', 'tunneltend-lockup-light.svg']], evidence.lockup, 160, luW, luH, 4),
  ...await tintableVariants('lockup.default', 'tunneltend-lockup.svg', evidence.lockup, 160, luW, luH, 4),
] });

// tokens: the reference palette and the semantic roles, plus scoped CSS.
const c = palette.colors;
const reference = { name: palette.name, colors: c, testedPairs: palette.testedPairs };
const semantic = {
  dark: { 'surface-canvas': c.darkCanvas, 'surface-raised': c.darkSurface, 'text-primary': c.textDark, 'text-muted': c.mutedDark, 'action-primary': c.accentDark, 'action-primary-hover': '#93D7E3', link: c.accentDark, 'focus-ring': c.accentDark, 'border-default': '#45404F', 'status-healthy': c.healthyDark, 'status-degraded': c.degradedDark, 'status-failed': c.failedDark, 'status-neutral': c.neutralDark },
  light: { 'surface-canvas': c.lightCanvas, 'surface-raised': c.lightSurface, 'text-primary': c.textLight, 'text-muted': c.mutedLight, 'action-primary': c.accentLight, 'action-primary-hover': c.accentLightOnSurface, link: c.accentLightOnSurface, 'focus-ring': c.accentLight, 'border-default': '#C9C2D0', 'status-healthy': c.healthyLight, 'status-degraded': c.degradedLight, 'status-failed': c.failedLight, 'status-neutral': c.neutralLight },
  fonts: { interface: '"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif', reading: '"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif', mono: '"Cascadia Code", "Cascadia Mono", Consolas, ui-monospace, monospace' },
};
const declarations = (theme) => Object.entries(semantic[theme]).map(([k, v]) => `  --brand-${k}: ${v};`).join('\n');
const css = `/* TunnelTend identity tokens (Moonpool After Dark). Scoped to the bundle host; dark is the reference theme. */
@layer brand.tokens;
@layer brand.tokens {
[data-brand-foundation="tunneltend"] {
  --brand-font-interface: ${semantic.fonts.interface};
  --brand-font-reading: ${semantic.fonts.reading};
  --brand-font-mono: ${semantic.fonts.mono};
${declarations('dark')}
}
[data-brand-foundation="tunneltend"][data-theme="light"] {
${declarations('light')}
}
}
`;
const tokens = {
  reference: record('tokens/reference.json', Buffer.from(`${JSON.stringify(reference, null, 2)}\n`)),
  semantic: record('tokens/semantic.json', Buffer.from(`${JSON.stringify(semantic, null, 2)}\n`)),
  css: record('css/tokens.css', Buffer.from(css)),
};
const licences = [{
  id: 'manrope-ofl', subject: 'Manrope 4.504, the typeface the wordmark lettering was outlined from (no font file is distributed)',
  name: 'SIL Open Font License 1.1', source: '@fontsource/manrope@5.2.6',
  file: record('licences/manrope-ofl.txt', master('manrope-ofl.txt')),
}];

const manifest = {
  schemaVersion: 1,
  bundleSha256: '',
  brand: { id: 'tunneltend', displayName: 'TunnelTend', description: 'The Fold and the Moonpool After Dark palette: the approved TunnelTend identity.' },
  source: { repository: 'Wolfsblvt/tunneltend', commit, exporter: 'website/scripts/export-brand.mjs' },
  tokens,
  assets,
  licences,
};
manifest.bundleSha256 = bundleSha256(manifest);
writeFileSync(resolve(bundleDir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

const result = await validateBrandBundle(bundleDir);
if (result?.findings?.length) throw new Error(`Exported bundle is invalid:\n${result.findings.join('\n')}`);
console.log(`[brand] exported ${files.length} files to brand/bundle/tunneltend (source ${commit.slice(0, 12)}, bundleSha256 ${manifest.bundleSha256})`);

function git(...args) {
  return execFileSync('git', args, { cwd: repo, encoding: 'utf8' }).trim();
}
