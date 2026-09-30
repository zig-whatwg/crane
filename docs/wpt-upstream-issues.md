# Upstream WPT issues

Tests excluded from the 0.1 worklist because the test, not Crane, is wrong - each
times out in every shipping engine - and the upstream issue filed for each. The
exclusions live in `tools/wpt_subset.py`'s EXCLUDE table, which cites the issue.

**When an issue closes:** check that the fix is in the WPT snapshot
(`tests/wpt`, the zig-whatwg/wpt fork), delete the file's EXCLUDE entry,
re-run `python3 tools/wpt_subset.py`, run the file, and move the row below to
"Resolved".

Check them all:

```bash
gh issue list --repo web-platform-tests/wpt --search "63098 63099 63100" --state all
```

## Open

| Issue | Filed | Test(s) | Why it cannot pass |
|-------|-------|---------|--------------------|
| [wpt#63098](https://github.com/web-platform-tests/wpt/issues/63098) | 2026-09-30 | `html/browsers/history/the-history-interface/traverse_the_history_1.html`, `traverse_the_history_write_after_load_1.html` | Their only path to `t.done()` is `start_test_wait()`, which only the manual-test helper calls; `write_after_load_1` also expects `document.open()` to add a history entry (removed by whatwg/html#3946) |
| [wpt#63099](https://github.com/web-platform-tests/wpt/issues/63099) | 2026-09-30 | `html/browsers/history/the-history-interface/joint_session_history/002.html` | Its third subtest waits for `document.open()` to fire `pageshow` and add a history entry - the pre-whatwg/html#3946 model |
| [wpt#63100](https://github.com/web-platform-tests/wpt/issues/63100) | 2026-09-30 | `html/browsers/history/the-location-interface/location_replace_session_history.html` | Completes only if an iframe's document is restored from session history without reloading (optional bfcache); times out in Servo, where it was written, too |

## Resolved

None yet.

## Kept in the worklist on purpose

`html/browsers/browsing-the-web/history-traversal/pageswap/pageswap-push-navigation-hidden-document.html`
also times out in Chrome, Firefox and Safari, but because `test_driver.minimize_window()` cannot hide a
window in wpt.fyi's automated runs - an infrastructure limit, not a test bug. Crane's test_driver
implements `minimize_window` by marking the page hidden, and the file PASSES in Crane since the testdriver
merge (822673be0, 2026-09-30) - the one file in the worklist all three shipping browsers time out on.
