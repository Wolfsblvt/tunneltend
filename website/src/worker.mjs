// SPDX-License-Identifier: AGPL-3.0-only
import { DOCS_ORIGIN, PRODUCT_ORIGIN, isDocsPath, publicDestination } from './lib/public-routes.mjs';

/** One artifact, two public hosts; internal /docs/ files are never a second public copy. */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const docs = url.hostname === new URL(DOCS_ORIGIN).hostname;
    if (!docs && isDocsPath(url.pathname)) {
      return Response.redirect(publicDestination(url.pathname + url.search), 308);
    }
    if (url.hostname === 'www.tunneltend.com') {
      return Response.redirect(PRODUCT_ORIGIN + url.pathname + url.search, 308);
    }
    if (docs) {
      // Old links arriving on either host take the same direct canonical bridge.
      if (isDocsPath(url.pathname)) return Response.redirect(publicDestination(url.pathname + url.search), 308);
      if (['/faq', '/faq/', '/privacy', '/privacy/', '/impressum', '/impressum/', '/install.ps1'].includes(url.pathname)) {
        return Response.redirect(PRODUCT_ORIGIN + url.pathname + url.search, 308);
      }
      if (url.pathname === '/robots.txt') {
        return new Response(`User-agent: *\nAllow: /\nSitemap: ${DOCS_ORIGIN}/sitemap-index.xml\n`, {
          headers: { 'content-type': 'text/plain; charset=utf-8' },
        });
      }
      if (url.pathname === '/sitemap-index.xml' || url.pathname === '/sitemap-0.xml') {
        url.pathname = '/docs-' + url.pathname.slice(1);
      } else if (!/^\/(?:_astro|pagefind|social|brand)\//u.test(url.pathname)
        && !/^\/(?:favicon(?:\.svg|\.ico|-192\.png)|apple-touch-icon\.png)$/u.test(url.pathname)) {
        url.pathname = '/docs' + url.pathname;
      }
    } else if (url.pathname.startsWith('/docs-sitemap-')) {
      return new Response('Not found', { status: 404 });
    }
    const response = await env.ASSETS.fetch(new Request(url, request));
    // Static Assets can canonicalize internal paths; do not expose that storage coordinate.
    if (docs && response.headers.has('location')) {
      const location = new URL(response.headers.get('location'), url);
      location.hostname = new URL(PRODUCT_ORIGIN).hostname;
      return Response.redirect(publicDestination(location.pathname + location.search), response.status);
    }
    return response;
  },
};
