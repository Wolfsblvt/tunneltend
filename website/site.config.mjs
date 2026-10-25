/**
 * The TunnelTend website's identity, destinations and legal facts. One source for pages, the
 * footer, the identity assets, the sitemap and the publication check. Operator data (name,
 * postal address) never lives here; it reaches the production build only through the private
 * WOLFSBLVT_LEGAL_OPERATOR_B64 projection.
 */
import { PRODUCT_ORIGIN, DOCS_ORIGIN } from './src/lib/public-routes.mjs';
const github = 'https://github.com/Wolfsblvt/tunneltend';

export default {
  title: 'TunnelTend',
  description:
    'Connect an app or tool running on your Windows PC to ChatGPT through OpenAI’s official tunnel client, and let TunnelTend keep it connected: startup at sign-in, health checks, bounded recovery and verified client updates. Free and open source.',
  url: PRODUCT_ORIGIN,
  docs: {
    mode: 'manual',
    url: DOCS_ORIGIN,
    surfaceName: 'TunnelTend Docs',
  },
  identity: {
    productName: 'TunnelTend',
    hostSiteName: 'TunnelTend',
    surfaceName: 'TunnelTend',
    descriptor: { text: null, persist: false },
    defaultLanguage: 'en',
    defaultLocale: 'en_US',
    themeColor: '#191821',
    backgroundColor: '#191821',
    icons: {
      svg: '/favicon.svg',
      raster: '/favicon-192.png',
      touch: '/apple-touch-icon.png',
    },
    social: {
      fallbackImage: '/social/generated/home.png',
      markText: 'tunneltend.com',
      // Moonpool After Dark, graphite field. The Fold is drawn by the card generator itself.
      colors: {
        background: '#191821',
        panel: '#221f2b',
        foreground: '#f0edf3',
        muted: '#aaa4b2',
        accent: '#79cad9',
      },
    },
    install: { kind: 'site' },
  },
  terms: false,
  publisher: 'Wolfsblvt Works',
  openSource: true,

  links: {
    source: github,
    releases: `${github}/releases`,
    latestRelease: `${github}/releases/latest`,
    status: null,
    security: `${github}/security/policy`,
    licences: `${github}/blob/main/LICENSE`,
    github: 'https://github.com/Wolfsblvt',
    maker: 'https://wolfsblvt.works',
    discordCommunity: 'https://wolfsblvt.com/discord',
    // Shown as a visibly unavailable row until the profile exists; set the URL and it becomes a link.
    bluesky: null,
  },

  sponsors: {
    github: 'https://github.com/sponsors/Wolfsblvt',
    kofi: 'https://ko-fi.com/wolfsblvt',
  },

  // The two middle footer columns are product-owned. The first (product) and last (Project) are fixed.
  footerGroups: [
    {
      title: 'Get',
      links: [
        { label: 'Install on Windows', href: '/#install' },
        { label: 'Download the release', href: `${github}/releases/latest` },
        { label: 'Install with an agent', href: '/docs/install-with-an-agent/' },
      ],
    },
    {
      title: 'Learn',
      links: [
        { label: 'How it works', href: '/docs/how-it-works/' },
        { label: 'Get started', href: '/docs/getting-started/' },
        { label: 'Everyday operation', href: '/docs/operations/' },
        { label: 'Use it through an agent', href: '/docs/agents/' },
        { label: 'CLI reference', href: '/docs/cli/' },
        { label: 'FAQ', href: '/faq/' },
      ],
    },
  ],

  legal: {
    lastUpdated: '2026-10-22',
    contact: null,
    impressum: { directContact: null },
    consumerDispute: null,
    privacy: {
      hosting:
        'This website is static and served by Cloudflare, Inc. (Cloudflare Workers with static assets). When you open a page, your browser sends the request with your IP address, the requested address, the time, the referring page if any, and browser and device information. Cloudflare processes that data to deliver the page and to protect the site against abuse.',
      purposeAndBasis:
        'Delivery of the pages you request, security of the site and troubleshooting of delivery faults. Legal basis: our legitimate interest in operating a reachable, secure website (Art. 6(1)(f) GDPR).',
      recipientsAndTransfers:
        'Cloudflare, Inc., San Francisco, USA, delivers the site through its global network, so a request may be answered from a server outside the EU. The transfer relies on the EU–US Data Privacy Framework and Cloudflare’s standard contractual clauses.',
      retention:
        'We do not keep request logs ourselves. Cloudflare, which delivers the site, processes request data such as your IP address and the page you asked for in order to deliver it and to run its security layer; how long it keeps that data is set by Cloudflare’s own policy, not by us.',
      provision:
        'Your browser has to send the request data to receive a page. There is no account, form, newsletter or tracking on this site, so no further information is required from you.',
      storage:
        'The site uses no analytics or tracking. Your appearance choice, the next theme-toggle direction and plain or developer reading mode are functional preferences. A first-party cookie (tunneltend.preferences) shares only those values between tunneltend.com and docs.tunneltend.com for up to one year after you choose them; it contains no identifier. Your browser sends it with requests to tunneltend.com and its subdomains, including the hosting provider. Local storage also keeps a fallback copy on each origin. Existing saved choices migrate when you visit their original host if no shared preference exists yet. This necessary preference storage supports the reading experience you request (§ 25(2) TDDDG). Clear the cookie and both sites’ local storage to reset it. If cookies are blocked, choices remain local to each host; if all storage is unavailable, they last for the current page. Cloudflare’s security layer may set a strictly necessary short-lived cookie to tell people from bots.',
      contact:
        'If you write to the contact address on the Impressum, we process your email address and what you wrote only to answer you. Legal basis: Art. 6(1)(b) GDPR where you ask about the product, otherwise Art. 6(1)(f) GDPR. Messages are kept as long as the conversation needs it and deleted afterwards. Writing to us is voluntary.',
    },
    terms: null,
  },
};
