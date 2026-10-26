// SPDX-License-Identifier: AGPL-3.0-only
import { existsSync, readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const home = readFileSync('artifacts/site/index.html', 'utf8');
assert.match(home, /data-compatibility(?:\s|>)/);
if (existsSync('artifacts/compatibility/facts.json')) {
  const facts = JSON.parse(readFileSync('artifacts/compatibility/facts.json', 'utf8'));
  assert.ok(home.includes(`data-website-source="${facts.websiteCommit}"`), 'built page lost its actual website source identity');
  for (const group of facts.groups) {
    assert.ok(home.includes(group.newest.evidence.artifactUrl), 'built page lost the exact consumed artifact identity');
    assert.ok(home.includes(group.newest.evidence.runUrl), 'built page lost the exact run/attempt identity');
  }
}
console.log('Built compatibility display carries its actual source and consumed evidence coordinates.');
