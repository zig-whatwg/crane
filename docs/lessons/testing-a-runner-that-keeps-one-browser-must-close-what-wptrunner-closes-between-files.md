# Testing: A runner that keeps one Browser must close what wptrunner closes between files

**Date**: 2026-11-17
**Lesson**: Crane's WPT runner reuses one Browser for every file of a runner process, so whatever a Browser keeps across a navigation - popups above all - lives into the next file unless the runner closes it the way wptrunner does.

**Why**: wptrunner's testharness executor (tools/wptrunner/wptrunner/executors/executorwebdriver.py `do_testharness`) calls `close_old_windows` before each test and again after it: every window but the runner's is closed with WebDriver's Close Window, HTML "close a top-level traversable". Crane's runner opened a fresh top-level traversable per file (`Browser.navigateWithOptions`) but popups are the Browser's (`dom.auxiliary_navigables.Popups`), and only the Browser's end closed them.

**What Happened**: lane locks1 (2026-11-17) found web-locks/bfcache/contention.https.window.js's three shared-worker variants failing after held.tentative or sharedworker-multiple.tentative in the same runner: since nav4b2 a restored popup kept a shared worker's owner active, so no eviction. Alone they passed. The worklist sweeps did not show it (the tentative files are not in it), but mixed lists and `--verify` x10 did. Lane bugs1's red pair (crane/bugs1-popup-left-open.html, then crane/bugs1-popup-closed-between-files.html, in one process): the second file heard the first file's popup broadcasting.

**Fix**: `WptBrowser.closeOldWindows` at the start of each file and crashtest: every open top-level traversable but the host page is closed through `Browser.closeTraversable` - the console's `:close`, the path a browser has (beforeunload, unload, documents destroyed, the popup's cached pages evicted) - not `dom.auxiliary_navigables.closeAll`, which is the Browser-END teardown and is safe only after the bfcache eviction `Browser.deinit` orders first. It changes every file's environment: a FULL A/B.

**Takeaway**: **Before trusting a runner's per-file isolation, list what the Browser keeps across a navigation and check each against what wptrunner resets between tests; close it through the path a browser has, never through the Browser's own end-of-life teardown.**
