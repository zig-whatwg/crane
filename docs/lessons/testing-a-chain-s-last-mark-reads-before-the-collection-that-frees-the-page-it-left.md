# Testing: A chain's last mark reads before the collection that frees the page it left

**Date**: 2026-11-17
**Lesson**: Once counts decide a navigated-away page's free, its wrapped tree goes when the engine collects its wrappers, so a page chain's footprint at its last mark includes the pages the collector has not reached yet; read the chain again after a forced collection before calling the difference a cost.

**Why**: Refcount step 7a freed a realm's document tree at the realm's end whatever its counts, so each step of a `load.*` chain read with the previous page already gone. Step 7b (lane rc7b) lets the counts decide, as WebKit and Blink do: a tree whose nodes script wrapped stays until V8 collects the ended realm's wrappers, and then the agent's queue frees it in slices. Which step the collection lands on depends on the collector's schedule, so the chain's figures move without anything being kept.

**What Happened**: Lane rc7b's cost pair (tip fc543513cca vs main d29206edf1d, chat.local) read `load.app` memory-pass steady 1.049 (40.5 vs 38.5 MB) on the full pass and again at 15 launches. The step-by-step medians were the same through step 6; from step 7 the tip stayed about 2 MB higher (one 500-row page). The 30-step `memory.page-growth` chain levelled off at 0.988, and `load.news` and `load.docs` were within the bar. perf_bench gives a chain no `collect=1` (runner.zig `collectedUrl`), so a diagnostic harness, used only in the mirror and restored after, read the chain's last step once more after `TestUtils.gc()` twice and 500 ms idle: tip 29.1 MB, main 28.9 MB, 1.006. The user accepted the row as collection timing (2026-11-17, scoped to that row) and queued a real chain `--collected` reading for perf_bench.

**Fix**: For a chain row over the bar after a lifetime change, compare the step-by-step medians (series) and read the last step after a forced collection. If the after-collection figures match, the cost is when the collector runs, not what is kept.

**Takeaway**: **A chain's last-mark footprint after a lifetime change is a collector-schedule reading; compare its per-step series and its footprint after a forced collection before calling it kept memory.**
