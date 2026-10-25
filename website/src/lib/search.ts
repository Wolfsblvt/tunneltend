// SPDX-License-Identifier: AGPL-3.0-only
/**
 * Global search over the Pagefind index the build writes for the whole site: product pages,
 * the manual and the FAQ. One modal on every route; the index and its runtime load on first
 * open, never on page load. In `astro dev` the index does not exist and the modal says so.
 */
import { publicDestination } from './public-routes.mjs';
interface SubResult { readonly title: string; readonly url: string; readonly excerpt: string }
interface ResultData { readonly url: string; readonly excerpt: string; readonly meta: { readonly title?: string }; readonly sub_results?: readonly SubResult[] }
interface Pagefind {
  init?: () => Promise<void>;
  debouncedSearch: (query: string, options?: object, delay?: number) => Promise<{ results: { data: () => Promise<ResultData> }[] } | null>;
}

const MAX_RESULTS = 8;
let engine: Promise<Pagefind | undefined> | undefined;

function load(): Promise<Pagefind | undefined> {
  // Assembled at run time so the bundler leaves it alone: the file exists only in built output.
  const path = ['', 'pagefind', 'pagefind.js'].join('/');
  engine ??= import(/* @vite-ignore */ path).then(async (module: Pagefind) => { await module.init?.(); return module; }).catch(() => undefined);
  return engine;
}

type Kind = 'docs' | 'faq' | 'site';
const kindOf = (url: string): Kind => {
  const target = new URL(publicDestination(url));
  return target.hostname === 'docs.tunneltend.com' ? 'docs' : target.pathname.startsWith('/faq/') ? 'faq' : 'site';
};
const kindLabel: Record<Kind, string> = { docs: 'Docs', faq: 'FAQ', site: 'Site' };

function hit(data: ResultData): HTMLLIElement {
  const kind = kindOf(data.url);
  const item = document.createElement('li');
  const link = document.createElement('a');
  link.className = 'search-hit'; link.href = publicDestination(data.url); link.dataset.kind = kind;
  const head = document.createElement('span'); head.className = 'search-hit-head';
  const chip = document.createElement('span'); chip.className = 'chip-meta search-kind'; chip.textContent = kindLabel[kind];
  const title = document.createElement('span'); title.className = 'search-hit-title'; title.textContent = data.meta.title ?? data.url;
  head.append(chip, title);
  const excerpt = document.createElement('span'); excerpt.className = 'search-hit-excerpt';
  excerpt.innerHTML = data.excerpt; // Pagefind escapes the page text and adds only <mark>.
  link.append(head, excerpt);
  item.append(link);
  const subs = (data.sub_results ?? []).filter(sub => sub.url !== data.url).slice(0, 3);
  if (subs.length > 0) {
    const list = document.createElement('ul'); list.className = 'search-subs';
    for (const sub of subs) {
      const li = document.createElement('li'); const a = document.createElement('a');
      a.className = 'search-sub'; a.href = publicDestination(sub.url); a.textContent = sub.title;
      li.append(a); list.append(li);
    }
    item.append(list);
  }
  return item;
}

export function wireSearch(): void {
  const dialog = document.querySelector<HTMLDialogElement>('[data-search-dialog]');
  if (!dialog) return;
  const input = dialog.querySelector<HTMLInputElement>('[data-search-input]')!;
  const status = dialog.querySelector<HTMLElement>('[data-search-status]')!;
  const results = dialog.querySelector<HTMLElement>('[data-search-results]')!;
  const hint = status.textContent ?? '';
  let sequence = 0;

  const open = (): void => { if (!dialog.open) dialog.showModal(); input.focus(); input.select(); void load(); };
  for (const trigger of document.querySelectorAll<HTMLButtonElement>('[data-search-open]')) trigger.addEventListener('click', open);
  document.addEventListener('keydown', event => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); open(); }
  });
  dialog.addEventListener('close', () => {
    window.setTimeout(() => {
      if (document.activeElement && document.activeElement !== document.body) return;
      [...document.querySelectorAll<HTMLButtonElement>('[data-search-open]')].find(launcher => launcher.offsetParent !== null)?.focus();
    }, 0);
  });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  dialog.querySelector('[data-search-form]')!.addEventListener('submit', event => {
    if ((event as SubmitEvent).submitter) return;
    event.preventDefault();
    results.querySelector<HTMLAnchorElement>('a')?.click();
  });
  results.addEventListener('click', event => {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    const link = event.target instanceof Element ? event.target.closest('a[href]') : null;
    if (!(link instanceof HTMLAnchorElement)) return;
    const target = new URL(link.href);
    if (target.origin === location.origin && target.pathname === location.pathname && target.hash) dialog.close();
  });
  dialog.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); dialog.close(); return; }
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
    const stops: HTMLElement[] = [input, ...results.querySelectorAll<HTMLAnchorElement>('a')];
    const index = stops.indexOf(document.activeElement as HTMLElement);
    event.preventDefault();
    stops[(index + (event.key === 'ArrowDown' ? 1 : -1) + stops.length) % stops.length]?.focus();
  });

  input.addEventListener('input', async () => {
    const query = input.value.trim();
    const mine = ++sequence;
    if (!query) { results.replaceChildren(); status.textContent = hint; return; }
    const pagefind = await load();
    if (mine !== sequence) return;
    if (!pagefind) { results.replaceChildren(); status.textContent = 'The search index is part of the built site and is not available in this preview.'; return; }
    const found = await pagefind.debouncedSearch(query, {}, 120);
    if (!found || mine !== sequence) return;
    const data = await Promise.all(found.results.slice(0, MAX_RESULTS).map(result => result.data()));
    if (mine !== sequence) return;
    results.replaceChildren(...data.map(hit));
    const total = found.results.length;
    status.textContent = total > 0
      ? (total > data.length ? `${total} results · showing the first ${data.length}` : `${total} result${total === 1 ? '' : 's'}`)
      : `Nothing found for “${query}”.`;
  });
}
