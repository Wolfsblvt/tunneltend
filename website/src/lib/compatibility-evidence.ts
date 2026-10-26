// SPDX-License-Identifier: AGPL-3.0-only
/** Refresh current availability without rewriting the exact historical report in details. */
export function refreshEvidence(root: Document, now = Date.now()) {
  for (const element of root.querySelectorAll<HTMLElement>('[data-evidence-available-until]')) {
    if (now >= Date.parse(element.dataset.evidenceAvailableUntil!)) {
      element.textContent = 'Unavailable';
    }
  }
  for (const element of root.querySelectorAll<HTMLElement>('[data-routine-available-until]')) {
    if (now >= Date.parse(element.dataset.routineAvailableUntil!)) {
      element.textContent = 'Unavailable — evidence expired. Historical qualification:';
    }
  }
  for (const element of root.querySelectorAll<HTMLElement>('[data-evidence-expiry]')) {
    if (now >= Date.parse(element.dataset.evidenceExpiry!)) {
      element.textContent = 'Expired — this historical check is no longer retained.';
    }
  }
}
