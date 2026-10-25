// SPDX-License-Identifier: AGPL-3.0-only
/** Public destinations for the single build's product and manual routes. */
export const PRODUCT_ORIGIN = 'https://tunneltend.com';
export const DOCS_ORIGIN = 'https://docs.tunneltend.com';

export function isDocsPath(path) {
  return path === '/docs' || path.startsWith('/docs/');
}

/** Includes query/fragment preservation for links, search hits and the old URL bridge. */
export function publicDestination(path) {
  const url = new URL(path, PRODUCT_ORIGIN);
  if (url.origin !== PRODUCT_ORIGIN) return url.href;
  if (isDocsPath(url.pathname)) {
    url.hostname = new URL(DOCS_ORIGIN).hostname;
    url.pathname = url.pathname.slice('/docs'.length) || '/';
    // The manual emits directory pages. Send slashless legacy links straight to their
    // final location instead of requiring a second Static Assets canonicalization hop.
    if (!url.pathname.endsWith('/') && !url.pathname.split('/').at(-1).includes('.')) url.pathname += '/';
  }
  return url.href;
}
