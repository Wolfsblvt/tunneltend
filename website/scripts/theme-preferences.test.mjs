// SPDX-License-Identifier: AGPL-3.0-only
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runInNewContext } from 'node:vm';
import { themeScript, persistPreferences } from '../src/lib/theme-script.mjs';

function page({ local = {}, cookie = '', light = false, blockedLocal = false, blockedCookie = false, hostname = 'tunneltend.com' } = {}) {
  const attributes = new Map();
  const writes = [];
  const store = new Map(Object.entries(local));
  const document = {
    documentElement: { setAttribute: (key, value) => attributes.set(key, value), getAttribute: key => attributes.get(key) },
    get cookie() { if (blockedCookie) throw Error('blocked'); return cookie; },
    set cookie(value) { if (blockedCookie) throw Error('blocked'); writes.push(value); cookie = value.split(';')[0]; },
  };
  const context = { document, location: { hostname, protocol: 'https:' }, window: { matchMedia: () => ({ matches: light }) },
    localStorage: { getItem(key) { if (blockedLocal) throw Error('blocked'); return store.get(key) ?? null; },
      setItem(key, value) { if (blockedLocal) throw Error('blocked'); store.set(key, value); } } };
  runInNewContext(themeScript, context);
  return { attributes, writes, context, persist: () => runInNewContext(`(${persistPreferences.toString()})();`, context) };
}

test('a first visit remains dark without creating a preference cookie', () => {
  const result = page();
  assert.equal(result.attributes.get('data-theme'), 'dark');
  assert.equal(result.writes.length, 0);
});

test('legacy light and reader choices migrate together to the shared domain', () => {
  const result = page({ local: { 'tunneltend.theme': 'light', 'tunneltend.reader': 'dev' } });
  assert.match(result.writes[0], /^tunneltend.preferences=light.dark.dev; Domain=tunneltend.com; Path=\/; Max-Age=31536000; SameSite=Lax; Secure$/);
});

test('shared Automatic and its traversal phase beat stale origin-local choices', () => {
  for (const light of [true, false]) {
    const result = page({ cookie: 'other=1; tunneltend.preferences=auto.dark.dev', light,
      local: { 'tunneltend.theme': 'light', 'tunneltend.theme.next': 'light' } });
    assert.equal(result.attributes.get('data-theme-pref'), 'auto');
    assert.equal(result.attributes.get('data-theme'), light ? 'light' : 'dark');
    assert.equal(result.attributes.get('data-theme-next'), 'dark');
    assert.equal(result.attributes.get('data-reader'), 'dev');
    assert.equal(result.writes.length, 0, 'ordinary visits do not renew the cookie');
  }
});

test('legacy Automatic without a phase starts toward the opposite displayed side', () => {
  const result = page({ local: { 'tunneltend.theme': 'auto' }, light: true });
  assert.equal(result.attributes.get('data-theme-next'), 'dark');
  assert.match(result.writes[0], /auto.dark.plain/);
});

test('cookie continuity works with blocked local storage', () => {
  const result = page({ blockedLocal: true, cookie: 'tunneltend.preferences=light.dark.plain' });
  assert.equal(result.attributes.get('data-theme'), 'light');
  result.persist();
  assert.equal(result.writes.length, 1);
});

test('blocked cookies retain local fallback; all-storage refusal remains usable', () => {
  const local = page({ blockedCookie: true, local: { 'tunneltend.theme': 'light' } });
  assert.equal(local.attributes.get('data-theme'), 'light');
  const blocked = page({ blockedCookie: true, blockedLocal: true });
  blocked.attributes.set('data-theme-pref', 'light');
  blocked.persist();
  assert.equal(blocked.attributes.get('data-theme-pref'), 'light');
});

test('malformed shared values cannot override valid local choices', () => {
  const result = page({ cookie: 'tunneltend.preferences=auto.bad.dev', local: { 'tunneltend.theme': 'light' } });
  assert.equal(result.attributes.get('data-theme-pref'), 'light');
});

test('preview and unrelated hosts never write the public-domain cookie', () => {
  const result = page({ hostname: '127.0.0.1', local: { 'tunneltend.theme': 'light' } });
  result.persist();
  assert.equal(result.writes.length, 0);
});
