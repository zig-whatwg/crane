# Testing: A subtest count can go DOWN because a test started testing something

**Date**: 2026-09-22
**Lesson**: `xhr/access-control-and-redirects.any.js` went from 4 passing
subtests to 3, and the change that did it was an improvement.

**Why**: its async cases read

    xhr.onerror = test.unreached_func("Network error");
    ...
    test.done();

with the `done()` synchronous. While `send()` never reached the network, no
request went out, `onerror` never fired, `unreached_func` was never called, and
the subtest passed **by doing nothing**. Once `send()` actually dispatched, the
cross-origin request was denied by CORS, `onerror` fired, and the subtest failed
on its merits. The file is measuring CORS for the first time.

**What Happened**: it appeared in a per-file diff as the single regression in an
otherwise clean sweep - `OK 40 -> 67`, `TIMEOUT 29 -> 7`, `subtests timed out
50 -> 9`. Reported as a regression it would have been chased; reported with the
reason it is a line item.

The same sweep showed a FLAT crash column that was not flat: the baseline's one
crash became OK and a different file crashed once, non-reproducibly. A totals
row said "crashes unchanged" and two real transitions were hiding under it.

**Fix**: when a subtest count drops, read the test before assuming a defect.
`unreached_func`, `assert_unreached` and a synchronous `done()` are the shapes
that pass while an engine does nothing at all.

**Takeaway**: **Subtest counts are not a monotone quality signal.** An engine
that starts performing an operation will fail tests that used to pass by
skipping it, and the honest report says which of the two is happening. Diff per
FILE and per SUBTEST NAME; a totals row can hold two opposite movements that
cancel.
