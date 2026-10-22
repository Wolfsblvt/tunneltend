// SPDX-License-Identifier: AGPL-3.0-only
/** Selected facts the pages share: origins, repository, release and official OpenAI destinations. */
import site from '../../site.config.mjs';

export const ORIGIN: string = site.url.replace(/\/$/u, '');
export const REPO = 'Wolfsblvt/tunneltend';
export const GITHUB = `https://github.com/${REPO}`;
export const RELEASES = `${GITHUB}/releases`;
export const LATEST_RELEASE = `${GITHUB}/releases/latest`;
export const COMPANY = 'Wolfsblvt Works';
export const COMPANY_SITE = 'https://wolfsblvt.works';

/** The current stable release this site describes. Change it with the release, not with the design. */
export const RELEASE_VERSION = '1.0.0';
export const RELEASE_TAG = `v${RELEASE_VERSION}`;
export const RELEASE_URL = `${GITHUB}/releases/tag/${RELEASE_TAG}`;
export const RELEASE_ZIP = `${GITHUB}/releases/download/${RELEASE_TAG}/tunneltend-${RELEASE_VERSION}.zip`;
export const RELEASE_SHA = `${RELEASE_ZIP}.sha256`;

/** One-line installation. The served script downloads the release, verifies its checksum and runs the installer. */
export const INSTALL_COMMAND = `irm ${ORIGIN}/install.ps1 | iex`;

export const paths = {
  home: '/',
  docs: '/docs/',
  faq: '/faq/',
  privacy: '/privacy/',
  impressum: '/impressum/',
  install: '/#install',
  installScript: '/install.ps1',
} as const;

export const docPaths = {
  howItWorks: '/docs/how-it-works/',
  getStarted: '/docs/getting-started/',
  prepareOpenAI: '/docs/getting-started/#prepare-your-openai-access',
  connectChatGPT: '/docs/getting-started/#connect-it-in-chatgpt',
  verify: '/docs/getting-started/#verify-the-whole-connection',
  agent: '/docs/install-with-an-agent/',
  registration: '/docs/registration/',
  serviceState: '/docs/service-state/',
  operations: '/docs/operations/',
  stops: '/docs/operations/#stop-a-service-on-purpose',
  updates: '/docs/operations/#official-client-updates',
  uninstall: '/docs/operations/#uninstall',
  cli: '/docs/cli/',
  troubleshooting: '/docs/troubleshooting/',
  privacyAndData: '/docs/privacy-and-data/',
  security: '/docs/security/',
  logging: '/docs/logging/',
} as const;

/** OpenAI's own resources. These are the authority for the tunnel side; TunnelTend only links to them. */
export const openai = {
  tunnelsGuide: 'https://developers.openai.com/api/docs/guides/secure-mcp-tunnels',
  clientRepo: 'https://github.com/openai/tunnel-client',
  clientReleases: 'https://github.com/openai/tunnel-client/releases',
  onboarding: 'https://github.com/openai/tunnel-client/blob/master/docs/onboarding.md',
  permissions: 'https://github.com/openai/tunnel-client/blob/master/docs/permissions.md',
  platformTunnels: 'https://platform.openai.com/settings/organization/tunnels',
  mcp: 'https://modelcontextprotocol.io/',
} as const;

/** The copied task hands a local coding agent the canonical guide; the guide carries the contract. */
export const AGENT_PROMPT = `Install TunnelTend for my current Windows user and register the MCP service I identify, following this guide: ${ORIGIN}${docPaths.agent}`;

export function absolute(path: string): string {
  return new URL(path, ORIGIN).href;
}
