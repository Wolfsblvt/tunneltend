/**
 * Every custom HTML route, including legal and error pages. Documentation pages are
 * enumerated from the Starlight content collection instead. This inventory drives the
 * layout, the sitemap, the generated social cards and the publication check.
 */
export default [
  {
    path: '/',
    title: null,
    description:
      'Connect an app or tool running on your Windows PC to ChatGPT through OpenAI’s official tunnel client, and let TunnelTend keep it connected: startup at sign-in, health checks, bounded recovery and verified client updates. Free and open source.',
    surfaceName: 'TunnelTend',
    indexing: 'index',
    role: 'public',
    social: {
      generate: true,
      alt: 'TunnelTend: register once, leave the routine to TunnelTend.',
    },
  },
  {
    path: '/faq/',
    title: 'FAQ',
    description:
      'Answers about what TunnelTend does, its relationship to OpenAI and ChatGPT, local operation, privacy, automation, the Windows release and the licence.',
    role: 'public',
    social: { generate: true, eyebrow: 'Questions', alt: 'TunnelTend FAQ' },
  },
  {
    path: '/impressum/',
    title: 'Impressum',
    description: 'Provider and contact information.',
    role: 'legal',
  },
  {
    path: '/privacy/',
    title: 'Privacy and data',
    description: 'How this website processes personal data.',
    role: 'legal',
  },
  {
    path: '/404/',
    title: 'Page not found',
    description: 'This address does not point to a page.',
    role: 'error',
  },
];
