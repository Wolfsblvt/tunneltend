// SPDX-License-Identifier: AGPL-3.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { readReportArchive, trustedRun, retainedReports, githubReader } from './github-evidence.mjs';
import { buildEvidence, validateIdentityHistory, evidenceAge } from './evidence-model.mjs';
import { fixtureRecord, reportZip, NOW, SHA } from './evidence-fixtures.mjs';
import { validateQualificationReport } from '../../scripts/lib/client-qualification.mjs';

const assemble = (records, histories = []) => buildEvidence({ records, histories, websiteCommit: SHA, websiteRun: { id: 99, attempt: 1 }, now: NOW });
// Explicitly retained prehistory for scenarios testing routine qualification, not bootstrap/loss.
const retained = () => ({ ...assemble([]).identityHistory, continuity: 'retained' });
test('single JSON metadata is decoded without extracting artifact paths', () => {
  const record = fixtureRecord();
  for (const method of [0, 8]) {
    const { bytes, digest } = reportZip(record.report, { method });
    assert.deepEqual(readReportArchive(bytes, digest), record.report);
  }
});
test('traversal, links, extra entries, encryption, corrupt digest, oversized and invalid UTF-8 are refused', () => {
  for (const options of [{ name: '../report.json' }, { mode: 0xa000 }, { count: 2 }, { flags: 1 },
    { payload: Buffer.alloc(256 * 1024 + 1) }, { payload: Buffer.from([0xff]) }]) {
    const { bytes, digest } = reportZip({}, options);
    assert.throws(() => readReportArchive(bytes, digest));
  }
  const { bytes } = reportZip({});
  assert.throws(() => readReportArchive(bytes, 'sha256:' + '0'.repeat(64)), /archive-digest/);
});
test('same-repository default-branch workflow identity and event are required', () => {
  const run = fixtureRecord().run;
  const repository = { id: 1, default_branch: 'main' };
  assert.equal(trustedRun(run, repository, { id: 123 }), true);
  for (const mutation of [{ head_branch: 'feature' }, { event: 'pull_request' }, { workflow_id: 999 },
    { head_repository: { id: 2, full_name: 'attacker/tunneltend' } }, { path: '.github/workflows/untrusted.yml' }]) {
    assert.equal(trustedRun({ ...run, ...mutation }, repository, { id: 123 }), false);
  }
});
test('same-tag mutation remains open on repeat and across package/contract changes', () => {
  const first = fixtureRecord({ id: 1, time: '2026-10-24T10:00:00Z' });
  const changed = fixtureRecord({ id: 2, digest: '9'.repeat(64), time: '2026-10-25T10:00:00Z' });
  const initial = assemble([first, changed], [retained()]);
  assert.equal(initial.groups[0].qualified.evidence.runId, 1);
  const repeat = fixtureRecord({ id: 3, digest: '9'.repeat(64), time: '2026-10-26T10:00:00Z' });
  repeat.report.package.version = '1.0.2'; repeat.report.contractVersion = 2;
  const next = assemble([repeat], [validateIdentityHistory(initial.identityHistory)]);
  assert.equal(next.groups[0].newest.evidence.runId, 3);
  assert.equal(next.groups[0].qualified, null); // expired predecessor proof is not renewed by history
  assert.equal(next.identityHistory.identities[0].changes.length, 1);
  assert.equal(next.identityHistory.identities[0].changes[0].runId, 2);
  assert.equal(next.identityHistory.identities[0].baseline.sha256, first.report.architectures[0].asset.sha256);
});
test('new tag resumes qualification, failed latest preserves previous pass and separate boundaries', () => {
  const pass = fixtureRecord({ id: 1, time: '2026-10-24T10:00:00Z' });
  const failure = fixtureRecord({ id: 2, tag: 'v0.0.19', outcome: 'failed', time: '2026-10-25T10:00:00Z' });
  const facts = assemble([pass, failure], [retained()]);
  assert.equal(facts.groups[0].qualified.release.tag, 'v0.0.18');
  assert.equal(facts.groups[0].newest.distribution.outcome, 'failed');
  assert.equal(facts.groups[0].newest.connectedConsumer.outcome, 'not exercised');
  assert.equal(assemble([pass, failure, fixtureRecord({ id: 3, tag: 'v0.0.19' })], [retained()]).groups[0].qualified.release.tag, 'v0.0.19');
  assert.equal(assemble([pass]).historyAvailable, false); // bootstrap does not claim earlier identity history
});
test('48 hours changes disclosure only; unknown fields and fabricated history are refused', () => {
  assert.equal(evidenceAge('2026-10-24T12:00:00Z', NOW).stale, true);
  assert.equal(evidenceAge('2026-10-24T12:01:00Z', NOW).stale, false);
  const history = assemble([fixtureRecord()]).identityHistory;
  assert.throws(() => validateIdentityHistory({ ...history, executable: 'do not run' }));
  assert.throws(() => validateIdentityHistory({ ...history, identities: [...history.identities, ...history.identities] }));
});

function fakeReader(records, { expired = false, invalid = false, outage = false } = {}) {
  const zipped = records.map(record => reportZip(record.report));
  return {
    async json(path) {
      if (outage) throw new Error('offline');
      if (!path) return { id: 1, default_branch: 'main' };
      if (path.includes('workflows/')) return { id: 123 };
      if (path.includes('artifacts?')) return { artifacts: records.map((record, i) => ({ ...record.artifact, expired,
        size_in_bytes: zipped[i].bytes.length, digest: invalid ? 'sha256:' + '0'.repeat(64) : zipped[i].digest })) };
      if (path.includes('/jobs?')) return { jobs: records.map(record => ({ name: `Qualify Windows client (${record.report.package.kind})`, run_attempt: record.run.run_attempt,
        status: 'completed', conclusion: record.run.conclusion, started_at: record.run.created_at, completed_at: '2026-10-26T11:00:00Z' })) };
      if (path.startsWith('actions/runs/')) return records.find(record => path === `actions/runs/${record.run.id}`).run;
      throw new Error(`unexpected ${path}`);
    },
    async archive(id) { return zipped[records.findIndex(record => record.artifact.id === id)].bytes; },
  };
}
test('provider outage, expiry, invalid archive and report/run mismatch remain explicit unavailable states', async () => {
  for (const options of [{ outage: true }, { expired: true }, { invalid: true }]) {
    const result = await retainedReports({ reader: fakeReader([fixtureRecord()], options), validateReport: value => value, now: NOW });
    assert.equal(result.records.length, 0); assert.ok(result.issues.length > 0);
  }
  const record = fixtureRecord(); record.report.run.id = 999;
  assert.equal((await retainedReports({ reader: fakeReader([record]), validateReport: value => value, now: NOW })).records.length, 0);
});
test('native provider envelope is attached to validated data, never taken from report URLs', async () => {
  const record = fixtureRecord();
  const result = await retainedReports({ reader: fakeReader([record]), validateReport: validateQualificationReport, now: NOW });
  assert.equal(result.records.length, 1);
  assert.equal(assemble(result.records).groups[0].newest.evidence.artifactId, record.artifact.id);
});
test('download authorization never follows the signed storage redirect', async () => {
  const calls = [];
  const reader = githubReader('test-read-token', async (url, options) => {
    calls.push({ url: String(url), options });
    if (calls.length === 1) return new Response(null, { status: 302, headers: { location: 'https://storage.example/report' } });
    return new Response(Buffer.from('metadata'));
  });
  await reader.archive(10);
  assert.equal(calls[0].options.headers.Authorization, 'Bearer test-read-token');
  assert.equal(calls[1].options.headers, undefined);
  assert.equal(calls[1].options.redirect, 'error');
});

test('native history survives expired raw proof, accepted build source differs from queued event, and later repeats', async () => {
  const first = fixtureRecord({ id: 1, time: '2026-10-23T10:00:00Z' });
  const changed = fixtureRecord({ id: 2, digest: '9'.repeat(64), time: '2026-10-24T10:00:00Z' });
  const history = assemble([first, changed]).identityHistory;
  const zipped = reportZip(history);
  const providerRun = { ...fixtureRecord({ id: 99 }).run, path: '.github/workflows/website.yml', workflow_id: 124, event: 'workflow_run', head_sha: '1'.repeat(40) };
  const artifact = { ...first.artifact, id: 999, name: 'client-qualification-history', digest: zipped.digest,
    created_at: '2026-10-26T12:01:00Z', workflow_run: { id: 99, head_sha: providerRun.head_sha } };
  const reader = {
    async json(path) {
      if (!path) return { id: 1, default_branch: 'main' };
      if (path.includes('workflows/website')) return { id: 124 };
      if (path.includes('workflows/')) return { id: 123 };
      if (path.includes('artifacts?name=client-qualification-history')) return { artifacts: [artifact] };
      if (path.includes('artifacts?')) return { artifacts: [] };
      if (path.includes('actions/runs/')) return providerRun;
      if (path === `compare/${SHA}...main`) return { status: 'ahead' };
      throw new Error(`unexpected ${path}`);
    },
    async archive() { return zipped.bytes; },
  };
  const retained = await retainedReports({ reader, validateReport: validateQualificationReport, now: new Date('2026-10-26T12:02:00Z') });
  assert.equal(retained.histories.length, 1);
  assert.equal(retained.historyWritable, true);
  const facts = buildEvidence({ ...retained, websiteCommit: SHA, websiteRun: { id: 100, attempt: 1 }, now: NOW });
  assert.equal(facts.groups.length, 0); // history does not recreate an expired qualification
  assert.equal(facts.identityHistory.identities[0].changes[0].runId, 2);
  reader.json = async () => { throw new Error('offline'); };
  const outage = await retainedReports({ reader, validateReport: validateQualificationReport, now: NOW });
  assert.equal(outage.historyWritable, false); // ordinary site delivery continues without overwriting good history
  assert.equal(outage.records.length, 0);
});

test('a release-only rerun preserves successful source attempt1 and chooses later release evidence by time, not ID', async () => {
  const source = fixtureRecord({ id: 50, kind: 'source', time: '2026-10-24T10:00:00Z' });
  const failed = fixtureRecord({ id: 50, kind: 'release', outcome: 'unavailable', time: '2026-10-24T10:00:00Z' });
  const passed = fixtureRecord({ id: 50, kind: 'release', time: '2026-10-25T10:00:00Z' });
  source.artifact.id = 9001; failed.artifact.id = 9000; passed.artifact.id = 100;
  passed.report.run.attempt = 2;
  const records = [source, failed, passed];
  const zipped = new Map(records.map(record => [record.artifact.id, reportZip(record.report)]));
  const current = { ...passed.run, run_attempt: 2 };
  const reader = {
    async json(path) {
      if (!path) return { id: 1, default_branch: 'main' };
      if (path.includes('workflows/')) return { id: 123 };
      if (path.includes('artifacts?')) return { artifacts: records.map(record => ({ ...record.artifact, digest: zipped.get(record.artifact.id).digest })) };
      if (path === 'actions/runs/50') return current;
      if (path === 'actions/runs/50/attempts/1') return { ...source.run, conclusion: 'failure' };
      if (path.includes('/jobs?')) {
        const attempt = path.includes('/attempts/1/') ? 1 : 2;
        return { jobs: ['source', 'release'].map(kind => ({ name: `Qualify Windows client (${kind})`, run_attempt: attempt, status: 'completed',
          conclusion: attempt === 1 && kind === 'release' ? 'failure' : 'success', started_at: '2026-10-24T09:00:00Z', completed_at: '2026-10-26T11:00:00Z' })) };
      }
      throw new Error(`unexpected ${path}`);
    },
    async archive(id) { return zipped.get(id).bytes; },
  };
  const retained = await retainedReports({ reader, validateReport: validateQualificationReport, now: NOW });
  assert.equal(retained.records.length, 3);
  const facts = assemble(retained.records, [{ ...assemble([]).identityHistory, continuity: 'retained' }]);
  const release = facts.groups.find(group => group.kind === 'release' && group.architecture === 'amd64');
  const sourceGroup = facts.groups.find(group => group.kind === 'source' && group.architecture === 'amd64');
  assert.equal(release.newest.evidence.artifactId, 100);
  assert.equal(release.qualified.evidence.attempt, 2);
  assert.equal(sourceGroup.qualified.evidence.attempt, 1);
  assert.equal(sourceGroup.qualified.evidence.conclusion, 'failure');
  assert.equal(sourceGroup.qualified.evidence.qualificationConclusion, 'success');
  assert.equal(retained.records.find(record => record.artifact.id === 9000).qualificationConclusion, 'failure');
});

test('total history loss stays unknown through saved snapshots, repeated changed bytes and reversion', async () => {
  let histories = [];
  for (const [id, digest] of [[1, '8'], [2, '9'], [3, '9'], [4, '8']]) {
    const record = fixtureRecord({ id, digest: digest.repeat(64) });
    record.report.package.version = `1.0.${id}`;
    const lookup = await retainedReports({ reader: fakeReader([record]), validateReport: validateQualificationReport, now: NOW });
    const facts = buildEvidence({ ...lookup, histories, websiteCommit: SHA, websiteRun: { id: 99, attempt: 1 }, now: NOW });
    assert.equal(facts.identityHistory.continuity, 'unknown');
    assert.equal(facts.historyAvailable, false);
    assert.equal(facts.groups[0].qualified, null);
    assert.equal(facts.groups[0].newest.distribution.outcome, 'passed'); // real boundary proof stays separate
    histories = [validateIdentityHistory(JSON.parse(JSON.stringify(facts.identityHistory)))];
  }
  assert.equal(histories[0].identities[0].changes.length, 1);
  assert.equal(histories[0].identities[0].changes[0].runId, 2);
});

test('reader merges older open changes with newer incomplete snapshots before qualification', async () => {
  const first = fixtureRecord({ id: 1, time: '2026-10-24T10:00:00Z' });
  const changed = fixtureRecord({ id: 2, digest: '9'.repeat(64), time: '2026-10-25T10:00:00Z' });
  const old = assemble([first, changed], [retained()]).identityHistory;
  const newer = { ...assemble([changed], [retained()]).identityHistory, run: { id: 100, attempt: 1 } };
  const latest = fixtureRecord({ id: 3, digest: '9'.repeat(64) });
  latest.report.package.version = '1.0.2';
  const baseReader = fakeReader([latest]);
  const historyRecords = [old, newer].map((history, index) => {
    const zip = reportZip(history);
    const run = { ...latest.run, id: history.run.id, path: '.github/workflows/website.yml', event: 'workflow_run' };
    return { history, zip, run, artifact: { ...latest.artifact, id: 9990 + index,
      name: 'client-qualification-history', workflow_run: { id: run.id, head_sha: SHA }, digest: zip.digest,
      created_at: `2026-10-26T12:0${index + 1}:00Z` } };
  });
  const reader = {
    async json(path) {
      if (path.includes('artifacts?name=client-qualification-history')) return { artifacts: historyRecords.map(item => item.artifact) };
      if (path === `compare/${SHA}...main`) return { status: 'identical' };
      const item = historyRecords.find(item => path === `actions/runs/${item.run.id}`);
      return item ? item.run : baseReader.json(path);
    },
    async archive(id) { return historyRecords.find(item => item.artifact.id === id)?.zip.bytes ?? baseReader.archive(id); },
  };
  const lookup = await retainedReports({ reader, validateReport: validateQualificationReport, now: new Date('2026-10-26T12:03:00Z') });
  assert.equal(lookup.histories.length, 2);
  assert.equal(lookup.historyWritable, true);
  const facts = buildEvidence({ ...lookup, websiteCommit: SHA, websiteRun: { id: 101, attempt: 1 }, now: NOW });
  assert.equal(facts.identityHistory.identities[0].baseline.sha256, first.report.architectures[0].asset.sha256);
  assert.equal(facts.identityHistory.identities[0].changes[0].runId, 2);
  assert.equal(facts.groups[0].qualified, null); // latest incomplete snapshot's baseline is not authority
  const restored = assemble([first], [validateIdentityHistory(facts.identityHistory)]);
  assert.equal(restored.identityHistory.identities[0].changes.length, 1);
});

test('legacy and incomplete retrieval preserve known identities without inventing continuity', () => {
  const known = assemble([fixtureRecord(), fixtureRecord({ id: 11, digest: '9'.repeat(64) })], [retained()]).identityHistory;
  const { continuity, continuousSince, ...legacy } = known;
  const normalized = validateIdentityHistory({ ...legacy, schemaVersion: 1 });
  assert.equal(normalized.continuity, 'unknown');
  assert.equal(normalized.identities[0].changes.length, 1);
  const partial = buildEvidence({ records: [fixtureRecord()], histories: [known], historyWritable: false,
    websiteCommit: SHA, websiteRun: { id: 99, attempt: 1 }, now: NOW });
  assert.equal(partial.identityHistory.continuity, 'unknown');
  assert.equal(partial.groups[0].qualified, null);
});

test('after loss a genuinely newer release qualifies automatically without clearing unknown prehistory or open changes', () => {
  const old = fixtureRecord({ id: 1 });
  const mutation = fixtureRecord({ id: 2, digest: '9'.repeat(64) });
  const bootstrap = assemble([old, mutation]).identityHistory;
  const next = fixtureRecord({ id: 3, tag: 'v0.0.19', time: '2026-10-28T10:00:00Z' });
  next.report.release.publishedAt = '2026-10-27T10:00:00Z';
  const facts = buildEvidence({ records: [next], histories: [validateIdentityHistory(JSON.parse(JSON.stringify(bootstrap)))],
    websiteCommit: SHA, websiteRun: { id: 100, attempt: 1 }, now: new Date('2026-10-28T12:00:00Z') });
  assert.equal(facts.identityHistory.continuity, 'unknown');
  assert.equal(facts.historyAvailable, false);
  assert.equal(facts.groups[0].qualified.release.tag, 'v0.0.19');
  assert.equal(facts.identityHistory.identities.find(item => item.tag === 'v0.0.18').changes.length, 1);
  const repeat = buildEvidence({ records: [next], histories: [validateIdentityHistory(facts.identityHistory)],
    websiteCommit: SHA, websiteRun: { id: 101, attempt: 1 }, now: new Date('2026-10-29T12:00:00Z') });
  assert.equal(repeat.groups[0].qualified.release.tag, 'v0.0.19');
  assert.equal(repeat.identityHistory.continuousSince, bootstrap.continuousSince);
  const republished = fixtureRecord({ id: 4, time: '2026-10-28T10:00:00Z' });
  republished.report.release.publishedAt = next.report.release.publishedAt;
  const oldTag = buildEvidence({ records: [republished], histories: [bootstrap], websiteCommit: SHA,
    websiteRun: { id: 102, attempt: 1 }, now: new Date('2026-10-29T12:00:00Z') });
  assert.equal(oldTag.groups[0].qualified, null); // a later release record cannot launder a known pre-loss tag
});

test('bounded incomplete collection cannot upload a replacement history or imply continuity', async () => {
  let pages = 0;
  const reader = {
    async json(path) {
      if (!path) return { id: 1, default_branch: 'main' };
      if (path.includes('workflows/')) return { id: 123 };
      if (path.includes('artifacts?')) {
        assert.ok(Number(new URLSearchParams(path.split('?')[1]).get('page')) <= 10);
        pages++;
        return { artifacts: Array.from({ length: 100 }, () => ({ name: 'client-qualification-history',
          workflow_run: { head_branch: 'untrusted-branch' } })) };
      }
      throw new Error(`unexpected ${path}`);
    },
    async archive() { assert.fail('out-of-scope artifact downloaded'); },
  };
  const lookup = await retainedReports({ reader, validateReport: validateQualificationReport, now: NOW });
  assert.equal(pages, 30);
  assert.equal(lookup.historyWritable, false);
  assert.ok(lookup.issues.includes('collection-incomplete'));
  assert.equal(buildEvidence({ ...lookup, websiteCommit: SHA, websiteRun: { id: 99, attempt: 1 }, now: NOW }).identityHistory.continuity, 'unknown');
});
