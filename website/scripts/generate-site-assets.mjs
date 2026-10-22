// SPDX-License-Identifier: AGPL-3.0-only
/**
 * Derive the site's identity assets from the approved brand bundle: favicon projections,
 * robots.txt, the legal-route headers, the generated social cards (the Fold on a graphite
 * field) and a verbatim mirror of the TunnelTend brand bundle at /brand/tunneltend/. The
 * bundle under ../brand/bundle/tunneltend/ is the only artwork source; nothing is redrawn.
 */
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import site from '../site.config.mjs';
import publicPages from '../src/data/public-pages.mjs';
import { assetPath, assetUrl, siteBasePath } from './identity-model.mjs';
import { resolvedPages } from './site-pages.mjs';
import { socialCardPath, wrapCardTitle } from './social-preview-model.mjs';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const publicRoot = resolve(projectRoot, 'public');
const bundleRoot = resolve(projectRoot, '../brand/bundle/tunneltend');
const pages = resolvedPages(site, publicPages, projectRoot);
const cards = [...pages.values()].filter((page) => page.generateCard);
const cardPaths = new Set();
for (const page of cards) {
  const output = socialCardPath(page.path);
  if (cardPaths.has(output)) throw new Error(`Generated social card path collides: ${output}`);
  cardPaths.add(output);
}

for (const generated of ['social/generated', 'brand', 'install.ps1', 'favicon.svg', 'favicon.ico', 'favicon-192.png', 'apple-touch-icon.png', 'robots.txt', '_headers']) {
  rmSync(resolve(publicRoot, generated), { recursive: true, force: true });
}
mkdirSync(publicRoot, { recursive: true });
mirrorBrandBundle();
copyInstallScript();
await generateIdentityIcons();
generateRobots();
generateHeaders();
for (const page of cards) await generateCard(page);
console.log(`[assets] generated ${cards.length} social card${cards.length === 1 ? '' : 's'}, identity icons and the brand mirror`);

/** /install.ps1 is the repository's online installer, served as plain text; its source stays in scripts/. */
function copyInstallScript() {
  const source = resolve(projectRoot, '../scripts/Install-TunnelTend-Online.ps1');
  if (!existsSync(source)) throw new Error(`Online installer not found: ${source}`);
  writeFileSync(resolve(publicRoot, 'install.ps1'), readFileSync(source));
}

/** The site serves the bundle tree verbatim at /brand/tunneltend/<path>, per the brand bundle contract. */
function mirrorBrandBundle() {
  if (!existsSync(resolve(bundleRoot, 'assets'))) throw new Error(`Brand bundle not found: ${bundleRoot}`);
  cpSync(bundleRoot, resolve(publicRoot, 'brand/tunneltend'), { recursive: true });
}

async function generateIdentityIcons() {
  const favicon = resolve(bundleRoot, 'assets/icon-favicon/universal-adaptive.svg');
  const faviconDark = resolve(bundleRoot, 'assets/icon-favicon/on-dark.svg');
  const ico = resolve(bundleRoot, 'assets/icon-favicon/universal-48x48.ico');
  const application = resolve(bundleRoot, 'assets/icon-application/universal.svg');
  for (const file of [favicon, faviconDark, ico, application]) {
    if (!existsSync(file)) throw new Error(`Identity source does not exist: ${file}`);
  }
  // The adaptive favicon follows the browser's colour scheme; the ICO is the graphite-ground fallback.
  writeFileSync(resolvePublicPath(site.identity.icons.svg), readFileSync(favicon));
  writeFileSync(resolvePublicPath('/favicon.ico'), readFileSync(ico));
  // Opaque projections use the approved application tile (the Fold at 62% on graphite).
  await writeRaster(site.identity.icons.raster, sharp(application).resize(192, 192).png());
  await writeRaster(site.identity.icons.touch, sharp(application).resize(180, 180).png());
}

function generateRobots() {
  if (siteBasePath(site) !== '/') {
    if (site.identity.robots !== 'origin-owned') throw new Error('A subpath site needs identity.robots: origin-owned.');
    return;
  }
  writeFileSync(resolve(publicRoot, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${assetUrl(site, '/sitemap-index.xml')}\n`, 'utf8');
}

function generateHeaders() {
  const lines = [];
  for (const page of pages.values()) {
    if (page.indexing !== 'noindex') continue;
    lines.push(page.role === 'error' ? assetPath(site, '/404.html') : `${assetPath(site, page.path)}*`);
    lines.push(`  X-Robots-Tag: ${page.role === 'legal' ? 'noindex, nosnippet' : 'noindex'}`);
  }
  // The served install script is plain text for a PowerShell reader, never an HTML page.
  lines.push(assetPath(site, '/install.ps1'), '  Content-Type: text/plain; charset=utf-8', '  X-Robots-Tag: noindex');
  writeFileSync(resolve(publicRoot, '_headers'), `${lines.join('\n')}\n`, 'utf8');
}

/** A quiet graphite field, a large Fold, the title and one sentence. No fictional interface. */
async function generateCard(page) {
  const colors = site.identity.social.colors;
  const foldSource = readFileSync(resolve(bundleRoot, 'assets/mark-primary/on-dark.svg'), 'utf8');
  const foldPaths = [...foldSource.matchAll(/<path[^>]*\/>/gu)].map((match) => match[0]).join('');
  const isHome = page.path === '/';
  const title = isHome ? 'Register once.\nLeave the routine to TunnelTend.' : page.pageTitle;
  const lines = isHome ? title.split('\n') : wrapCardTitle(title, { maxLines: 3, targetCharacters: 24 });
  const titleSize = isHome ? 54 : lines.length === 1 ? 72 : lines.length === 2 ? 60 : 52;
  const titleStart = isHome ? 262 : lines.length === 1 ? 300 : lines.length === 2 ? 268 : 236;
  const titleMarkup = lines.map((line, index) => `<tspan x="88" y="${titleStart + index * (titleSize + 12)}">${escapeXml(line)}</tspan>`).join('');
  const subtitle = isHome
    ? 'Keep the tools on your Windows PC connected to ChatGPT.'
    : page.surfaceName;
  const eyebrow = isHome ? 'TunnelTend' : (page.socialEyebrow ? `${page.surfaceName} · ${page.socialEyebrow}` : page.surfaceName);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="${colors.background}"/>
  <rect x="0" y="0" width="1200" height="630" fill="url(#g)"/>
  <defs><radialGradient id="g" cx="0.86" cy="0.5" r="0.6"><stop offset="0" stop-color="${colors.accent}" stop-opacity="0.10"/><stop offset="1" stop-color="${colors.accent}" stop-opacity="0"/></radialGradient></defs>
  <g transform="translate(804 150) scale(14)" fill="none" stroke="${colors.accent}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${foldPaths}</g>
  <text x="88" y="140" fill="${colors.muted}" font-size="28" font-weight="600" letter-spacing="1" font-family="Segoe UI, system-ui, sans-serif">${escapeXml(eyebrow)}</text>
  <text fill="${colors.foreground}" font-size="${titleSize}" font-weight="700" letter-spacing="-1.5" font-family="Segoe UI, system-ui, sans-serif">${titleMarkup}</text>
  <text x="88" y="${isHome ? 430 : titleStart + lines.length * (titleSize + 12) + 24}" fill="${colors.muted}" font-size="28" font-family="Segoe UI, system-ui, sans-serif">${escapeXml(subtitle)}</text>
  <text x="88" y="556" fill="${colors.muted}" font-size="26" font-weight="600" font-family="Segoe UI, system-ui, sans-serif">${escapeXml(site.identity.social.markText)}</text>
</svg>\n`;
  await writeRaster(socialCardPath(page.path), sharp(Buffer.from(svg)).png());
}

async function writeRaster(publicPath, pipeline) {
  const destination = resolvePublicPath(publicPath);
  mkdirSync(dirname(destination), { recursive: true });
  await pipeline.toFile(destination);
}

function resolvePublicPath(publicPath) {
  if (typeof publicPath !== 'string' || !publicPath.startsWith('/')) throw new Error(`Public asset path must start with /: ${String(publicPath)}`);
  const destination = resolve(publicRoot, publicPath.slice(1));
  const relation = relative(publicRoot, destination);
  if (relation.startsWith('..') || isAbsolute(relation)) throw new Error(`Public asset path escapes public/: ${publicPath}`);
  mkdirSync(dirname(destination), { recursive: true });
  return destination;
}

function escapeXml(value) {
  return String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
}
