import { composeDocumentTitle, normalizePublicRoute, resolveSocialImage } from './social-preview-model.mjs';
import { publicDestination } from '../src/lib/public-routes.mjs';

export function siteBasePath(site) {
  return normalizePublicRoute(new URL(site.url).pathname);
}

export function routeFromPath(site, pathname) {
  const base = siteBasePath(site);
  const path = normalizePublicRoute(pathname);
  if (base === '/') return path;
  if (!path.startsWith(base)) throw new Error(`Route ${path} is outside the canonical base ${base}.`);
  return normalizePublicRoute(`/${path.slice(base.length)}`);
}

export function publicUrl(site, route) {
  const base = siteBasePath(site);
  const path = normalizePublicRoute(route);
  return publicDestination(new URL(`${base}${path.slice(1)}`, new URL(site.url).origin).href);
}

export function assetPath(site, path) {
  if (typeof path !== 'string' || !path.startsWith('/') || path.startsWith('//')) {
    throw new Error(`Site asset needs a root-relative path: ${String(path)}`);
  }
  return `${siteBasePath(site)}${path.slice(1)}`;
}

export function assetUrl(site, path) {
  return new URL(assetPath(site, path), new URL(site.url).origin).href;
}

export function resolvePageIdentity(site, route, source = {}, { surfaceName = site.identity.surfaceName } = {}) {
  const path = normalizePublicRoute(route);
  const role = source.role ?? 'public';
  if (!['public', 'unlisted', 'task', 'legal', 'error', 'private', 'preview', 'resource'].includes(role)) {
    throw new Error(`Unsupported page role: ${role}`);
  }
  const indexing = source.indexing ?? (role === 'public' || role === 'task' ? 'index' : 'noindex');
  const sharing = source.sharing ?? (role === 'public' || role === 'task' ? 'share' : 'none');
  if (!['index', 'noindex'].includes(indexing) || !['share', 'none'].includes(sharing)) {
    throw new Error(`Invalid indexing or sharing for ${path}.`);
  }
  if (indexing === 'index' && !['public', 'task'].includes(role)) {
    throw new Error(`${role} page cannot be indexed: ${path}`);
  }
  const canonicalAllowed = !['legal', 'error', 'private', 'preview', 'resource'].includes(role);
  const canonical = canonicalAllowed && source.canonical !== false
    ? publicUrl(site, source.canonical ?? path)
    : null;
  if (indexing === 'index' && !canonical) throw new Error(`Indexed page needs a canonical URL: ${path}`);
  const isHome = path === '/' || source.home === true;
  const configuredDescriptor = site.identity.descriptor;
  const inheritedDescriptor = typeof configuredDescriptor === 'string'
    ? configuredDescriptor
    : configuredDescriptor?.text;
  const persistent = typeof configuredDescriptor === 'object' && configuredDescriptor?.persist === true;
  const descriptor = Object.hasOwn(source, 'descriptor')
    ? source.descriptor
    : isHome || persistent ? inheritedDescriptor : null;
  const page = source.home === true ? null : source.title ?? null;
  const section = descriptor ? null : source.section ?? null;
  const title = composeDocumentTitle({ page, section, surface: source.surfaceName ?? surfaceName, descriptor });
  const description = source.description ?? site.description;
  const language = source.language ?? site.identity.defaultLanguage;
  const locale = source.locale ?? site.identity.defaultLocale;
  const social = source.social ?? {};
  const socialImage = sharing === 'share'
    ? resolveSocialImage({
        explicitImage: social.image,
        generated: social.generate,
        route: path,
        fallbackImage: site.identity.social.fallbackImage,
      })
    : null;
  const generateCard = sharing === 'share' && !social.image && social.generate !== false;
  const imageUrl = socialImage
    ? socialImage.startsWith('https://') ? socialImage : assetUrl(site, socialImage)
    : null;
  const docsHome = path === '/docs/';
  const structuredData = role === 'public' && (path === '/' || docsHome)
    ? {
        '@context': 'https://schema.org',
        '@type': 'WebSite',
        name: docsHome ? site.docs.surfaceName : site.identity.hostSiteName,
        url: publicUrl(site, path),
        description,
        inLanguage: language,
      }
    : null;

  return {
    path, role, indexing, sharing, canonical, title, pageTitle: page ?? title,
    description, language, locale, socialImage, imageUrl, generateCard,
    socialAlt: social.alt ?? `${source.surfaceName ?? surfaceName} preview`,
    socialEyebrow: social.eyebrow ?? source.section,
    socialFact: social.fact,
    surfaceName: source.surfaceName ?? surfaceName,
    structuredData,
  };
}
