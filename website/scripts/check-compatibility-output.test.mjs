// SPDX-License-Identifier: AGPL-3.0-only
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { buildEvidence } from '../../tools/compatibility/evidence-model.mjs';
import { fixtureRecord, NOW, SHA } from '../../tools/compatibility/evidence-fixtures.mjs';
import { validateQualificationReport } from '../../scripts/lib/client-qualification.mjs';
import { refreshEvidence } from '../src/lib/compatibility-evidence.ts';

const checker = fileURLToPath(new URL('./check-compatibility-output.mjs', import.meta.url));

test('expiry makes all four current outcomes and routine qualification unavailable, preserving historical results', () => {
  const expiresAt = '2027-01-24T10:00:00Z';
  const outcomes = ['Passed', 'Failed', 'Not exercised', 'Unavailable'].map(textContent => ({
    textContent, dataset: { evidenceAvailableUntil: expiresAt },
  }));
  const routine = { textContent: 'Retained qualification:', dataset: { routineAvailableUntil: expiresAt } };
  const expiry = { textContent: 'Retained', dataset: { evidenceExpiry: expiresAt } };
  const root = { querySelectorAll: selector => ({
    '[data-evidence-available-until]': outcomes,
    '[data-routine-available-until]': [routine],
    '[data-evidence-expiry]': [expiry],
  })[selector] };
  refreshEvidence(root, Date.parse(expiresAt) - 1);
  assert.deepEqual(outcomes.map(item => item.textContent), ['Passed', 'Failed', 'Not exercised', 'Unavailable']);
  refreshEvidence(root, Date.parse(expiresAt));
  assert.deepEqual(outcomes.map(item => item.textContent), Array(4).fill('Unavailable'));
  assert.match(routine.textContent, /Unavailable.*expired.*Historical/);
  refreshEvidence(root, Date.parse(expiresAt) + 1000);
  assert.deepEqual(outcomes.map(item => item.textContent), Array(4).fill('Unavailable'));
});

test('built-output checker accepts unavailable release identity while preserving source evidence', (t) => {
  const release = fixtureRecord({ id: 501, kind: 'release', outcome: 'unavailable' });
  release.report.release = null;
  for (const architecture of release.report.architectures) {
    architecture.asset = null;
    architecture.execution = 'not exercised';
    architecture.distribution = {
      outcome: 'unavailable',
      checks: architecture.distribution.checks.map(({ id }) => ({
        id,
        outcome: ['version-agreement', 'installation-agreement'].includes(id) ? 'not exercised' : 'unavailable',
      })),
    };
  }
  validateQualificationReport(release.report);

  const source = fixtureRecord({ id: 502, kind: 'source', outcome: 'passed' });
  validateQualificationReport(source.report);
  const facts = buildEvidence({
    records: [release, source],
    websiteCommit: SHA,
    websiteRun: { id: 503, attempt: 1 },
    now: NOW,
  });
  const evidenceLinks = facts.groups.map(({ newest }) =>
    `<a href="${newest.evidence.runUrl}">${newest.evidence.artifactUrl}</a>`).join('');
  const releaseItem = facts.groups.find(group => group.kind === 'release' && group.architecture === 'amd64').newest;
  const outcomeLabel = value => value === 'not exercised'
    ? 'Not exercised'
    : value.charAt(0).toUpperCase() + value.slice(1);
  const outcomes = [
    ['distribution', 'Distribution'],
    ['credentialFreeCli', 'Credential-free CLI'],
    ['localFleet', 'Owned fleet restored'],
    ['connectedConsumer', 'Connected consumer'],
  ];
  const summary = `<section data-compatibility-summary><h4>Release evidence unavailable</h4>
    <p>Publication date unavailable</p><ul>${outcomes
      .map(([key, label]) => `<li data-compatibility-outcome="${key}">${label}<strong>${outcomeLabel(releaseItem[key].outcome)}</strong></li>`).join('')}
    </ul></section>`;
  const home = `<aside data-compatibility data-website-source="${facts.websiteCommit}">${summary}
    ${evidenceLinks}<details data-compatibility-details></details></aside>`;
  const fixtureRoot = mkdtempSync(join(tmpdir(), 'tunneltend-compatibility-output-'));
  t.after(() => rmSync(fixtureRoot, { recursive: true, force: true }));
  mkdirSync(join(fixtureRoot, 'artifacts', 'site'), { recursive: true });
  mkdirSync(join(fixtureRoot, 'artifacts', 'compatibility'), { recursive: true });
  writeFileSync(join(fixtureRoot, 'artifacts', 'site', 'index.html'), home);
  writeFileSync(join(fixtureRoot, 'artifacts', 'compatibility', 'facts.json'), JSON.stringify(facts));

  const result = spawnSync(process.execPath, [checker], {
    cwd: fixtureRoot,
    encoding: 'utf8',
    windowsHide: true,
  });

  assert.equal(result.status, 0, result.stderr || result.error?.message || result.stdout);
  assert.match(result.stdout, /preserves its visible summary/);
});
