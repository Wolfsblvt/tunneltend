// SPDX-License-Identifier: AGPL-3.0-only
export const FRESHNESS_HOURS = 48;
export const HISTORY_ARTIFACT = 'client-qualification-history';

const hash = /^[a-f0-9]{64}$/;
const utc = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z$/;
const exact = (object, keys) => object && typeof object === 'object' && !Array.isArray(object)
  && Object.keys(object).length === keys.length && keys.every(key => Object.hasOwn(object, key));

/** Only release identities survive beyond their original report; never copy an expired pass. */
export function validateIdentityHistory(value) {
  // Legacy snapshots preserve identities but never prove continuity that their schema could not express.
  if (value?.schemaVersion === 1 && exact(value, ['schemaVersion', 'generatedAt', 'sourceCommit', 'run', 'identities'])) {
    value = { ...value, schemaVersion: 2, continuity: 'unknown' };
  }
  if (!exact(value, ['schemaVersion', 'continuity', 'generatedAt', 'sourceCommit', 'run', 'identities']) || value.schemaVersion !== 2
    || !['retained', 'unknown'].includes(value.continuity)
    || !utc.test(value.generatedAt) || !Number.isFinite(Date.parse(value.generatedAt)) || !/^[a-f0-9]{40}$/.test(value.sourceCommit)
    || !exact(value.run, ['id', 'attempt']) || !Number.isSafeInteger(value.run.id) || value.run.id < 1
    || !Number.isSafeInteger(value.run.attempt) || value.run.attempt < 1 || !Array.isArray(value.identities)) throw new Error('identity-history');
  const keys = new Set();
  for (const item of value.identities) {
    if (!exact(item, ['tag', 'architecture', 'baseline', 'changes', 'lastObservedAt'])
      || !/^v?\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$/.test(item.tag) || item.tag.length > 100
      || !['amd64', 'arm64'].includes(item.architecture) || !validAsset(item.baseline)
      || !Array.isArray(item.changes) || !item.changes.every(asset => validAsset(asset) && asset.sha256 !== item.baseline.sha256)
      || new Set(item.changes.map(asset => asset.sha256)).size !== item.changes.length
      || !utc.test(item.lastObservedAt)
      || ![item.baseline, ...item.changes].every(asset => Date.parse(asset.observedAt) <= Date.parse(item.lastObservedAt))
      || Date.parse(item.lastObservedAt) > Date.parse(value.generatedAt)) throw new Error('identity-history-item');
    const key = `${item.tag}/${item.architecture}`;
    if (keys.has(key)) throw new Error('identity-history-duplicate');
    keys.add(key);
  }
  return value;
}

function validAsset(asset) {
  return exact(asset, ['id', 'name', 'sha256', 'observedAt', 'runId', 'artifactId']) && Number.isSafeInteger(asset.id) && asset.id > 0
    && /^[a-zA-Z0-9._-]{1,200}$/.test(asset.name) && hash.test(asset.sha256) && utc.test(asset.observedAt)
    && Number.isFinite(Date.parse(asset.observedAt)) && Number.isSafeInteger(asset.runId) && asset.runId > 0
    && Number.isSafeInteger(asset.artifactId) && asset.artifactId > 0;
}

/** Fold observations in provider order. A repeat or reversion cannot close an identity change. */
export function buildEvidence({ records, issues = [], histories = [], historyWritable = true, websiteCommit, websiteRun, now = new Date() }) {
  const identities = new Map();
  const continuity = historyWritable && histories.length > 0 && histories.every(history => history.continuity === 'retained')
    ? 'retained' : 'unknown';
  // Merge retained snapshots instead of allowing a failed or concurrent later build to erase an open change.
  for (const history of histories) {
    for (const item of history.identities) mergeIdentity(item);
  }
  const observations = [];
  for (const record of records) {
    const { report, run, artifact } = record;
    for (const architecture of report.architectures) {
      const tag = report.release?.tag;
      const digest = architecture.asset?.sha256;
      if (tag && digest) {
        mergeIdentity({ tag, architecture: architecture.architecture,
          baseline: { ...architecture.asset, observedAt: report.observedAt, runId: run.id, artifactId: artifact.id },
          changes: [], lastObservedAt: report.observedAt });
      }
      observations.push({
        package: report.package, release: report.release, ...architecture,
        observedAt: report.observedAt, checkedAt: report.checkedAt, source: report.source,
        evidence: { runId: run.id, attempt: run.run_attempt, runUrl: `https://github.com/Wolfsblvt/tunneltend/actions/runs/${run.id}/attempts/${run.run_attempt}`,
          artifactId: artifact.id, artifactUrl: `https://github.com/Wolfsblvt/tunneltend/actions/runs/${run.id}/artifacts/${artifact.id}`,
          expiresAt: artifact.expires_at, digest: artifact.digest, conclusion: run.conclusion,
          qualificationConclusion: record.qualificationConclusion ?? run.conclusion },
      });
    }
  }
  const groups = [];
  for (const kind of ['release', 'source']) {
    for (const architecture of ['amd64', 'arm64']) {
      const items = observations.filter(item => item.package.kind === kind && item.architecture === architecture);
      const newest = items.at(-1) ?? null;
      const qualified = continuity === 'retained' ? items.findLast(item => item.evidence.qualificationConclusion === 'success' && item.distribution.outcome === 'passed'
        && (item.execution === 'native' ? item.credentialFreeCli.outcome === 'passed' : item.credentialFreeCli.outcome === 'not exercised')
        && item.asset?.sha256 === identities.get(`${item.release?.tag}/${architecture}`)?.baseline.sha256) ?? null : null;
      if (newest) groups.push({ kind, architecture, newest, qualified });
    }
  }
  return {
    schemaVersion: 1, builtAt: now.toISOString(), websiteCommit, groups, issues,
    identityHistory: { schemaVersion: 2, continuity, generatedAt: now.toISOString(), sourceCommit: websiteCommit, run: websiteRun,
      // Keep the currently observed baseline and open changes, rather than making a version registry.
      identities: [...identities.values()].filter(item => item.changes.length > 0 ||
        ![...identities.values()].some(other => other.architecture === item.architecture && Date.parse(other.lastObservedAt) > Date.parse(item.lastObservedAt))) },
    historyAvailable: continuity === 'retained',
  };

  function mergeIdentity(incoming) {
    const key = `${incoming.tag}/${incoming.architecture}`;
    const current = identities.get(key);
    if (!current) { identities.set(key, structuredClone(incoming)); return; }
    const earlier = Date.parse(incoming.baseline.observedAt) < Date.parse(current.baseline.observedAt);
    const baseline = earlier ? incoming.baseline : current.baseline;
    const assets = new Map();
    for (const asset of [current.baseline, ...current.changes, incoming.baseline, ...incoming.changes]) {
      const existing = assets.get(asset.sha256);
      if (!existing || Date.parse(asset.observedAt) < Date.parse(existing.observedAt)) assets.set(asset.sha256, asset);
    }
    assets.delete(baseline.sha256);
    current.baseline = baseline;
    current.changes = [...assets.values()];
    if (Date.parse(incoming.lastObservedAt) > Date.parse(current.lastObservedAt)) current.lastObservedAt = incoming.lastObservedAt;
  }
}

/** Relative age is disclosure only. No installation or publication decision consumes it. */
export function evidenceAge(timestamp, now = new Date()) {
  const hours = Math.max(0, Math.floor((now.getTime() - Date.parse(timestamp)) / 3_600_000));
  return { hours, stale: hours >= FRESHNESS_HOURS };
}
