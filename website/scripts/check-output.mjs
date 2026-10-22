import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import site from '../site.config.mjs';
import publicPages from '../src/data/public-pages.mjs';
import { assetUrl, siteBasePath } from './identity-model.mjs';
import { resolvedPages } from './site-pages.mjs';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputRoot = resolve(projectRoot, 'artifacts/site');
const pages = resolvedPages(site, publicPages, projectRoot);
const indexable = new Set([...pages.values()]
  .filter((page) => page.indexing === 'index' && page.canonical)
  .map((page) => page.canonical));
const sitemap = readFileSync(resolve(outputRoot, 'sitemap-0.xml'), 'utf8');
const emitted = new Set([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/gu)].map((match) => match[1]));
if (emitted.size !== indexable.size || [...indexable].some((url) => !emitted.has(url))) {
  throw new Error('Built sitemap does not match the resolved indexable page identities.');
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
console.log('Built pages, sitemap, robots policy and structured Home identity match resolved source.');
