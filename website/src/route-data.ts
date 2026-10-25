import { defineRouteMiddleware } from '@astrojs/starlight/route-data';
import site from '../site.config.mjs';
import { resolvePageIdentity, routeFromPath } from '../scripts/identity-model.mjs';

export const onRequest = defineRouteMiddleware((context) => {
  const route = context.locals.starlightRoute;
  const data = route.entry.data as { title: string; description: string; identity?: Record<string, unknown> };
  const path = routeFromPath(site, context.url.pathname);
  const page = resolvePageIdentity(site, path, {
    ...data.identity,
    title: data.title,
    description: data.description,
  }, { surfaceName: site.docs.surfaceName });
  route.lang = page.language;
  route.head = route.head.filter((item) => !isOwnedIdentityEntry(item));
  route.head.push(
    { tag: 'title', content: page.title },
    { tag: 'meta', attrs: { name: 'description', content: page.description } },
  );
  if (page.indexing === 'noindex') {
    route.head.push({ tag: 'meta', attrs: { name: 'robots', content: page.role === 'legal' ? 'noindex, nosnippet' : 'noindex' } });
  }
  if (page.canonical) route.head.push({ tag: 'link', attrs: { rel: 'canonical', href: page.canonical } });
  if (page.sharing === 'share') {
    route.head.push(
      { tag: 'meta', attrs: { property: 'og:type', content: 'website' } },
      { tag: 'meta', attrs: { property: 'og:title', content: page.pageTitle } },
      { tag: 'meta', attrs: { property: 'og:description', content: page.description } },
      { tag: 'meta', attrs: { property: 'og:site_name', content: site.docs.surfaceName } },
      { tag: 'meta', attrs: { property: 'og:locale', content: page.locale } },
      { tag: 'meta', attrs: { name: 'twitter:card', content: page.imageUrl ? 'summary_large_image' : 'summary' } },
      { tag: 'meta', attrs: { name: 'twitter:title', content: page.pageTitle } },
      { tag: 'meta', attrs: { name: 'twitter:description', content: page.description } },
    );
    if (page.canonical) route.head.push({ tag: 'meta', attrs: { property: 'og:url', content: page.canonical } });
    if (page.imageUrl) route.head.push(
      { tag: 'meta', attrs: { property: 'og:image', content: page.imageUrl } },
      { tag: 'meta', attrs: { property: 'og:image:alt', content: page.socialAlt } },
      { tag: 'meta', attrs: { name: 'twitter:image', content: page.imageUrl } },
      { tag: 'meta', attrs: { name: 'twitter:image:alt', content: page.socialAlt } },
    );
  }
  if (page.structuredData) route.head.push({
    tag: 'script',
    attrs: { type: 'application/ld+json' },
    content: JSON.stringify(page.structuredData).replaceAll('<', '\\u003c'),
  });
});

function isOwnedIdentityEntry(item: { tag: string; attrs?: Record<string, string | boolean | undefined> }) {
  if (item.tag === 'title') return true;
  if (item.tag === 'link' && item.attrs?.rel === 'canonical') return true;
  if (item.tag === 'script' && item.attrs?.type === 'application/ld+json') return true;
  if (item.tag !== 'meta') return false;
  const key = item.attrs?.name ?? item.attrs?.property;
  return [
    'description', 'robots',
    'og:type', 'og:title', 'og:description', 'og:site_name', 'og:locale', 'og:url', 'og:image', 'og:image:alt',
    'twitter:card', 'twitter:title', 'twitter:description', 'twitter:image', 'twitter:image:alt',
  ].includes(String(key ?? ''));
}
