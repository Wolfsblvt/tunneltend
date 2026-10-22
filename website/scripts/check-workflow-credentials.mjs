// SPDX-License-Identifier: AGPL-3.0-only
// Reads the website workflow and enforces who may hold the Cloudflare deployment credential:
// only the step that runs the Wrangler deploy, and nothing that builds or checks the site.
// GitHub Actions cannot be executed locally, so this inspects the exact exposure boundary the
// workflow declares: workflow, job and step environments plus the secret expressions in them.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';

const path = resolve(dirname(fileURLToPath(import.meta.url)), '../../.github/workflows/website.yml');
const workflow = parse(readFileSync(path, 'utf8'));
const CREDENTIALS = /CLOUDFLARE_API_TOKEN|CLOUDFLARE_ACCOUNT_ID/u;

const holds = (value) => CREDENTIALS.test(JSON.stringify(value ?? {}));
const failures = [];

if (holds(workflow.env)) failures.push('workflow-level env carries a Cloudflare credential');
if (holds(workflow.permissions)) failures.push('workflow permissions mention a Cloudflare credential');
for (const [jobName, job] of Object.entries(workflow.jobs)) {
  if (holds(job.env)) failures.push(`job ${jobName} env carries a Cloudflare credential`);
  const holders = job.steps.filter((step) => holds(step.env) || holds(step.with));
  for (const step of holders) {
    const commands = String(step.run ?? '');
    if (!/wrangler(\.cmd)?\s+deploy/u.test(commands)) failures.push(`step "${step.name}" holds a Cloudflare credential but does not deploy`);
    if (/\bnpm\b|\bnpx\b|\bnode\s/u.test(commands)) failures.push(`deploy step "${step.name}" runs the package toolchain`);
    if (JSON.stringify(step.env ?? {}).includes('WOLFSBLVT_LEGAL_OPERATOR_B64')) failures.push(`deploy step "${step.name}" also holds the legal operator projection`);
  }
  if (holders.length !== 1) failures.push(`exactly one step may hold the Cloudflare credential; found ${holders.length}`);
  for (const step of job.steps) {
    if (holds(step.env)) continue;
    if (/wrangler(\.cmd)?\s+deploy/u.test(String(step.run ?? ''))) failures.push(`step "${step.name}" deploys without being the credential holder`);
    if (/secrets\.CLOUDFLARE/u.test(JSON.stringify(step))) failures.push(`step "${step.name}" references a Cloudflare secret outside its env`);
  }
}
if (failures.length) throw new Error(`Website workflow credential boundary violated:\n- ${failures.join('\n- ')}`);
console.log('Cloudflare credentials reach only the Wrangler deploy step.');
