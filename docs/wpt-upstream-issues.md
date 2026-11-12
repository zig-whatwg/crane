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

## Resolved

None yet.

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
