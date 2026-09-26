# Testing: The per-file ceiling does not bound the file

**Date**: 2026-09-22
**Lesson**: `waitForCompletion`'s timeout covers only the wait for `__wpt_complete`; the navigation, the parse and every script the parser runs are unbounded.

**Why**: `runHTMLTest` is three phases - `loadTestHarness`,
`loadPageWithOptions`, `waitForCompletion` - and only the third has a
deadline. `fetch()` is synchronous down to `curl_easy_perform`, and
`CURLOPT_TIMEOUT` is 0, so a script that polls in a loop never returns to the
phase that could stop it:

    loadPageWithOptions -> parseHTMLWithScripting -> runClassicScript
      -> PerformCheckpoint -> AsyncFunctionAwaitResolveClosure
        -> fetchCallback -> curl_easy_perform -> poll()

**What Happened**: `common/dispatcher/dispatcher.js` - loaded by **251**
`html/` sources - is `while(1) { try { await fetch(...) } catch {} }`.
`history-traversal/pagereveal/order-in-prerender-activation.https.html` sat in
that stack against a 10s ceiling and never came back, and every file queued
behind it waited too. Another file has run **78 minutes** this way. A sampled
stack named it in one command; reasoning about it from the journal did not,
because a hung sweep and a slow sweep look identical there.

**Fix**: `tests/wpt_runner/stall_watchdog.zig`. The supervisor cannot see
inside the child, but the journal grows by one record per finished file, so a
journal that has not grown is a child that has not finished one - a signal
that needs no cooperation from whatever is stuck. SIGKILL past 150s (more than
double the longest legal per-file budget) and record the file as TIMEOUT: a
hang is not a crash, nothing faulted.

**Takeaway**: **Check liveness by the journal's mtime, not by the process -
and give any unbounded phase an external deadline, because an in-process one
cannot fire while the process is inside a blocking C call.**
