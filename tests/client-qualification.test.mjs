import test from 'node:test';
import assert from 'node:assert/strict';
import { validateQualificationReport } from '../scripts/lib/client-qualification.mjs';

const distributionIds = ['package-acquisition','release-selection','asset-selection','published-digest','guarded-extraction','version-agreement','installation-agreement'];
const cliIds = ['version','runtimes','runtimes-json','runtime-status','runtime-connect','runtime-stop','list-json','status-missing','stop-missing'];
const boundary = (ids, outcome) => ({ outcome, checks: ids.map(id => ({id, outcome})) });
function report() {
  return {
    schemaVersion: 2, contractVersion: 2, observedAt:'2026-10-26T00:00:00Z', checkedAt:'2026-10-26T00:01:00Z',
    run:{id:'12', attempt:1, workflow:'upstream-compatibility.yml', artifact:'client-qualification-release'},
    source:{repository:'Wolfsblvt/tunneltend', commit:'a'.repeat(40), harnessSha256:'b'.repeat(64), adapterSha256:'c'.repeat(64), updaterSha256:'f'.repeat(64)},
    package:{kind:'release', version:'1.0.1', sha256:'d'.repeat(64), sourceCommit:null},
    release:{id:123, tag:'v0.0.18', publishedAt:'2026-10-23T00:00:00Z'},
    architectures:['amd64','arm64'].map((architecture, i) => ({
      architecture, asset:{id:123+i, name:`tunnel-client-v0.0.18-windows-${architecture}.zip`, sha256:'e'.repeat(64)}, execution:i ? 'not exercised' : 'native',
      distribution:{outcome:'passed', checks:distributionIds.map((id,j) => ({id, outcome:i && j >= 5 ? 'not exercised' : 'passed'}))}, credentialFreeCli:boundary(cliIds, i ? 'not exercised' : 'passed'),
      localFleet:boundary(['owned-fleet'],'not exercised'), connectedConsumer:boundary(['connected-call'],'not exercised')
    }))
  };
}
test('accepts separate package/architecture and unexercised consumer facts', () => {
  const value=report();
  value.architectures[1].distribution.checks.slice(-2).forEach(c => { c.outcome='not exercised'; });
  assert.equal(validateQualificationReport(value), value);
});
test('retains failure and unavailable reports with missing acquisition identities', () => {
  for (const outcome of ['failed','unavailable']) {
    const value=report(); value.release=null; value.package.sha256=null; value.source.adapterSha256=null;
    for(const arch of value.architectures) { arch.asset=null; arch.execution='not exercised'; arch.distribution=boundary(distributionIds,'not exercised'); arch.distribution.checks[0].outcome=outcome; arch.distribution.outcome=outcome; arch.credentialFreeCli=boundary(cliIds,'not exercised'); }
    assert.equal(validateQualificationReport(value), value);
  }
});
test('keeps partial distribution unexercised when a CLI failure prevents installation', () => {
  const value=report();
  const arch=value.architectures[0];
  arch.credentialFreeCli.checks[6].outcome='failed'; arch.credentialFreeCli.outcome='failed';
  arch.distribution.checks[6].outcome='not exercised'; arch.distribution.outcome='not exercised';
  assert.equal(validateQualificationReport(value), value);
});
for (const [name, mutate] of Object.entries({
  'unknown fields': r => { r.stdout='untrusted output'; },
  'arbitrary check text': r => { r.architectures[0].distribution.checks[0].id='<script>'; },
  'duplicate architecture': r => { r.architectures[1].architecture='amd64'; },
  'partial evidence disguised as pass': r => { r.architectures[0].distribution.checks[0].outcome='failed'; },
  'missing asset identity': r => { r.architectures[0].asset.sha256=null; },
  'missing updater identity': r => { r.source.updaterSha256=null; },
  'old assisted-proof contract': r => { r.schemaVersion=1; r.contractVersion=1; delete r.source.updaterSha256; },
  'invented connected proof': r => { r.architectures[0].connectedConsumer=boundary(['connected-call'],'passed'); },
  'non-native CLI proof': r => { r.architectures[0].execution='not exercised'; },
  'wrong artifact identity': r => { r.run.artifact='client-qualification-source'; },
  'backward timestamp': r => { r.checkedAt='2026-10-25T00:00:00Z'; },
  'non-ISO timestamp': r => { r.checkedAt='2026Z'; },
  'invalid calendar date': r => { r.checkedAt='2026-02-30T00:00:00Z'; },
  'duplicate check': r => { r.architectures[0].distribution.checks.push(r.architectures[0].distribution.checks[0]); },
  'missing distribution checks': r => { r.architectures[0].distribution.checks.pop(); },
  'unexercised native distribution': r => { r.architectures[0].distribution.checks[6].outcome='not exercised'; },
  'partial CLI pass': r => { r.architectures[0].credentialFreeCli.checks[6].outcome='not exercised'; }
})) test(`refuses ${name}`, () => { const value=report(); mutate(value); assert.throws(() => validateQualificationReport(value)); });

for (const id of ['version-agreement','installation-agreement']) {
  for (const outcome of ['passed','failed','unavailable']) {
    test(`refuses unexercised ${id} marked ${outcome}`, () => {
      const value=report();
      value.architectures[1].distribution.checks.find(c => c.id === id).outcome=outcome;
      assert.throws(() => validateQualificationReport(value), /Unexercised installation\/version claim/);
    });
  }
}
