// SPDX-License-Identifier: AGPL-3.0-only
// Executes the shared manual verification script in PowerShell against a good and a tampered
// release ZIP. The refusal must happen before extraction or the installer launch. The script
// uses Windows paths and a .cmd launcher, so this check runs where the product runs.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { manualVerifyScript } from '../src/data/manual-verify.mjs';

// The manual keeps a literal copy of the script; it must be the shared one, whatever the platform.
const guide = readFileSync(new URL('../src/content/docs/docs/getting-started.md', import.meta.url), 'utf8');
const fence = '`'.repeat(3);
if (!guide.includes([`${fence}powershell`, manualVerifyScript(), fence].join('\n'))) {
  throw new Error('getting-started.md does not carry the shared manual verification script.');
}

if (process.platform !== 'win32') {
  console.log('Manual verification script check skipped: it executes Windows paths and a .cmd launcher.');
  process.exit(0);
}

const version = '9.9.9';
const root = mkdtempSync(join(tmpdir(), 'tunneltend-manual-verify-'));

function run(name, sha256Text, zipBytes) {
  const dir = join(root, name);
  mkdirSync(dir);
  // A real ZIP holding a stub installer that leaves a marker, built with the platform tool.
  const payload = join(dir, 'payload');
  mkdirSync(payload);
  writeFileSync(join(payload, 'Install-TunnelTend.cmd'), '@echo ran> installer-ran.txt\r\n');
  const zip = join(dir, `tunneltend-${version}.zip`);
  const built = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command',
    `Compress-Archive -Path '${payload}\\*' -DestinationPath '${zip}'`], { encoding: 'utf8', windowsHide: true });
  if (built.status !== 0) throw new Error(`Could not build the test ZIP: ${built.stderr}`);
  const bytes = zipBytes?.(readFileSync(zip)) ?? readFileSync(zip);
  const digest = createHash('sha256').update(readFileSync(zip)).digest('hex');
  writeFileSync(zip, bytes);
  writeFileSync(`${zip}.sha256`, sha256Text(digest));
  const scriptPath = join(dir, 'verify.ps1');
  // The extracted folder is `.\tunneltend`, so the stub installer starts there, as for a user.
  writeFileSync(scriptPath, `Set-Location -LiteralPath '${dir}'\n${manualVerifyScript().replace('<version>', version)}\n`);
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', scriptPath], { encoding: 'utf8', windowsHide: true });
  return { result, extracted: existsSync(join(dir, 'tunneltend')), launched: existsSync(join(dir, 'installer-ran.txt')) || existsSync(join(dir, 'tunneltend', 'installer-ran.txt')) };
}

try {
  const good = run('good', (digest) => `${digest}  tunneltend-${version}.zip\n`);
  if (good.result.status !== 0 || !good.extracted || !good.launched) {
    throw new Error(`A matching checksum must extract and run the installer.\n${good.result.stdout}${good.result.stderr}`);
  }
  const cases = {
    mismatch: run('mismatch', () => `${'0'.repeat(64)}  tunneltend-${version}.zip\n`),
    tampered: run('tampered', (digest) => `${digest}  tunneltend-${version}.zip\n`, (zip) => Buffer.concat([zip, Buffer.from('x')])),
    malformed: run('malformed', () => 'not a digest\n'),
  };
  for (const [name, outcome] of Object.entries(cases)) {
    if (outcome.result.status === 0 || outcome.extracted || outcome.launched) {
      throw new Error(`The ${name} checksum must be refused before extraction or launch.\n${outcome.result.stdout}${outcome.result.stderr}`);
    }
    if (!/Checksum mismatch/u.test(outcome.result.stderr)) {
      throw new Error(`The ${name} refusal must say why.\n${outcome.result.stderr}`);
    }
  }
  console.log('Manual verification extracts on a match and refuses mismatched, tampered and malformed checksums before extraction.');
} finally {
  rmSync(root, { recursive: true, force: true });
}
