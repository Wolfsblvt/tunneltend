import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import site from '../site.config.mjs';
import publicPages from '../src/data/public-pages.mjs';
import { assetUrl, siteBasePath } from './identity-model.mjs';
import { resolvedPages } from './site-pages.mjs';
import { manualVerifyScript } from '../src/data/manual-verify.mjs';
import { RELEASE_VERSION } from '../src/data/site.ts';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputRoot = resolve(projectRoot, 'artifacts/site');
const pages = resolvedPages(site, publicPages, projectRoot);
const indexable = new Set([...pages.values()]
  .filter((page) => page.indexing === 'index' && page.canonical)
  .map((page) => page.canonical));
const sitemap = ['sitemap-0.xml', 'docs-sitemap-0.xml']
  .map(file => readFileSync(resolve(outputRoot, file), 'utf8')).join('');
const emitted = new Set([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/gu)].map((match) => match[1]));
if (emitted.size !== indexable.size || [...indexable].some((url) => !emitted.has(url))) {
  throw new Error('Built sitemap does not match the resolved indexable page identities.');
}
for (const [file, origin] of [['sitemap-0.xml', site.url], ['docs-sitemap-0.xml', site.docs.url]]) {
  const xml = readFileSync(resolve(outputRoot, file), 'utf8');
  const urls = [...xml.matchAll(/<loc>([^<]+)<\/loc>/gu)].map(match => match[1]);
  if (urls.length === 0 || urls.some(url => new URL(url).origin !== origin)) {
    throw new Error(`Built ${file} contains a foreign-host URL or no URLs.`);
  }
}
if (siteBasePath(site) === '/') {
  const robots = readFileSync(resolve(outputRoot, 'robots.txt'), 'utf8');
  if (robots !== `User-agent: *\nAllow: /\nSitemap: ${assetUrl(site, '/sitemap-index.xml')}\n`) {
    throw new Error('Built robots.txt does not name the canonical sitemap.');
  }
} else if (existsSync(resolve(outputRoot, 'robots.txt'))) {
  throw new Error('A subpath site cannot publish origin-wide robots.txt.');
}
for (const page of pages.values()) {
  const output = page.role === 'error' ? '404.html' : `${page.path.slice(1)}index.html`;
  const html = readFileSync(resolve(outputRoot, output), 'utf8');
  if (/\bhref="(?:https:\/\/tunneltend\.com)?\/docs(?:\/|["?#])/u.test(html)) {
    throw new Error(`Built page still links to the compatibility bridge: ${page.path}.`);
  }
  const base = siteBasePath(site);
  if (base !== '/' && [...html.matchAll(/\b(?:href|src)="(\/[^"]+)"/gu)]
    .some((match) => match[1].startsWith(`${base}${base.slice(1)}`))) {
    throw new Error(`Built internal URL repeats the site base: ${page.path}.`);
  }
  if (!html.includes(`<html lang="${page.language}"`)) {
    throw new Error(`Built language disagrees with ${page.path}.`);
  }
  if (page.canonical && !html.includes(`href="${page.canonical}"`)) {
    throw new Error(`Built canonical URL disagrees with ${page.path}.`);
  }
  if (page.indexing === 'noindex' && !html.includes('name="robots"')) {
    throw new Error(`Built page lacks noindex metadata: ${page.path}.`);
  }
  if (page.sharing === 'none' && html.includes('property="og:image"')) {
    throw new Error(`Non-shareable page exposes a social image: ${page.path}.`);
  }
  if (page.imageUrl && !html.includes(`content="${page.imageUrl}"`)) {
    throw new Error(`Built social image disagrees with ${page.path}.`);
  }
  if (page.socialImage?.startsWith('/')) {
    const imagePath = resolve(outputRoot, page.socialImage.slice(1));
    if (!existsSync(imagePath)) throw new Error(`Built social image is missing: ${page.socialImage}`);
    const metadata = await sharp(imagePath).metadata();
    if (!metadata.width || !metadata.height) throw new Error(`Built social image does not decode: ${page.socialImage}`);
  }
  if (page.structuredData) {
    const payload = html.match(/<script type="application\/ld\+json">([^<]+)<\/script>/u)?.[1];
    if (!payload || JSON.parse(payload).url !== page.structuredData.url) {
      throw new Error(`Built Home structured identity disagrees with ${page.path}.`);
    }
  }
}
// The homepage and the manual must both show the one executable verification script.
const visibleText = (html) => html.replace(/<[^>]+>/gu, '')
  .replace(/&#x([0-9a-f]+);/giu, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
  .replace(/&#(\d+);/gu, (_, dec) => String.fromCodePoint(Number(dec)))
  .replace(/&(quot|amp|lt|gt);/gu, (_, name) => ({ quot: '"', amp: '&', lt: '<', gt: '>' })[name])
  .replace(/\s+/gu, '');
// Highlighted lines carry no separator between them, so the comparison ignores whitespace.
const expectedScript = manualVerifyScript(RELEASE_VERSION).replace(/\s+/gu, '');
for (const output of ['index.html', 'docs/getting-started/index.html']) {
  if (!visibleText(readFileSync(resolve(outputRoot, output), 'utf8')).includes(expectedScript)) {
    throw new Error(`The manual verification script on ${output} is not the shared executable script.`);
  }
}
console.log('Built pages, sitemap, robots policy and structured Home identity match resolved source.');
