import site from '../site.config.mjs';
import publicPages from '../src/data/public-pages.mjs';
import { assertSafeIdentityText } from './social-preview-model.mjs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolvedPages } from './site-pages.mjs';
import { siteBasePath } from './identity-model.mjs';
import { assertPublicationLegalContact, loadLegalOperator } from '../src/lib/legal-operator.mjs';

const url = new URL(site.url);
if (url.protocol !== 'https:' || url.hostname === 'example.invalid' || site.title === 'Example Product') {
  throw new Error('Set the real HTTPS canonical URL and product title before publishing.');
}
if (url.search || url.hash || (siteBasePath(site) !== '/' && site.identity.robots !== 'origin-owned')) {
  throw new Error('Canonical URL needs a clean base path; subpath sites require origin-owned robots policy.');
}
for (const [name, value] of [
  ['identity.productName', site.identity?.productName],
  ['identity.hostSiteName', site.identity?.hostSiteName],
  ['identity.surfaceName', site.identity?.surfaceName],
  ['identity.defaultLanguage', site.identity?.defaultLanguage],
  ['identity.defaultLocale', site.identity?.defaultLocale],
  ['description', site.description],
]) {
  assertSafeIdentityText(value, name);
  if (/Example Product|Replace this/u.test(value)) throw new Error(`Replace demonstration ${name} before publishing.`);
}
if (/Example Product/u.test(site.docs.surfaceName) || /Example Product/u.test(site.identity.social.markText ?? '')) {
  throw new Error('Replace demonstration Docs and social identity before publishing.');
}

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
for (const page of resolvedPages(site, publicPages, projectRoot).values()) {
  if (page.indexing === 'index') assertSafeIdentityText(page.description, `page description ${page.path}`);
  assertSafeIdentityText(page.title, `page title ${page.path}`);
  if (/Example Product|Replace this/u.test(page.title + page.description)) {
    throw new Error(`Replace demonstration page identity: ${page.path}`);
  }
}

if (site.identity.install.kind === 'application') {
  for (const key of ['id', 'startUrl', 'scope', 'name', 'shortName', 'display', 'icon192', 'icon512', 'maskable512']) {
    if (typeof site.identity.install[key] !== 'string' || !site.identity.install[key].trim()) {
      throw new Error(`Application manifest needs identity.install.${key}.`);
    }
  }
}

const requiredText = [
  ['lastUpdated', site.legal?.lastUpdated],
  ...['hosting', 'purposeAndBasis', 'recipientsAndTransfers', 'retention', 'provision', 'storage', 'contact']
    .map((key) => ['privacy.' + key, site.legal?.privacy?.[key]]),
  ...(site.terms ? ['service', 'formation', 'eligibility', 'availability', 'suspension', 'changes']
    .map((key) => ['terms.' + key, site.legal?.terms?.[key]]) : [])
];
for (const [name, value] of requiredText) {
  if (typeof value !== 'string' || !value.trim()) throw new Error('Configure legal.' + name + ' before publishing.');
}
if (JSON.stringify(site.legal).includes('REPLACE_WITH_')) {
  throw new Error('Replace every legal/privacy/Terms placeholder before publishing.');
}
const operator = loadLegalOperator({ requireProduction: true });
assertPublicationLegalContact(operator, site.legal.contact, site.legal?.impressum?.directContact);
console.log('Publication identity and legal operator data are configured; this does not certify copy, hosting, provider processing, indexing or external previews.');
