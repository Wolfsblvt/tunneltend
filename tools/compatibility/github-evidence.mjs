// SPDX-License-Identifier: AGPL-3.0-only
// Only metadata crosses from the executable runner to the website runner. Nothing is extracted.
import { createHash } from 'node:crypto';
import { inflateRawSync, crc32 } from 'node:zlib';
import { HISTORY_ARTIFACT, validateIdentityHistory } from './evidence-model.mjs';

export const REPOSITORY = 'Wolfsblvt/tunneltend';
export const WORKFLOW_PATH = '.github/workflows/upstream-compatibility.yml';
export const ARTIFACT_NAMES = ['client-qualification-source', 'client-qualification-release'];
export const REPORT_FILE = 'report.json';
const MAX_REPORT_BYTES = 256 * 1024;
const MAX_ARCHIVE_BYTES = 512 * 1024;
const MAX_ARTIFACT_PAGES = 10;

/** Read exactly one regular JSON entry from a small ZIP, without trusting or writing paths. */
export function readReportArchive(bytes, digest) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 22 || bytes.length > MAX_ARCHIVE_BYTES) throw new Error('archive-size');
  if (!/^sha256:[a-f0-9]{64}$/.test(digest ?? '') || `sha256:${createHash('sha256').update(bytes).digest('hex')}` !== digest) throw new Error('archive-digest');
  const end = bytes.length - 22;
  if (bytes.readUInt32LE(end) !== 0x06054b50 || bytes.readUInt16LE(end + 20) !== 0
    || bytes.readUInt16LE(end + 4) !== 0 || bytes.readUInt16LE(end + 6) !== 0
    || bytes.readUInt16LE(end + 8) !== 1 || bytes.readUInt16LE(end + 10) !== 1) throw new Error('archive-directory');
  const offset = bytes.readUInt32LE(end + 16);
  if (offset + 46 > end || bytes.readUInt32LE(offset) !== 0x02014b50
    || offset + bytes.readUInt32LE(end + 12) !== end) throw new Error('archive-directory');
  const flags = bytes.readUInt16LE(offset + 8);
  const method = bytes.readUInt16LE(offset + 10);
  const compressedSize = bytes.readUInt32LE(offset + 20);
  const size = bytes.readUInt32LE(offset + 24);
  const nameLength = bytes.readUInt16LE(offset + 28);
  const extraLength = bytes.readUInt16LE(offset + 30);
  const commentLength = bytes.readUInt16LE(offset + 32);
  const attributes = bytes.readUInt32LE(offset + 38);
  const unixType = (attributes >>> 16) & 0xf000;
  if (size > MAX_REPORT_BYTES || ![0, 8].includes(method) || (flags & ~0x0808) !== 0
    || ![0, 0x8000].includes(unixType) || (attributes & 0x10) !== 0
    || bytes.readUInt16LE(offset + 34) !== 0 || bytes.readUInt32LE(offset + 42) !== 0
    || offset + 46 + nameLength + extraLength + commentLength !== end
    || bytes.subarray(offset + 46, offset + 46 + nameLength).toString('utf8') !== REPORT_FILE) throw new Error('archive-entry');
  if (bytes.readUInt32LE(0) !== 0x04034b50 || bytes.readUInt16LE(6) !== flags || bytes.readUInt16LE(8) !== method) throw new Error('archive-header');
  const localNameLength = bytes.readUInt16LE(26);
  const dataStart = 30 + localNameLength + bytes.readUInt16LE(28);
  if (bytes.subarray(30, 30 + localNameLength).toString('utf8') !== REPORT_FILE || dataStart + compressedSize > offset) throw new Error('archive-header');
  const compressed = bytes.subarray(dataStart, dataStart + compressedSize);
  const payloadEnd = dataStart + compressedSize;
  if ((flags & 8) === 0) {
    if (payloadEnd !== offset || bytes.readUInt32LE(14) !== bytes.readUInt32LE(offset + 16)
      || bytes.readUInt32LE(18) !== compressedSize || bytes.readUInt32LE(22) !== size) throw new Error('archive-local-content');
  } else {
    const descriptor = offset - payloadEnd;
    const start = descriptor === 16 && bytes.readUInt32LE(payloadEnd) === 0x08074b50 ? payloadEnd + 4 : payloadEnd;
    if (![12, 16].includes(descriptor) || (descriptor === 16 && start === payloadEnd)
      || bytes.readUInt32LE(start) !== bytes.readUInt32LE(offset + 16)
      || bytes.readUInt32LE(start + 4) !== compressedSize || bytes.readUInt32LE(start + 8) !== size) throw new Error('archive-descriptor');
  }
  const payload = method === 0 ? compressed : inflateRawSync(compressed, { maxOutputLength: MAX_REPORT_BYTES });
  if (payload.length !== size || crc32(payload) !== bytes.readUInt32LE(offset + 16)) throw new Error('archive-content');
  const json = new TextDecoder('utf-8', { fatal: true }).decode(payload);
  return JSON.parse(json);
}

/** Provider-issued provenance, independent of all fields supplied by the report. */
export function trustedRun(run, repository, workflow, path = WORKFLOW_PATH) {
  return run?.repository?.id === repository.id && run?.head_repository?.id === repository.id
    && run?.repository?.full_name === REPOSITORY && run?.head_repository?.full_name === REPOSITORY
    && run?.workflow_id === workflow.id && run?.path === path && run?.head_branch === repository.default_branch
    && repository.default_branch === 'main' && (path === WORKFLOW_PATH ? ['schedule', 'workflow_dispatch', 'push'] : ['workflow_dispatch', 'push', 'workflow_run']).includes(run?.event)
    && run?.status === 'completed' && ['success', 'failure'].includes(run?.conclusion)
    && /^[a-f0-9]{40}$/.test(run?.head_sha ?? '') && Number.isSafeInteger(run?.id) && Number.isSafeInteger(run?.run_attempt);
}

/** A native GitHub REST reader. Tokens go only to api.github.com; downloaded bytes are bounded. */
export function githubReader(token, fetcher = fetch) {
  const headers = { Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2026-03-10' };
  if (token) headers.Authorization = `Bearer ${token}`;
  async function request(path) {
    const response = await fetcher(`https://api.github.com/repos/${REPOSITORY}${path ? `/${path}` : ''}`, { headers, redirect: 'manual', signal: AbortSignal.timeout(30_000) });
    if (!response.ok) throw new Error(`github-api-${response.status}`);
    return response.json();
  }
  return {
    json: request,
    async archive(id) {
      const response = await fetcher(`https://api.github.com/repos/${REPOSITORY}/actions/artifacts/${id}/zip`, { headers, redirect: 'manual', signal: AbortSignal.timeout(30_000) });
      if (response.status !== 302) throw new Error(`github-download-${response.status}`);
      const url = new URL(response.headers.get('location'));
      if (url.protocol !== 'https:' || url.username || url.password) throw new Error('github-download-location');
      // The signed storage location is issued by GitHub, never by artifact content. Do not forward authorization.
      const download = await fetcher(url, { redirect: 'error', signal: AbortSignal.timeout(30_000) });
      if (!download.ok || Number(download.headers.get('content-length')) > MAX_ARCHIVE_BYTES) throw new Error('github-download-size');
      const chunks = [];
      let length = 0;
      for await (const chunk of download.body) {
        length += chunk.length;
        if (length > MAX_ARCHIVE_BYTES) throw new Error('github-download-size');
        chunks.push(chunk);
      }
      return Buffer.concat(chunks);
    },
  };
}

/** Resolve retained reports, preserving diagnostics without letting an outage stop website delivery.
 * validateReport returns the exact schema-checked report or throws; its implementation is shared with the producer.
 */
export async function retainedReports({ reader, validateReport, now = new Date() }) {
  const records = [];
  const histories = [];
  const issues = new Set();
  let historyWritable = true;
  try {
    const repository = await reader.json('');
    const workflow = await reader.json('actions/workflows/upstream-compatibility.yml');
    const websiteWorkflow = await reader.json('actions/workflows/website.yml');
    const runs = new Map();
    const attempts = new Map();
    const attemptJobs = new Map();
    const artifacts = [];
    for (const name of [...ARTIFACT_NAMES, HISTORY_ARTIFACT]) {
      for (let page = 1; page <= MAX_ARTIFACT_PAGES; page++) {
        const result = await reader.json(`actions/artifacts?name=${name}&per_page=100&page=${page}`);
        artifacts.push(...result.artifacts.filter(artifact => artifact.name === name));
        if (result.artifacts.length < 100) break;
        if (page === MAX_ARTIFACT_PAGES) {
          issues.add('collection-incomplete');
          historyWritable = false;
        }
      }
    }
    artifacts.sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at) || b.id - a.id);
    // Read every retained snapshot in the bounded collection: even a valid newer snapshot may be incomplete.
    const ordered = [...artifacts.filter(artifact => artifact.name === HISTORY_ARTIFACT), ...artifacts.filter(artifact => artifact.name !== HISTORY_ARTIFACT)];
    for (const artifact of ordered) {
        const isHistory = artifact.name === HISTORY_ARTIFACT;
        if (artifact.workflow_run?.head_branch && artifact.workflow_run.head_branch !== repository.default_branch) continue;
        if (artifact.expired || !(Date.parse(artifact.expires_at) > now.getTime())) { issues.add('expired'); continue; }
        try {
          if (!Number.isSafeInteger(artifact.id) || !Number.isSafeInteger(artifact.workflow_run?.id)
            || artifact.size_in_bytes > MAX_ARCHIVE_BYTES) throw new Error('artifact-metadata');
          const runId = artifact.workflow_run.id;
          if (!runs.has(runId)) runs.set(runId, await reader.json(`actions/runs/${runId}`));
          const currentRun = runs.get(runId);
          const path = isHistory ? '.github/workflows/website.yml' : WORKFLOW_PATH;
          const expectedWorkflow = isHistory ? websiteWorkflow : workflow;
          if (!trustedRun(currentRun, repository, expectedWorkflow, path)
            || artifact.workflow_run.head_sha !== currentRun.head_sha) throw new Error('artifact-provenance');
          if (Date.parse(artifact.expires_at) - Date.parse(artifact.created_at) <= 48 * 3_600_000) issues.add('retention-under-48-hours');
          const payload = readReportArchive(await reader.archive(artifact.id), artifact.digest);
          const attempt = payload?.run?.attempt;
          if (!Number.isSafeInteger(attempt) || attempt < 1 || attempt > currentRun.run_attempt) throw new Error('artifact-attempt');
          const attemptKey = `${runId}/${attempt}`;
          if (!attempts.has(attemptKey)) attempts.set(attemptKey, attempt === currentRun.run_attempt ? currentRun : await reader.json(`actions/runs/${runId}/attempts/${attempt}`));
          const run = attempts.get(attemptKey);
          if (!trustedRun(run, repository, expectedWorkflow, path) || run.run_attempt !== attempt || run.head_sha !== currentRun.head_sha) throw new Error('artifact-attempt');
          if (isHistory) {
            const history = validateIdentityHistory(payload);
            // Website events may have queued before main moved; the clean checkout records the SHA actually built.
            // Verify that commit is accepted main ancestry rather than equating it with the trigger's head_sha.
            const comparison = await reader.json(`compare/${history.sourceCommit}...main`);
            if (!['ahead', 'identical'].includes(comparison.status) || history.run.id !== run.id || history.run.attempt !== run.run_attempt
              || Date.parse(history.generatedAt) > Date.parse(artifact.created_at)) throw new Error('history-provenance');
            histories.push(history);
            continue;
          }
          const report = validateReport(payload);
          if (artifact.name !== `client-qualification-${report.package.kind}` || report.run.id !== String(run.id)
            || report.run.attempt !== run.run_attempt || report.source.commit !== run.head_sha
            || report.source.repository !== REPOSITORY || report.run.workflow !== 'upstream-compatibility.yml'
            || report.run.artifact !== artifact.name || Date.parse(report.checkedAt) > Date.parse(artifact.created_at)
            || Date.parse(report.observedAt) > Date.parse(report.checkedAt)) throw new Error('report-provenance');
          if (!attemptJobs.has(attemptKey)) attemptJobs.set(attemptKey, await reader.json(`actions/runs/${runId}/attempts/${attempt}/jobs?per_page=100`));
          const job = attemptJobs.get(attemptKey).jobs.find(job => job.name === `Qualify Windows client (${report.package.kind})`);
          if (!job || job.run_attempt !== attempt || job.status !== 'completed' || !['success', 'failure'].includes(job.conclusion)
            || !(Date.parse(job.started_at) <= Date.parse(artifact.created_at) && Date.parse(artifact.created_at) <= Date.parse(job.completed_at))) throw new Error('report-job');
          records.push({ report, run, artifact, qualificationConclusion: job.conclusion });
        } catch {
          issues.add(isHistory ? 'identity-history-invalid-or-inaccessible' : 'invalid-or-inaccessible');
          if (isHistory) historyWritable = false;
        }
    }
  } catch { issues.add('provider-unavailable'); historyWritable = false; }
  records.sort((a, b) => Date.parse(a.artifact.created_at) - Date.parse(b.artifact.created_at)
    || Date.parse(a.report.checkedAt) - Date.parse(b.report.checkedAt) || a.run.run_attempt - b.run.run_attempt);
  if (!records.length && !issues.size) issues.add('missing-or-expired');
  histories.sort((a, b) => Date.parse(a.generatedAt) - Date.parse(b.generatedAt));
  if (!histories.length || histories.some(history => history.continuity === 'unknown')) issues.add('identity-continuity-unknown');
  return { records, histories, issues: [...issues], historyWritable };
}
