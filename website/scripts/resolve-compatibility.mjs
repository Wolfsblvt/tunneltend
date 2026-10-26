// SPDX-License-Identifier: AGPL-3.0-only
import { mkdirSync, writeFileSync, appendFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { githubReader, retainedReports } from '../../tools/compatibility/github-evidence.mjs';
import { buildEvidence } from '../../tools/compatibility/evidence-model.mjs';
import { validateQualificationReport } from '../../scripts/lib/client-qualification.mjs';
import { execFileSync } from 'node:child_process';

const website = fileURLToPath(new URL('../', import.meta.url));
const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: website, encoding: 'utf8', windowsHide: true }).trim();
const run = { id: Number(process.env.GITHUB_RUN_ID || 1), attempt: Number(process.env.GITHUB_RUN_ATTEMPT || 1) };
const retained = await retainedReports({ reader: githubReader(process.env.GH_TOKEN), validateReport: validateQualificationReport });
const facts = buildEvidence({ ...retained, websiteCommit: commit, websiteRun: run });
const destination = resolve(website, 'artifacts/compatibility');
mkdirSync(destination, { recursive: true });
writeFileSync(resolve(destination, 'facts.json'), `${JSON.stringify(facts, null, 2)}\n`);
if (retained.historyWritable) writeFileSync(resolve(destination, 'report.json'), `${JSON.stringify(facts.identityHistory, null, 2)}\n`);
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `history_ready=${retained.historyWritable}\n`);
const receipt = `Website source: ${commit}\nCompatibility reports: ${retained.records.map(item => `run ${item.run.id} attempt ${item.run.run_attempt}, artifact ${item.artifact.id}, expires ${item.artifact.expires_at}`).join('; ') || 'unavailable'}\nEvidence notices: ${retained.issues.join(', ') || 'none'}\n`;
console.log(receipt);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `\n\`\`\`text\n${receipt}\`\`\`\n`);
