# Testing: A shared limit below one file's parallel demand flakes by interleaving

**Date**: 2026-10-30
**Lesson**: When a file's subtests run in parallel and each needs a slot of a shared, capped resource, a cap below their total demand makes WHICH subtest fails depend on how they interleave - a flake whose cause is a configuration number, not a race in the code.

**Why**: fetch/fetch-later/send-on-deactivate.https.window.js runs its five subtests at once (its `parallelPromiseTest` is an `async_test` per subtest). Three of them each open a noopener popup, navigate it (its page enters the back/forward cache) and go back. Each stores two pages over its life, so up to six pages want Crane's cache at once - and a Browser kept two (`back_forward_cache_size`, WebKit's capacity). The store that pushed the cache over its size evicted the oldest page; that popup's history.back() loaded a fresh document, whose `window.pageshowEvent` (set by a listener on the evicted page) was undefined: "Cannot read properties of undefined (reading 'persisted')". Which page was oldest depended on the order the three subtests reached their navigations - about half of each name failed per run (row 130's 10 pairs: 14/30 and 16/30; this batch's 10 base runs: 5/10, 4/10, 4/10).

**What Happened**: The failure looked like a restore race ("a pageshow that fires too late, or a restore that runs too early"). Two things pointed elsewhere at once: every failure had the same message (so the same object was missing every time - see testing-a-count-that-moves-between-runs-diff-the-failure-messages.md), and the file's two subtests whose popups are never cached never failed. Counting the pages the file keeps at once against the cache size explained the whole pattern; reading the engines settled the number: Chrome keeps 6 pages per tab (one BackForwardCacheImpl per WebContents, so popups never evict each other), Firefox 8 in all (nsSHistory::CalcMaxTotalViewers), WebKit 2 in all (CacheModel). The integrator ruled Firefox's behaviour - Browser-wide, 8 - by golden rule 2 mechanism by mechanism.

**Fix**:
1. Reproduce at N >= 10 and table each subtest's status and message per run.
2. When one message covers every failure and only the subtests that use the shared resource flake, count the file's peak demand on that resource against its cap.
3. Write a Crane test that reaches the cap deterministically, without parallel subtests (crane/nav2b6-bfcache-three-popups.window.js: three popups' pages kept at once, then each goes back) - RED 0/1 x10 on base.
4. Choose the cap from what the engines ship, not from what makes the test pass, and measure what it costs (here ~2.2 MB of retained heap per kept page, crane/nav2b6-bfcache-heap-9.window.js).

**Takeaway**: **A flake that hits only the subtests sharing a capped resource, always with the same message, is the cap - count the file's peak demand before looking for a race.**
