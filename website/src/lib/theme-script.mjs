// SPDX-License-Identifier: AGPL-3.0-only
/** One before-paint rule for the product pages and the manual: the theme preference with its
 * bounce direction, and the reader mode (plain words, or "Excuse me, I'm a dev?!"). Both
 * share a functional preference cookie on the product and Docs hosts, with local storage
 * as a fallback. The cookie contains no identifier. */
/** Persist only fixed preference values, shared only by the two supported public hosts. */
export function persistPreferences() {
  const root = document.documentElement;
  const pref = root.getAttribute('data-theme-pref');
  const next = root.getAttribute('data-theme-next');
  const reader = root.getAttribute('data-reader');
  if (!['dark', 'auto', 'light'].includes(pref) || !['dark', 'light'].includes(next) || !['plain', 'dev'].includes(reader)) return;
  try {
    localStorage.setItem('tunneltend.theme', pref);
    localStorage.setItem('tunneltend.theme.next', next);
    localStorage.setItem('tunneltend.reader', reader);
  } catch { /* Cookies can still preserve the choice when local storage is unavailable. */ }
  if (location.protocol !== 'https:' || !['tunneltend.com', 'docs.tunneltend.com'].includes(location.hostname)) return;
  try {
    document.cookie = `tunneltend.preferences=${pref}.${next}.${reader}; Domain=tunneltend.com; Path=/; Max-Age=31536000; SameSite=Lax; Secure`;
  } catch { /* Storage refusal leaves the current page usable. */ }
}

/** Resolve shared preferences or migrate this origin's existing choice before paint. */
export function initializeTheme() {
  const d = document.documentElement;
  let p = 'dark', n = 'light', saved = false, reader = 'plain', migrate = false;
  try {
    const value = localStorage.getItem('tunneltend.theme');
    if (['dark', 'auto', 'light'].includes(value)) { p = value; migrate = true; }
    const next = localStorage.getItem('tunneltend.theme.next');
    if (next === 'dark' || next === 'light') { n = next; saved = true; }
    if (localStorage.getItem('tunneltend.reader') === 'dev') { reader = 'dev'; migrate = true; }
  } catch {}
  // Shared state wins over an origin's older local copy. Migrate only when no shared choice exists.
  try {
    const cookie = document.cookie.split(';').map(value => value.trim()).find(value => value.startsWith('tunneltend.preferences='));
    const match = cookie?.match(/^tunneltend\.preferences=(dark|auto|light)\.(dark|light)\.(plain|dev)$/);
    if (match) { [, p, n, reader] = match; saved = true; migrate = false; }
  } catch {}
  let light = false;
  try { light = window.matchMedia('(prefers-color-scheme: light)').matches; } catch {}
  const resolved = p === 'auto' ? (light ? 'light' : 'dark') : p;
  // A legacy Auto without a phase starts toward the opposite of what is on screen, once.
  if (p === 'auto' && !saved) { n = resolved === 'dark' ? 'light' : 'dark'; try { localStorage.setItem('tunneltend.theme.next', n); } catch {} }
  if (p !== 'auto') n = p === 'dark' ? 'light' : 'dark';
  d.setAttribute('data-theme', resolved);
  d.setAttribute('data-theme-pref', p);
  d.setAttribute('data-theme-next', n);
  d.setAttribute('data-reader', reader);
  if (migrate) persistPreferences();
}

export const themeScript = `${persistPreferences.toString()}\n(${initializeTheme.toString()})();`;
