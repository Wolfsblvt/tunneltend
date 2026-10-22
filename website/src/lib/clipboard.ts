// SPDX-License-Identifier: AGPL-3.0-only
/** One shared live region announces copies and state changes. */
let hideTimer: number | undefined;

export function announce(message: string): void {
  const region = document.querySelector<HTMLElement>('[data-live-region]');
  if (!region) return;
  region.textContent = message;
  region.classList.add('is-visible');
  window.clearTimeout(hideTimer);
  hideTimer = window.setTimeout(() => region.classList.remove('is-visible'), 2000);
}

/** Real clipboard behaviour; the label swap alone is never the proof of a copy. */
export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    announce('Copied to clipboard.');
    return true;
  } catch {
    announce('Copy failed. Select the text and copy it manually.');
    return false;
  }
}

/** Buttons with data-copy copy their value (or the text of data-copy-from); the label swaps for 2 s without moving focus. */
export function wireCopyButtons(root: ParentNode): void {
  for (const button of root.querySelectorAll<HTMLButtonElement>('[data-copy]')) {
    if (button.dataset.copyWired) continue;
    button.dataset.copyWired = 'true';
    button.addEventListener('click', async () => {
      const source = button.dataset.copyFrom ? document.getElementById(button.dataset.copyFrom)?.textContent ?? '' : button.dataset.copy ?? '';
      const done = await copyText(source.trim());
      if (!done) return;
      if (button.hasAttribute('data-copy-state')) {
        // A fixed-width control shows its confirmation in place: both texts share one grid cell.
        button.classList.add('is-copied');
        window.setTimeout(() => button.classList.remove('is-copied'), 2000);
        return;
      }
      const label = button.querySelector<HTMLElement>('[data-copy-label]') ?? button;
      const original = label.textContent ?? '';
      label.textContent = button.dataset.copyDone ?? 'Copied';
      window.setTimeout(() => { label.textContent = original; }, 2000);
    });
  }
}
