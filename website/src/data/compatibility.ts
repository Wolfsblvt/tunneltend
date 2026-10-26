// SPDX-License-Identifier: AGPL-3.0-only
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

type Outcome = 'passed' | 'failed' | 'not exercised' | 'unavailable';
interface Boundary { outcome: Outcome; checks: { id: string; outcome: Outcome }[] }
interface Asset { id: number; name: string; sha256: string | null }
interface HistoricalAsset extends Asset { observedAt: string; runId: number; artifactId: number }
interface Observation {
  package: { kind: 'source' | 'release'; version: string | null; sha256: string | null; sourceCommit: string | null };
  release: { id: number; tag: string; publishedAt: string } | null;
  asset: Asset | null;
  architecture: 'amd64' | 'arm64'; execution: 'native' | 'not exercised';
  distribution: Boundary; credentialFreeCli: Boundary; localFleet: Boundary; connectedConsumer: Boundary;
  observedAt: string; checkedAt: string;
  source: { repository: string; commit: string; harnessSha256: string; adapterSha256: string | null; updaterSha256: string | null };
  evidence: { runId: number; attempt: number; runUrl: string; artifactId: number; artifactUrl: string; expiresAt: string; digest: string; conclusion: string; qualificationConclusion: string };
}
interface CompatibilityFacts {
  builtAt: string | null; websiteCommit: string | null; historyAvailable: boolean; issues: string[];
  groups: { kind: string; architecture: string; newest: Observation; qualified: Observation | null }[];
  identityHistory: { continuity: 'retained' | 'unknown'; identities: { tag: string; architecture: string; baseline: HistoricalAsset; changes: HistoricalAsset[]; lastObservedAt: string }[] };
}

/** Input assembled by the clean build controller; downloaded executable artifacts are never imported. */
export function loadCompatibility(): CompatibilityFacts {
  // Astro bundles this module; import.meta.url would then name an emitted chunk, not the source directory.
  const path = resolve(process.cwd(), 'artifacts/compatibility/facts.json');
  if (!existsSync(path)) return { builtAt: null, websiteCommit: null, groups: [], issues: ['not-resolved'], historyAvailable: false, identityHistory: { continuity: 'unknown', identities: [] } };
  return JSON.parse(readFileSync(path, 'utf8')) as CompatibilityFacts;
}
