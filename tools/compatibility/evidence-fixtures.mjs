// SPDX-License-Identifier: AGPL-3.0-only
// Synthetic metadata only; these values establish no official-client or connected-use result.
import { createHash } from 'node:crypto';
import { deflateRawSync, crc32 } from 'node:zlib';
export const SHA = 'a'.repeat(40);
export const NOW = new Date('2026-10-26T12:00:00Z');
export const boundary = (outcome = 'passed', ids = ['fixture-check']) => ({ outcome, checks: ids.map(id => ({ id, outcome })) });
export function fixtureRecord({ id = 10, digest = 'b'.repeat(64), kind = 'release', outcome = 'passed', tag = 'v0.0.18', time = '2026-10-26T10:00:00Z' } = {}) {
  return {
    report: {
      schemaVersion: 1, contractVersion: 1, observedAt: time, checkedAt: time,
      run: { id: String(id), attempt: 1, workflow: 'upstream-compatibility.yml', artifact: `client-qualification-${kind}` },
      source: { repository: 'Wolfsblvt/tunneltend', commit: SHA, harnessSha256: 'c'.repeat(64), adapterSha256: 'd'.repeat(64) },
      package: { kind, version: '1.0.1', sha256: 'e'.repeat(64), sourceCommit: kind === 'source' ? SHA : null },
      release: { id: 100, tag, publishedAt: '2026-10-23T00:00:00Z' },
      architectures: ['amd64', 'arm64'].map(architecture => ({ architecture, asset: { id: architecture === 'amd64' ? 200 : 201, name: `tunnel-client-windows-${architecture}.zip`, sha256: digest }, execution: architecture === 'amd64' ? 'native' : 'not exercised',
        distribution: boundary(outcome, ['package-acquisition', 'release-selection', 'asset-selection', 'published-digest', 'guarded-extraction', 'version-agreement', 'installation-agreement']),
        credentialFreeCli: boundary(architecture === 'amd64' ? outcome : 'not exercised', ['version', 'runtimes', 'runtimes-json', 'runtime-status', 'runtime-connect', 'runtime-stop', 'list-json', 'status-missing', 'stop-missing']),
        localFleet: boundary('not exercised', ['owned-fleet']), connectedConsumer: boundary('not exercised', ['connected-call']) })),
    },
    run: { id, run_attempt: 1, workflow_id: 123, path: '.github/workflows/upstream-compatibility.yml', event: 'schedule', status: 'completed',
      conclusion: outcome === 'passed' ? 'success' : 'failure', head_branch: 'main', head_sha: SHA, created_at: time,
      repository: { id: 1, full_name: 'Wolfsblvt/tunneltend' }, head_repository: { id: 1, full_name: 'Wolfsblvt/tunneltend' } },
    artifact: { id: id + 1000, name: `client-qualification-${kind}`, digest: 'sha256:' + 'f'.repeat(64), size_in_bytes: 1000, expired: false,
      created_at: time, expires_at: '2027-01-24T10:00:00Z', workflow_run: { id, head_sha: SHA } },
  };
}

export function reportZip(value, { name = 'report.json', mode = 0x8000, method = 8, flags = 0, count = 1, payload = Buffer.from(JSON.stringify(value)) } = {}) {
  const filename = Buffer.from(name);
  const data = method === 8 ? deflateRawSync(payload) : payload;
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50); local.writeUInt16LE(20, 4); local.writeUInt16LE(flags, 6); local.writeUInt16LE(method, 8);
  local.writeUInt32LE(crc32(payload), 14); local.writeUInt32LE(data.length, 18); local.writeUInt32LE(payload.length, 22); local.writeUInt16LE(filename.length, 26);
  const directory = Buffer.alloc(46);
  directory.writeUInt32LE(0x02014b50); directory.writeUInt16LE(0x0314, 4); directory.writeUInt16LE(20, 6); directory.writeUInt16LE(flags, 8);
  directory.writeUInt16LE(method, 10); directory.writeUInt32LE(crc32(payload), 16); directory.writeUInt32LE(data.length, 20);
  directory.writeUInt32LE(payload.length, 24); directory.writeUInt16LE(filename.length, 28); directory.writeUInt32LE((mode * 65536) >>> 0, 38);
  const offset = local.length + filename.length + data.length;
  const end = Buffer.alloc(22); end.writeUInt32LE(0x06054b50); end.writeUInt16LE(count, 8); end.writeUInt16LE(count, 10);
  end.writeUInt32LE(directory.length + filename.length, 12); end.writeUInt32LE(offset, 16);
  const bytes = Buffer.concat([local, filename, data, directory, filename, end]);
  return { bytes, digest: `sha256:${createHash('sha256').update(bytes).digest('hex')}` };
}
