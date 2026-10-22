// SPDX-License-Identifier: AGPL-3.0-only
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import starlight from '@astrojs/starlight';
import site from './site.config.mjs';
import publicPages from './src/data/public-pages.mjs';
import { assetPath, routeFromPath } from './scripts/identity-model.mjs';
import { resolvedPages } from './scripts/site-pages.mjs';
import { moonpoolSyntax } from './src/lib/shiki-theme.ts';
import { themeScript } from './src/lib/theme-script.mjs';

// The brand bundle and the online installer live above the website root; Vite may read them.
const repositoryRoot = fileURLToPath(new URL('../', import.meta.url));

const pages = resolvedPages(site, publicPages, import.meta.dirname);

export default defineConfig({
  site: new URL(site.url).origin,
  output: 'static',
  trailingSlash: 'always',
  outDir: './artifacts/site',
  markdown: { shikiConfig: { theme: moonpoolSyntax } },
  vite: { server: { fs: { allow: [repositoryRoot] } } },
  integrations: [
    sitemap({
      filter: (url) => {
        const page = pages.get(routeFromPath(site, new URL(url).pathname));
        return page?.indexing === 'index' && page.canonical === url;
      },
    }),
    starlight({
      title: site.docs.surfaceName,
      description: site.description,
      titleDelimiter: '·',
      favicon: site.identity.icons.svg,
      disable404Route: true,
      routeMiddleware: './src/route-data.ts',
      pagination: true,
      lastUpdated: false,
      credits: false,
      head: [
        { tag: 'script', content: themeScript },
        { tag: 'meta', attrs: { name: 'theme-color', content: site.identity.themeColor } },
        { tag: 'meta', attrs: { name: 'color-scheme', content: 'dark light' } },
        { tag: 'link', attrs: { rel: 'icon', href: assetPath(site, '/favicon.ico'), sizes: '48x48' } },
        { tag: 'link', attrs: { rel: 'icon', href: assetPath(site, site.identity.icons.raster), sizes: '192x192', type: 'image/png' } },
        { tag: 'link', attrs: { rel: 'apple-touch-icon', href: assetPath(site, site.identity.icons.touch), sizes: '180x180' } },
      ],
      customCss: ['./src/styles/tokens.css', './src/styles/global.css', './src/styles/starlight.css'],
      components: {
        Header: './src/components/docs/Header.astro',
        SiteTitle: './src/components/docs/SiteTitle.astro',
        Search: './src/components/docs/Search.astro',
        ThemeProvider: './src/components/docs/ThemeProvider.astro',
        ThemeSelect: './src/components/docs/ThemeSelect.astro',
        Footer: './src/components/docs/Footer.astro',
      },
      expressiveCode: {
        themes: [moonpoolSyntax],
        useStarlightDarkModeSwitch: false,
        useStarlightUiThemeColors: false,
        styleOverrides: { codeFontFamily: 'var(--font-mono)', codeFontSize: '13px', codeLineHeight: '1.6', borderRadius: '10px' },
      },
      sidebar: [
        { label: 'Start', items: [
          { label: 'Docs home', link: '/docs/' },
          { label: 'How it works', link: '/docs/how-it-works/' },
          { label: 'Get started', link: '/docs/getting-started/' },
          { label: 'Install with an agent', link: '/docs/install-with-an-agent/' },
        ] },
        { label: 'Use', items: [
          { label: 'Register a service', link: '/docs/registration/' },
          { label: 'Service state', link: '/docs/service-state/' },
          { label: 'Everyday operation', link: '/docs/operations/' },
          { label: 'CLI reference', link: '/docs/cli/' },
        ] },
        { label: 'Understand', items: [
          { label: 'Troubleshooting', link: '/docs/troubleshooting/' },
          { label: 'Privacy and data', link: '/docs/privacy-and-data/' },
          { label: 'Security', link: '/docs/security/' },
          { label: 'Logging', link: '/docs/logging/' },
        ] },
        { label: 'FAQ', link: '/faq/' },
      ],
    }),
  ],
});
