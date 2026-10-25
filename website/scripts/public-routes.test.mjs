// SPDX-License-Identifier: AGPL-3.0-only
import assert from 'node:assert/strict';
import { test } from 'node:test';
import worker from '../src/worker.mjs';
import { publicDestination } from '../src/lib/public-routes.mjs';

test('old docs links, search anchors and agent handoffs select the canonical host', () => {
  for (const [path, expected] of [
    ['/docs', 'https://docs.tunneltend.com/'],
    ['/docs/', 'https://docs.tunneltend.com/'],
    ['/docs/cli?x=1', 'https://docs.tunneltend.com/cli/?x=1'],
    ['/docs/getting-started/?mode=a%2Fb#verify', 'https://docs.tunneltend.com/getting-started/?mode=a%2Fb#verify'],
    ['/docs/install-with-an-agent/', 'https://docs.tunneltend.com/install-with-an-agent/'],
    ['/faq/#agent-setup', 'https://tunneltend.com/faq/#agent-setup'],
    ['https://example.org/docs/', 'https://example.org/docs/'],
  ]) assert.equal(publicDestination(path), expected);
});

test('apex and www old URLs bridge directly with query preserved and no assets fetch', async () => {
  for (const host of ['tunneltend.com', 'www.tunneltend.com', 'docs.tunneltend.com']) {
    const response = await worker.fetch(new Request(`https://${host}/docs/cli/?q=a%2Fb&x=1`), {});
    assert.equal(response.status, 308);
    assert.equal(response.headers.get('location'), 'https://docs.tunneltend.com/cli/?q=a%2Fb&x=1');
  }
});

test('host routing serves the right files, keeps assets shared and prevents duplicate product HTML', async () => {
  for (const [input, output] of [
    ['https://tunneltend.com/', '/'],
    ['https://tunneltend.com/faq/', '/faq/'],
    ['https://tunneltend.com/install.ps1', '/install.ps1'],
    ['https://docs.tunneltend.com/', '/docs/'],
    ['https://docs.tunneltend.com/cli/?x=1', '/docs/cli/?x=1'],
    ['https://docs.tunneltend.com/_astro/site.css', '/_astro/site.css'],
    ['https://docs.tunneltend.com/pagefind/pagefind.js', '/pagefind/pagefind.js'],
    ['https://docs.tunneltend.com/sitemap-0.xml', '/docs-sitemap-0.xml'],
    ['https://docs.tunneltend.com/not-a-guide/', '/docs/not-a-guide/'],
  ]) {
    const env = { ASSETS: { fetch: async request => {
      const url = new URL(request.url);
      assert.equal(url.pathname + url.search, output);
      return new Response('asset');
    } } };
    assert.equal(await (await worker.fetch(new Request(input), env)).text(), 'asset');
  }
  const faq = await worker.fetch(new Request('https://docs.tunneltend.com/faq/'), {});
  assert.equal(faq.headers.get('location'), 'https://tunneltend.com/faq/');
});

test('docs robots and asset canonicalization expose only public coordinates', async () => {
  const robots = await worker.fetch(new Request('https://docs.tunneltend.com/robots.txt'), {});
  assert.match(await robots.text(), /Sitemap: https:\/\/docs\.tunneltend\.com\/sitemap-index\.xml/u);
  const env = { ASSETS: { fetch: async () => Response.redirect('https://docs.tunneltend.com/docs/cli/', 307) } };
  const canonical = await worker.fetch(new Request('https://docs.tunneltend.com/cli'), env);
  assert.equal(canonical.headers.get('location'), 'https://docs.tunneltend.com/cli/');
  assert.equal(canonical.status, 307);
});
