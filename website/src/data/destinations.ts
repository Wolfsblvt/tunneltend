// SPDX-License-Identifier: AGPL-3.0-only
/**
 * The one list of community and external destinations. The header's Community panel and
 * the footer render from it, so a destination is activated in exactly one place. A
 * destination without a real URL stays listed and renders unavailable, never invented.
 *
 * Header rule: GitHub is the one direct icon, so it stays out of the Community panel.
 * Footer rule: icons only, never collapsed, complete: Works, Discord, Bluesky, GitHub.
 */
import site from '../../site.config.mjs';
import type { IconName } from './icons';
import { GITHUB } from './site';

export interface Destination {
  readonly id: string;
  readonly icon: IconName;
  readonly label: string;
  readonly note: string;
  readonly href: string | null;
}

const works: Destination = { id: 'works', icon: 'website', label: 'Wolfsblvt Works', note: 'About the maker', href: site.links.maker };
const discord: Destination = { id: 'discord', icon: 'discord', label: 'Discord', note: 'Wolfsblvt Works community', href: site.links.discordCommunity };
const bluesky: Destination = { id: 'bluesky', icon: 'bluesky', label: 'Bluesky', note: 'Development updates', href: site.links.bluesky };
const github: Destination = { id: 'github', icon: 'github', label: 'GitHub', note: 'Source code', href: GITHUB };

export const community: readonly Destination[] = [discord, bluesky, works];
export const footerSocials: readonly Destination[] = [works, discord, bluesky, github];
