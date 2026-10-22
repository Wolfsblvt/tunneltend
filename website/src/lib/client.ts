// SPDX-License-Identifier: AGPL-3.0-only
/** Shared client behaviour for every page, the manual included. Plain DOM; no framework. */
import { wireCopyButtons } from './clipboard';
import { wireSearch } from './search';
import { labelShortcut, openHashTarget, wireDisclosures, wirePanels, wireReaderToggle, wireThemeControl } from './shell-behaviour';

wireThemeControl();
wireReaderToggle();
wirePanels();
wireSearch();
labelShortcut();
wireCopyButtons(document);
wireDisclosures();
openHashTarget();
window.addEventListener('hashchange', openHashTarget);
