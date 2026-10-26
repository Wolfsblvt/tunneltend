// SPDX-License-Identifier: AGPL-3.0-only
import { existsSync, readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const home = readFileSync('artifacts/site/index.html', 'utf8');
assert.match(home, /data-compatibility(?:\s|>)/);
const summaryMatch = home.match(/<section(?=[^>]*data-compatibility-summary)[^>]*>([\s\S]*?)<\/section>/);
assert.ok(summaryMatch, 'built page is missing its always-visible released-client summary');
const summary = summaryMatch[0];
assert.equal([...summary.matchAll(/data-compatibility-outcome=/g)].length, 4, 'the visible summary must keep all four outcomes separate');
if (existsSync('artifacts/compatibility/facts.json')) {
  const facts = JSON.parse(readFileSync('artifacts/compatibility/facts.json', 'utf8'));
  assert.ok(home.includes(`data-website-source="${facts.websiteCommit}"`), 'built page lost its actual website source identity');
  const release = facts.groups.find(group => group.kind === 'release' && group.architecture === 'amd64');
  const item = release?.newest;
  if (item?.release) {
    assert.ok(summary.includes(item.release.tag), 'visible summary lost the latest released-client tag');
    assert.ok(summary.includes(`datetime="${item.release.publishedAt}"`), 'visible summary lost the official publication date');
  } else {
    assert.match(summary, /Release evidence unavailable/);
    assert.match(summary, /Publication date unavailable/);
  }
  if (item) {
    for (const key of ['distribution', 'credentialFreeCli', 'localFleet', 'connectedConsumer']) {
      const outcome = item[key].outcome === 'not exercised' ? 'Not exercised' : item[key].outcome[0].toUpperCase() + item[key].outcome.slice(1);
      assert.ok(summary.includes(outcome), `visible summary lost the ${key} outcome`);
    }
    assert.ok(!summary.includes(item.package.sha256 ?? '\u0000'), 'package hashes belong behind the details disclosure');
  } else {
    assert.equal((summary.match(/Unavailable/g) ?? []).length, 4, 'missing release evidence must remain explicit for each boundary');
  }
  const hasIdentityChange = facts.identityHistory.identities.some(item => item.changes.length > 0);
  const warningIndex = home.indexOf('data-same-tag-warning');
  const detailsIndex = home.indexOf('data-compatibility-details');
  assert.equal(warningIndex >= 0, hasIdentityChange, 'a same-tag change must produce one visible warning');
  if (hasIdentityChange) assert.ok(warningIndex < detailsIndex, 'the material warning must remain outside the details disclosure');
  for (const group of facts.groups) {
    assert.ok(home.includes(group.newest.evidence.artifactUrl), 'built page lost the exact consumed artifact identity');
    assert.ok(home.includes(group.newest.evidence.runUrl), 'built page lost the exact run/attempt identity');
  }
}
console.log('Built compatibility display preserves its visible summary and the exact consumed evidence coordinates.');
