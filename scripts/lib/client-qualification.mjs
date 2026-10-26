import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// This fixed-schema validator is shared by the producer and retained consumer.
// It intentionally accepts no caller-supplied schema or remote references.
const schema = JSON.parse(readFileSync(new URL('../../schemas/client-qualification.schema.json', import.meta.url), 'utf8'));
const boundaries = ['distribution', 'credentialFreeCli', 'localFleet', 'connectedConsumer'];
const checkIds = {
  distribution: ['package-acquisition','release-selection','asset-selection','published-digest','guarded-extraction','version-agreement','installation-agreement'],
  credentialFreeCli: ['version','runtimes','runtimes-json','runtime-status','runtime-connect','runtime-stop','list-json','status-missing','stop-missing'],
  localFleet: ['owned-fleet'], connectedConsumer: ['connected-call']
};
function check(value, rule, path) {
  if (rule.$ref) return check(value, schema.$defs[rule.$ref.split('/').at(-1)], path);
  const reject = () => { throw new Error(`Invalid qualification report at ${path}`); };
  if ('const' in rule && value !== rule.const) reject();
  if (rule.enum && !rule.enum.includes(value)) reject();
  const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value === 'number' && Number.isInteger(value) ? 'integer' : typeof value;
  if (rule.type && ![rule.type].flat().includes(type)) reject();
  if (value === null) return;
  if (typeof value === 'string') {
    if (rule.pattern && !new RegExp(rule.pattern).test(value)) reject();
    if (rule.maxLength && value.length > rule.maxLength) reject();
    if (rule.format === 'date-time' && (!Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0, 19) !== value.slice(0, 19))) reject();
  }
  if (typeof value === 'number' && (value < (rule.minimum ?? -Infinity) || value > (rule.maximum ?? Infinity))) reject();
  if (Array.isArray(value)) {
    if (value.length < (rule.minItems ?? 0) || value.length > (rule.maxItems ?? Infinity)) reject();
    value.forEach((item, i) => check(item, rule.items, `${path}[${i}]`));
  } else if (typeof value === 'object') {
    for (const key of rule.required ?? []) if (!Object.hasOwn(value, key)) reject();
    for (const [key, item] of Object.entries(value)) {
      if (!Object.hasOwn(rule.properties ?? {}, key)) reject();
      check(item, rule.properties[key], `${path}.${key}`);
    }
  }
}

/** Validate bounded metadata and cross-field evidence claims; never execute it. */
export function validateQualificationReport(value) {
  if (Buffer.byteLength(JSON.stringify(value)) > 65536) throw new Error('Qualification report exceeds 64 KiB');
  check(value, schema, 'report');
  if (new Set(value.architectures.map(a => a.architecture)).size !== 2) throw new Error('Duplicate qualification architecture');
  if (value.run.artifact !== `client-qualification-${value.package.kind}`) throw new Error('Package/artifact mismatch');
  if (value.package.kind === 'source' && value.package.sourceCommit !== value.source.commit) throw new Error('Source package commit mismatch');
  if (Date.parse(value.checkedAt) < Date.parse(value.observedAt)) throw new Error('Invalid qualification chronology');
  for (const arch of value.architectures) {
    for (const key of boundaries) {
      const boundary = arch[key];
      if (boundary.checks.length !== checkIds[key].length || boundary.checks.some(c => !checkIds[key].includes(c.id))) throw new Error('Missing or misplaced qualification checks');
      if (new Set(boundary.checks.map(c => c.id)).size !== boundary.checks.length) throw new Error('Duplicate qualification check');
      if (key === 'distribution' && arch.execution === 'not exercised'
        && boundary.checks.some(c => ['version-agreement','installation-agreement'].includes(c.id) && c.outcome !== 'not exercised')) {
        throw new Error('Unexercised installation/version claim');
      }
      const applicable = key === 'distribution' && arch.execution === 'not exercised' ? boundary.checks.filter(c => !['version-agreement','installation-agreement'].includes(c.id)) : boundary.checks;
      const expected = applicable.some(c => c.outcome === 'failed') ? 'failed'
        : applicable.some(c => c.outcome === 'unavailable') ? 'unavailable'
        : applicable.some(c => c.outcome === 'not exercised') ? 'not exercised' : 'passed';
      if (boundary.outcome !== expected) throw new Error('Inconsistent qualification boundary');
    }
    if (arch.distribution.outcome === 'passed' && (!value.release || !arch.asset?.sha256 || !value.package.version || !value.package.sha256 || !value.source.adapterSha256 || !value.source.updaterSha256)) throw new Error('Missing qualification identity');
    if (arch.execution === 'not exercised' && arch.credentialFreeCli.outcome === 'passed') throw new Error('Non-native CLI claim');
    if (arch.distribution.outcome === 'passed') {
      const required = arch.execution === 'native' ? checkIds.distribution : checkIds.distribution.slice(0, 5);
      if (required.some(id => arch.distribution.checks.find(c => c.id === id).outcome !== 'passed')) throw new Error('Incomplete distribution pass');
    }
    if (arch.credentialFreeCli.outcome === 'passed' && arch.credentialFreeCli.checks.some(c => c.outcome !== 'passed')) throw new Error('Incomplete CLI pass');
    // These two layers are deliberately outside this credential-free producer.
    if (arch.localFleet.outcome !== 'not exercised' || arch.connectedConsumer.outcome !== 'not exercised') throw new Error('Unowned qualification claim');
  }
  return value;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  validateQualificationReport(JSON.parse(readFileSync(process.argv[2], 'utf8')));
  process.stdout.write('Qualification report valid\n');
}
