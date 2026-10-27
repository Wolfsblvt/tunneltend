// SPDX-License-Identifier: AGPL-3.0-only
/**
 * The manual "download and verify yourself" route, written once. The homepage and the manual
 * both render this exact text, and scripts/check-manual-verify.mjs executes it, so the
 * displayed ritual cannot drift from the one that refuses a mismatch.
 *
 * Everything that follows the comparison sits in the else branch of a single statement: a
 * terminating error cannot be skipped by a terminal that feeds pasted lines one at a time.
 */
export function manualVerifyScript() {
  return String.raw`$zip = '.\tunneltend-<version>.zip'
$expected = ((Get-Content "$zip.sha256" -Raw) -split '\s+' | Select-Object -First 1).ToLowerInvariant()
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expected -notmatch '^[0-9a-f]{64}$' -or $actual -ne $expected) {
  throw "Checksum mismatch for $zip. Expected $expected but downloaded $actual. Nothing was extracted. Delete the download and get it again."
} else {
  Expand-Archive $zip -DestinationPath .\tunneltend
  .\tunneltend\Install-TunnelTend.cmd
}`;
}
