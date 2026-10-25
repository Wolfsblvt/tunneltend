// SPDX-License-Identifier: AGPL-3.0-only
import { globSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import site from '../site.config.mjs';
import publicPages from '../src/data/public-pages.mjs';
import { resolvedPages } from './site-pages.mjs';
import { DOCS_ORIGIN, PRODUCT_ORIGIN, publicDestination } from '../src/lib/public-routes.mjs';

const root = resolve(import.meta.dirname, '../artifacts/site');
// Starlight needs its build routes to resolve the active sidebar and pagination. Project
// those generated anchors to public destinations once, alongside ordinary page anchors.
for (const file of globSync('**/*.html', { cwd: root })) {
  const path = resolve(root, file);
  const html = readFileSync(path, 'utf8').replace(/\bhref="((?:https:\/\/tunneltend\.com)?\/(?!\/)[^"]*)"/gu,
    (_, href) => `href="${publicDestination(href)}"`);
  writeFileSync(path, html);
}

const pages = [...resolvedPages(site, publicPages, resolve(import.meta.dirname, '..')).values()];
for (const [origin, prefix] of [[PRODUCT_ORIGIN, ''], [DOCS_ORIGIN, 'docs-']]) {
  const urls = pages.filter(page => page.indexing === 'index' && new URL(page.canonical).origin === origin)
    .map(page => `<url><loc>${page.canonical}</loc></url>`).join('');
  writeFileSync(resolve(root, `${prefix}sitemap-0.xml`),
    `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`);
  writeFileSync(resolve(root, `${prefix}sitemap-index.xml`),
    `<?xml version="1.0" encoding="UTF-8"?><sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><sitemap><loc>${origin}/sitemap-0.xml</loc></sitemap></sitemapindex>`);
}
