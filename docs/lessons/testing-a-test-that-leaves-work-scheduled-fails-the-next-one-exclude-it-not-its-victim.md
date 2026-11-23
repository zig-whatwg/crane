# Testing: A test that leaves work scheduled fails the next one - exclude it, not its victim

**Date**: 2026-11-23
**Lesson**: When excluding a failing framework test only moves the failure to the test after it, the failure belongs to the test BEFORE it - the one that leaves work scheduled when it ends - and that test is the one to classify and filter out.

**Why**: A Jest file's tests share one realm, one module registry and one task queue. A test that ends with a callback still queued (a passive effect, a timer, a message) hands that callback to whichever test runs next, and the callback logs into, or mutates, that test's state. Excluding the victim with a name filter does not drop the queued work: the next test inherits it. Which environment the queued work runs in also decides whether anything fails: under jsdom React 17's scheduler, with no `MessageChannel`, falls back to `setTimeout`, which Jest's fake timers hold forever, so the leftover effect never runs; every browser has `MessageChannel`, so it runs during the next test.

**What Happened**: Lane react1 classified "mutating the store in between render and commit when getSnapshot has changed" (useSyncExternalStoreShared-test.js:324) as jsdom-only: it logged "Passive effect: 0" before "A1" in Crane, Chrome, Firefox and Safari. Filtering it out with Jest's testNamePattern made the next test fail the same way, in Crane and in Chrome (runs k-r1, c-r1). The test before them, "compares to current state before bailing out, even when there's a mutation in between the sync and passive effects" (:281), renders without `act` by design and ends with its passive effect still scheduled. Filtering that one instead, its successors passed: 18 passed, 0 failed in Crane and in Chrome.

**Fix**:
1. When a filtered test's failure reappears in its successor, stop filtering successors.
2. Read the tests before it for one that ends with work queued (no `act`, a real timer, an unawaited promise, a posted message).
3. Classify that test, filter it, and run the whole file in Crane and in the reference browser: every remaining test must pass.
4. Record the evidence in the entry: which test failed while the polluter ran, and the clean run after.

**Takeaway**: **A failure that follows the exclusion list from test to test was caused by the test before it: filter the test that leaves work queued, then prove the rest of the file passes in Crane and Chrome.**
