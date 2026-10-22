// SPDX-License-Identifier: AGPL-3.0-only
/** Bind the portable Works sponsor template at build time. Host input is text or an enabled HTTPS destination, never HTML. */
export function renderWorksSponsor(template, { idPrefix, heading = 2, context = '', github, kofi }) {
  if (!/^[a-z][a-z0-9-]*$/u.test(idPrefix)) throw new Error('Sponsor idPrefix must be a unique lowercase HTML id.');
  if (!Number.isInteger(heading) || heading < 1 || heading > 6) throw new Error('Sponsor heading must be 1–6.');
  const escape = value => String(value).replace(/[&<>"']/gu, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
  const links = [[github, 'GitHub Sponsors', 'primary'], [kofi, 'Ko-fi', 'secondary']]
    .filter(([href]) => Boolean(href))
    .map(([href, label, className]) => {
      if (new URL(href).protocol !== 'https:') throw new Error('Sponsor destinations must be HTTPS.');
      return `<a class="${className}" href="${escape(href)}" rel="noopener">${label}</a>`;
    }).join('');
  const values = { id: idPrefix, heading: String(heading), context: context ? `<p class="add">${escape(context)}</p>` : '', links };
  return template.replace(/\{\{(id|heading|context|links)\}\}/gu, (_, key) => values[key]);
}
