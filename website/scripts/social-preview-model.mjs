import { createHash } from 'node:crypto';

const controlCharacters = /[\u0000-\u001f\u007f-\u009f\u061c\u200b\u200e-\u200f\u202a-\u202e\u2060-\u206f\ufeff]/u;

export function assertSafeIdentityText(value, label = 'identity text') {
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${label} must be a non-empty string.`);
  }
  if (controlCharacters.test(value)) {
    throw new Error(`${label} contains invisible, control, or bidirectional formatting characters.`);
  }
  return value.trim();
}

export function normalizePublicRoute(route) {
  if (typeof route !== 'string' || !route.startsWith('/')) {
    throw new Error('Public routes must start with /.');
  }
  const path = route.split(/[?#]/u, 1)[0].replaceAll(/\/{2,}/gu, '/');
  if (path === '/') return '/';
  return `${path.replace(/\/+$/u, '')}/`;
}

export function socialCardPath(route, prefix = '/social/generated') {
  const normalized = normalizePublicRoute(route);
  if (normalized === '/') return `${prefix}/home.png`;
  const digest = createHash('sha256').update(normalized, 'utf8').digest('hex');
  return `${prefix}/${digest}.png`;
}

export function composeDocumentTitle({ page, section, surface, descriptor } = {}) {
  const safeSurface = assertSafeIdentityText(surface, 'surface identity');
  const safePage = page == null ? null : assertSafeIdentityText(page, 'page title');
  const safeSection = section == null ? null : assertSafeIdentityText(section, 'section title');
  const safeDescriptor = descriptor == null ? null : assertSafeIdentityText(descriptor, 'persistent descriptor');

  if (safeSection && safeDescriptor) {
    throw new Error('A document title may use a section or a persistent descriptor, not both.');
  }
  if (!safePage && safeSection) {
    throw new Error('A section title requires a page title.');
  }
  for (const [label, value] of [
    ['page title', safePage],
    ['section title', safeSection],
    ['surface identity', safeSurface],
    ['persistent descriptor', safeDescriptor],
  ]) {
    if (value?.includes(' · ')) throw new Error(`${label} must not contain the title separator.`);
  }

  const parts = safePage
    ? [safePage, safeSection, safeSurface, safeDescriptor].filter(Boolean)
    : [safeSurface, safeDescriptor].filter(Boolean);
  if (parts.length > 3) throw new Error('Document titles may contain at most three visible segments.');
  return parts.join(' · ');
}

export function resolveSocialImage({ explicitImage, generated, route, fallbackImage } = {}) {
  if (explicitImage) return explicitImage;
  if (generated !== false && route) return socialCardPath(route);
  if (fallbackImage) return fallbackImage;
  return null;
}

export function wrapCardTitle(value, { maxLines = 3, targetCharacters = 26 } = {}) {
  const words = assertSafeIdentityText(value, 'card title').split(/\s+/u);
  const lines = [];
  let current = '';

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length <= targetCharacters || !current) {
      current = candidate;
      continue;
    }
    lines.push(current);
    current = word;
  }
  if (current) lines.push(current);
  if (lines.length <= maxLines) return lines;

  const retained = lines.slice(0, maxLines);
  const remaining = lines.slice(maxLines - 1).join(' ');
  const available = Math.max(8, targetCharacters - 1);
  retained[maxLines - 1] = `${remaining.slice(0, available).trimEnd().replace(/[\s.…]+$/u, '')}…`;
  return retained;
}

export function renderSocialCardSvg({
  title,
  surface,
  eyebrow,
  fact,
  markText,
  colors = {},
} = {}) {
  const safeTitle = assertSafeIdentityText(title, 'card title');
  const safeSurface = assertSafeIdentityText(surface, 'card surface');
  const safeEyebrow = eyebrow == null ? null : assertSafeIdentityText(eyebrow, 'card eyebrow');
  const safeFact = fact == null ? null : assertSafeIdentityText(fact, 'card fact');
  const safeMark = markText == null ? safeSurface : assertSafeIdentityText(markText, 'card mark');
  const background = colors.background ?? '#0b0d12';
  const panel = colors.panel ?? '#151923';
  const foreground = colors.foreground ?? '#f8fafc';
  const muted = colors.muted ?? '#a9b2c2';
  const accent = colors.accent ?? '#8ea6ff';
  const lines = wrapCardTitle(safeTitle);
  const titleStart = lines.length === 1 ? 288 : lines.length === 2 ? 250 : 218;
  const titleSize = lines.length === 1 ? 86 : lines.length === 2 ? 72 : 62;
  const titleMarkup = lines.map((line, index) => `<tspan x="96" y="${titleStart + index * (titleSize + 14)}">${escapeXml(line)}</tspan>`).join('');
  const factMarkup = safeFact
    ? `<text x="1104" y="540" text-anchor="end" fill="${escapeXml(muted)}" font-size="30" font-family="system-ui, sans-serif">${escapeXml(safeFact)}</text>`
    : '';
  const eyebrowMarkup = safeEyebrow
    ? `<text x="96" y="170" fill="${escapeXml(accent)}" font-size="30" font-weight="700" letter-spacing="2" font-family="system-ui, sans-serif">${escapeXml(safeEyebrow.toUpperCase())}</text>`
    : '';

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="${escapeXml(background)}"/>
  <rect x="36" y="36" width="1128" height="558" rx="36" fill="${escapeXml(panel)}"/>
  <rect x="72" y="72" width="12" height="486" rx="6" fill="${escapeXml(accent)}"/>
  <text x="96" y="112" fill="${escapeXml(muted)}" font-size="27" font-weight="650" font-family="system-ui, sans-serif">${escapeXml(safeSurface)}</text>
  ${eyebrowMarkup}
  <text fill="${escapeXml(foreground)}" font-size="${titleSize}" font-weight="760" letter-spacing="-2" font-family="system-ui, sans-serif">${titleMarkup}</text>
  <text x="96" y="540" fill="${escapeXml(muted)}" font-size="30" font-weight="650" font-family="system-ui, sans-serif">${escapeXml(safeMark)}</text>
  ${factMarkup}
</svg>\n`;
}

function escapeXml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}
