// SPDX-License-Identifier: AGPL-3.0-only
/** One before-paint rule for the product pages and the manual: the theme preference with its
 * bounce direction, and the reader mode (plain words, or "Excuse me, I'm a dev?!"). Both live
 * in local storage only; nothing is sent anywhere. */
export const THEME_KEY = 'tunneltend.theme';
export const THEME_NEXT_KEY = 'tunneltend.theme.next';
export const READER_KEY = 'tunneltend.reader';

export function initializeTheme() {
  const d = document.documentElement;
  let p = 'dark', n = 'light', saved = false, reader = 'plain';
  try {
    const value = localStorage.getItem('tunneltend.theme');
    if (['dark', 'auto', 'light'].includes(value)) p = value;
    const next = localStorage.getItem('tunneltend.theme.next');
    if (next === 'dark' || next === 'light') { n = next; saved = true; }
    if (localStorage.getItem('tunneltend.reader') === 'dev') reader = 'dev';
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
}

export const themeScript = `(${initializeTheme.toString()})();`;
