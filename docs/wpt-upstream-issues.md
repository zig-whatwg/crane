# Upstream WPT issues

Tests excluded from the 0.1 worklist because the test, not Crane, is wrong - each
times out in every shipping engine - and the upstream issue filed for each. The
exclusions live in `tools/wpt_subset.py`'s EXCLUDE table, which cites the issue.

**When an issue closes:** check that the fix is in the WPT snapshot
(`tests/wpt`, the zig-whatwg/wpt fork; the upstream commit it is built on is
in its `.crane-upstream-revision`, and `CRANE-UPSTREAM.md` there says how to
move it), delete the file's EXCLUDE entry,
re-run `python3 tools/wpt_subset.py`, run the file, and move the row below to
"Resolved".

Check them all:

```bash
gh issue list --repo web-platform-tests/wpt --search "63098 63099 63100" --state all
```

## Open

| Issue | Filed | Test(s) | Why it cannot pass |
|-------|-------|---------|--------------------|
| [wpt#65067](https://github.com/web-platform-tests/wpt/issues/65067) | 2026-11-11 | `editing/other/paste_text_with_text_transform.html` | Its top-level script asserts `window.testRunner` (WebKit's DumpRenderTree object) before defining any test, so every wptrunner browser ends in the same harness ERROR ("This test requires testRunner to read/write clipboard"): Chrome 157, Firefox 160, Safari 27.2 at 24ddf405a0, and Crane. Filed on the user's "File both" (lane editing5 b2's question 3); exempt as `test-bug` in tools/wpt_gate_exemptions.txt until the issue is resolved |
| [wpt#65066](https://github.com/web-platform-tests/wpt/pull/65066) (PR) | 2026-11-11 | `permissions/worker.https.html` | Awaits `messagePromise`, which the test never declares (one-word fix): Chrome 157 and Firefox 160 fail with "ReferenceError: messagePromise is not defined", as Crane does (gen 216); Safari 27.2 fails earlier ("Action set_permission failed: not implemented"). Filed on the user's "File both". Not in tools/wpt_gate_exemptions.txt: the file's rules exclude a file the browsers fail differently (Safari fails at an earlier step) - the integrator decides |
| [wpt#64636](https://github.com/web-platform-tests/wpt/issues/64636) | 2026-11-03 | `service-workers/service-worker/navigation-timing-extended.https.html` | Assertions 2 and 3 compare coarsened timestamps of back-to-back steps strictly: `fetchStart` is the fetch event dispatch time (Service Workers Create Fetch Event and Dispatch 17.4.12) and the handler runs at 17.4.13, so in one coarsening interval they are equal - the spec's answer. Crane: 163/180 navigations 0 ticks apart, 7/20 runs fail with equal values; no browser passes the file (Chrome assertion 1, Firefox 3, Safari 2). Suggested `assert_greater_than_equal` for 2 and 3. Filed on the user's yes (lane flakes2's evidence); stays in the worklist with a flake disposition; `crane/flakes2-sw-navigation-timing-order.https.html` pins the order the specs require |
| [wpt#64332](https://github.com/web-platform-tests/wpt/pull/64332) (PR) | 2026-10-28 | `fetch/fetch-later/quota/same-origin-iframe/multiple-iframes.https.window.js` | Still asserts `null, null` for QuotaExceededError's requested/quota; whatwg/fetch#1904 made fetchLater report them and #57078 updated the four sibling tests but missed this one. Crane follows #1904 (requested 65536, quota 0) and passes the PR's expectation. Filed on the user's yes (Codex row 126 Q69); stays in the worklist, blocking until the PR lands |
| [wpt#63098](https://github.com/web-platform-tests/wpt/issues/63098) | 2026-09-30 | `html/browsers/history/the-history-interface/traverse_the_history_1.html`, `traverse_the_history_write_after_load_1.html` | Their only path to `t.done()` is `start_test_wait()`, which only the manual-test helper calls; `write_after_load_1` also expects `document.open()` to add a history entry (removed by whatwg/html#3946) |
| [wpt#63099](https://github.com/web-platform-tests/wpt/issues/63099) | 2026-09-30 | `html/browsers/history/the-history-interface/joint_session_history/002.html` | Its third subtest waits for `document.open()` to fire `pageshow` and add a history entry - the pre-whatwg/html#3946 model |
| [wpt#63100](https://github.com/web-platform-tests/wpt/issues/63100) | 2026-09-30 | `html/browsers/history/the-location-interface/location_replace_session_history.html` | Completes only if an iframe's document is restored from session history without reloading (optional bfcache); times out in Servo, where it was written, too |

**Re-checked 2026-09-30 against upstream afe89a5df4** (the snapshot rebuilt on
wpt.fyi's aligned Chrome/Firefox/Safari revision, from fae291ef5): all four files
are unchanged upstream since fae291ef5, all three issues are open, and the
worklist regenerated against the new manifest still excludes all four.

## Everything filed, with its status (checked 2026-11-12 16:37 UTC)

The table above carries the details for the files that are excluded or exempt. This is the complete list
of what was filed under the user's account, so each can be re-checked (`gh issue view <n> --repo <repo>`).

| Item | Kind | Filed | About | Status |
|------|------|-------|-------|--------|
| wpt#63098 | issue | 2026-09-30 | traverse_the_history_1 + write_after_load_1 | open |
| wpt#63099 | issue | 2026-09-30 | joint_session_history/002 | open |
| wpt#63100 | issue | 2026-09-30 | location_replace_session_history | open |
| wpt#63811 | issue | 2026-10-17 | MutationObserver-characterData PI subtest | open |
| wpt#63812 | issue | 2026-10-17 | CSP sandbox-empty headers file name | open |
| wpt#64332 | PR | 2026-10-28 | fetchLater same-origin-iframe quota expectation | open, no review |
| wpt#64475 | issue | 2026-10-31 | dynamic-import microtasks basic.any.js Date.now() specifier | open; maintainer asked for a PR -> wpt#65105 |
| wpt#64636 | issue | 2026-11-03 | navigation-timing-extended strict comparisons | open |
| wpt#64827 | issue | 2026-11-05 | COEP reporting-to-endpoint lacks Reporting-Endpoints | open |
| wpt#64870 | issue | 2026-11-06 | COEP reporting tests post Report.toJSON() across threads | CLOSED (tests changed upstream 2026-11-07, 585d7b6f39) |
| wpt#64927 | issue | 2026-11-09 | customizable-select select-pick-option-dirtiness | open |
| wpt#64928 | issue | 2026-11-09 | customizable-select select-picker-hover-after-picking | open, 4 comments |
| wpt#65066 | PR | 2026-11-11 | permissions/worker.https.html undeclared promise | MERGED 2026-11-12 (65989351d1) |
| wpt#65067 | issue | 2026-11-11 | paste_text_with_text_transform requires window.testRunner | open, 1 comment |
| wpt#65105 | PR | 2026-11-12 | dynamic-import microtasks: unique module specifier (fixes #64475) | open |
| wpt#65399 | issue | 2026-11-18 | template-for-move-cross-document: `after.previousSibling` is the script, not "A" | open |
| wpt#65400 | issue | 2026-11-18 | fullscreen document-fullscreen-enabled-*-allowfullscreen*.sub.html (3 files): frame is same-origin | open |
| wpt#65401 | issue | 2026-11-18 | event-handler-attributes-no-bc: `assert_false(window.ran)` on a never-set property | open |
| wpt#65402 | issue | 2026-11-18 | write-active-document: expects writes to an inactive document ignored | open |
| wpt#65403 | issue | 2026-11-18 | template-for-only-html-001: resources/template-for.xhtml left behind in partial-updates/tentative | open |
| wpt#65404 | issue | 2026-11-18 | promise-resolution-order: `src="   "` fetches the base URL, never fires error | open |
| wpt#65405 | issue | 2026-11-18 | close_script_defer: `t.step` instead of `t.step_func` | open |
| wpt#65406 | issue | 2026-11-18 | not-restored-reasons/fetch.window.js: listener parameter shadows wavURL, long-wav.py never fetched | open |
| wpt#65407 | issue | 2026-11-18 | reload-service-worker-fetch-event: no `.https`, worker calls `transitionWhile()` | open |
| wpt#65463 | issue | 2026-11-19 | autoplay-disabled-by-csp: parent reads the document of a `CSP: sandbox` (opaque-origin) frame | open |
| wpt#65464 | issue | 2026-11-19 | popup-inheritance-form-submission: asserts the test page's own `document.referrer`, not the popup's | PR wpt#65843 (2026-11-27, expected value corrected to "": the form navigation replaces the initial about:blank; Chrome 157 + Firefox 161 report "") |
| wpt#65465 | issue | 2026-11-19 | unregister-immediately-during-extendable-events: top window's `TypeError` for a frame's `fetch()` | open |
| wpt#65466 | issue | 2026-11-19 | css-forms input-file/input-text base appearance: expectations differ from the ED (radius 4px, `align-items: unsafe center`) | open |
| wpt#65471 | issue | 2026-11-19 | client-url-creation-url: listens for the frame's first `'done'` only after its load; the frame posts it while parsing | open |
| wpt.fyi#5128 | issue | 2026-09-30 | Crane test runner registration request | open |
| w3c/IndexedDB#510 | spec issue | 2026-10-03 | IDBKeyRange.bound() equal keys with an open bound | open, 3 comments |
| w3c/FileAPI#226 | spec issue | 2026-10-04 | Blob/File serialization drops type | open |
| w3c/ServiceWorker#1853 | spec issue | 2026-11-05 | static routing "cache" source stops at the first cache | open, 2 comments |

## Resolved

- wpt#65066 merged upstream 2026-11-12 (65989351d1): `permissions/worker.https.html` gets the fix when
  tests/wpt moves past it.
- wpt#64870 closed: upstream changed the COEP reporting tests (585d7b6f39, 2026-11-07); re-check the
  Report.toJSON ruling against the new copies at the WPT update.

## Kept in the worklist on purpose

`html/browsers/browsing-the-web/history-traversal/pageswap/pageswap-push-navigation-hidden-document.html`
also times out in Chrome, Firefox and Safari, but because `test_driver.minimize_window()` cannot hide a
window in wpt.fyi's automated runs - an infrastructure limit, not a test bug. Crane's test_driver
implements `minimize_window` by marking the page hidden, and the file PASSES in Crane since the testdriver
merge (822673be0, 2026-09-30) - the one file in the worklist all three shipping browsers time out on.

## Candidates - not filed (the user decides on filing)

| Test | Found | Why it cannot pass |
|------|-------|--------------------|
| `xhr/open-url-multi-window-4.htm` | 2026-09-30, flakes lane | Expects `error` then `loadend` at an XHR whose frame is removed mid-request, "according to my suggested spec text in whatwg/xhr#3" (its own comment) - a proposal never adopted. HTML "destroy a document" step 2 runs "abort a document", whose step 2 cancels the document's fetches "discarding any tasks queued for them, and discarding any further data received from the network for them", and step 7 removes its queued tasks without running them: no event fires, and the test can only time out. wpt.fyi: Edge TIMEOUT 0/1; Chrome, Firefox and Safari have no result. Crane has timed out on it since the flakes lane (the XHR is canceled at the removal); before, it fired events it must not (OK 0/1). `crane/fl-xhr-frame-removed-mid-request.html` pins the spec's answer. Still in the worklist. |
