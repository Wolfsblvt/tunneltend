// SPDX-License-Identifier: AGPL-3.0-only
/**
 * Semantic icon names for the site, resolved through the shared Wolfsblvt Works catalogue
 * (@wolfsblvt/icons) and the locally installed Iconify collections. Callers name a meaning,
 * never a drawing; the glyph data is inlined at build time, nothing is fetched at run time.
 */
import { createRequire } from 'node:module';
import { getBrand, resolveUiIcon } from '@wolfsblvt/icons';
import type { UiIconName } from '@wolfsblvt/icons';

export const iconMap = {
  // header and shell
  search: 'ui:search',
  chevron: 'ui:lucide:chevron-down',
  'social-links': 'ui:lucide:waypoints',
  external: 'ui:lucide:arrow-up-right',
  copy: 'ui:copy',
  check: 'ui:lucide:check',
  'theme-light': 'ui:lucide:sun',
  'theme-dark': 'ui:lucide:moon',
  menu: 'ui:lucide:menu',
  // destinations
  github: 'brand:github',
  discord: 'brand:discord',
  bluesky: 'brand:bluesky',
  website: 'ui:lucide:globe',
  // product concepts
  windows: 'ui:lucide:monitor',
  terminal: 'ui:lucide:terminal',
  download: 'ui:lucide:download',
  bot: 'ui:lucide:bot',
  heart: 'ui:lucide:heart',
  shield: 'ui:lucide:shield-check',
  refresh: 'ui:lucide:refresh-cw',
  power: 'ui:lucide:power',
  pause: 'ui:lucide:pause',
  eye: 'ui:lucide:eye',
  'file-text': 'ui:lucide:file-text',
  'book-open': 'ui:lucide:book-open',
  'arrow-right': 'ui:lucide:arrow-right',
  link: 'ui:lucide:link',
} as const;

export type IconName = keyof typeof iconMap;

interface IconCollection { readonly icons: Record<string, { readonly body: string }> }
const require = createRequire(import.meta.url);
const lucide = require('@iconify-json/lucide/icons.json') as IconCollection;
const simple = require('@iconify-json/simple-icons/icons.json') as IconCollection;

export interface ResolvedIcon { readonly body: string; readonly viewBox: string }

export function resolveIcon(name: IconName): ResolvedIcon {
  const [kind, glyph] = iconMap[name].split(/:(.*)/su) as [string, string];
  const reference = kind === 'ui' ? resolveUiIcon(glyph as UiIconName) : getBrand(glyph).iconifyName;
  const [collection, id] = reference.split(':') as ['lucide' | 'simple-icons', string];
  const body = collection === 'lucide' ? lucide.icons[id]?.body : simple.icons[id]?.body;
  if (!body) throw new Error(`Icon "${name}" (${reference}) is not in its installed collection.`);
  return { body, viewBox: '0 0 24 24' };
}
