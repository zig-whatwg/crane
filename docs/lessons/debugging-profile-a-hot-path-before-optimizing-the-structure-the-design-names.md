# Debugging: Profile a hot path before optimizing the structure the design names

**Date**: 2026-10-30
**Lesson**: A cost piece's design names the data structure it suspects; a `sample` profile of the real workload names where the time goes, and the worst term may be one step away from that structure.

**Why**: Lane nav2's piece H ("fragment cost") was designed against the joint session history: an id->index map, per-navigable lists, one compaction for clear-forward, `ensureHistoryEntries` once per navigation. Since piece E, a fragment navigation also writes every view twice, so the history looked like the cost.

**What Happened**: One untimed run of crane/nv2-fragment-navigation-cost.html with macOS `sample` attached to the runner child (`--parallel=1`, `pgrep -n`, 2 s from 0.3 s in) showed, per fragment navigation in the listener variant: the navigate-event machinery ~57% (spec work: each synchronous hash change aborts the previous navigate event, still ongoing until its microtask, with a new AbortError), Navigation's "update the navigation API entries for a same-document navigation" ~25%, and the joint history only ~12%. Inside that 25% was a check, for every NavigationHistoryEntry handed out, of whether the entry list still contained it - a linear search per handed entry, and every navigation hands out one more: quadratic in a frame's navigations. H shipped the design's history changes plus a fast path that skips that search when one walk of the list counts every handed entry: the in-page 10,000 updates went from ~337 ms to ~311 (listener: 353 -> 328), and the timed bars came in at 0.968 and 0.983.

**Fix**:
1. Before optimizing, profile the cost test itself on the pool host: `sample <runner child pid> <secs> -mayDie -file out.txt`, the child found with `pgrep -n -f <runner path>` after a short delay.
2. Read the call tree under the entry point (here `Location.set_hash`), not the top-of-file symbol counts - those are dominated by realm creation.
3. Separate spec work you must keep (the navigate event's abort) from incidental work (a search that grows with history).
4. Keep a characterization test for the structural change (tests/html/navigation/nav2h_indexes_test.zig checks every indexed lookup against a scan after random changes) so the rewrite cannot change behaviour.

**Takeaway**: **Profile the workload the bar measures before rebuilding the structure the design suspects; look for terms that grow with the session, wherever they live.**
