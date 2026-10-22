import { existsSync, globSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parse } from 'yaml';
import { normalizePublicRoute } from './social-preview-model.mjs';
import { resolvePageIdentity } from './identity-model.mjs';

export function resolvedPages(site, publicPages, projectRoot) {
  const pages = new Map();
  const add = (route, source, options) => {
    const path = normalizePublicRoute(route);
    if (pages.has(path)) throw new Error(`Duplicate identity route: ${path}`);
    const page = resolvePageIdentity(site, path, source, options);
    if (['private', 'preview', 'resource'].includes(page.role)) {
      throw new Error(`${page.role} route cannot be emitted as public static HTML: ${path}`);
    }
    pages.set(path, page);
  };
  for (const page of publicPages) add(page.path, page);

  if (site.docs.mode === 'manual') {
    const docsRoot = resolve(projectRoot, 'src/content/docs');
    if (existsSync(docsRoot)) {
      for (const sourcePath of globSync('**/*.{md,mdx}', { cwd: docsRoot }).sort()) {
        const frontmatter = readFrontmatter(resolve(docsRoot, sourcePath), sourcePath);
        if (frontmatter.draft === true) continue;
        const identity = frontmatter.identity ?? {};
        const route = documentationRoute(sourcePath, frontmatter.slug);
        add(route, {
          ...identity,
          title: frontmatter.title,
          description: frontmatter.description,
        }, { surfaceName: site.docs.surfaceName });
      }
    }
  }
  return pages;
}

export function readFrontmatter(path, label = path) {
  const source = readFileSync(path, 'utf8');
  if (!source.startsWith('---\n')) throw new Error(`Documentation page needs frontmatter: ${label}`);
  const end = source.indexOf('\n---\n', 4);
  if (end < 0) throw new Error(`Documentation page has unterminated frontmatter: ${label}`);
  const data = parse(source.slice(4, end));
  if (!data || typeof data.title !== 'string' || !data.title.trim()) {
    throw new Error(`Documentation page needs a title: ${label}`);
  }
  return data;
}

export function documentationRoute(sourcePath, slug) {
  if (slug) return normalizePublicRoute(`/${slug}`);
  const segments = sourcePath.replace(/\.(?:md|mdx)$/u, '').split(/[\\/]/u);
  if (segments.at(-1) === 'index') segments.pop();
  return normalizePublicRoute(`/${segments.join('/')}`);
}
