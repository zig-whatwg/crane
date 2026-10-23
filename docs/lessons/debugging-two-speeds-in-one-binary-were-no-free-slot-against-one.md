# Debugging: Two speeds in one binary were no free slot against one

**Date**: 2026-10-23
**Lesson**: gc_bench's append/remove exited in about 1.4 s in some runs and 2.7 s in others, same binary. The two speeds were a std hash map with ONE free slot left against one with NONE. A miss probes until it meets a free slot, or `capacity` slots when there is none, so one free slot halves every miss and none doubles it.

**Why**: Each realm's wrapper cache maps an instance's address to its entry in a `std.AutoHashMap`. std deletes by tombstone and never counts a tombstone against its load (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`), so a map whose puts and removes balance never grows. Growing was the only thing that cleared tombstones.
- Every collected wrapper takes its entry out (`unlinkCollected`).
- The deferred teardown queue keeps the collected nodes alive, so no address comes back, and every new wrapper is a key the map has never seen.
- Inserts that meet no tombstone on their probe path take free slots, and nothing gives one back.
- By the end of the run there were 0, 1 or 2 free slots out of 16,384, depending on where V8's automatic collections had fallen.
- The realm's end then asks about each of ~78,000 queued nodes twice (`drainDeferred` -> `wrappedAgain`, `wrappedElsewhere`): about 156,000 misses at 16,384 or ~8,192 slots each.

**What Happened**: Codex row 117 profiled the append/remove bar. 58-73% of the samples were `HashMap.getIndex` misses under the wrapper cache, all after the loop's report line, on main without row 117's code. The hypothesis "tombstones and/or capacity" was proven by temporary instrumentation (never committed), built from a source archive:
- At each phase of the realm's end it printed the map's capacity, live, tombstone and free counts, and the mean cost of a miss computed from std's slot metadata. Every 20,000 `set`s it printed the same.
- Across 14 runs, the 10 slow runs had free = 0 (mean miss 16,384 slots; drain 2.39-2.50 s) and the 4 fast ones free = 1-2 (mean miss ~8,191; drain 1.24 s).
- The load was 7.2-7.9 throughout and did not decide the mode: round 5 was fast and round 6 slow at the same 7.46.
- Free slots fell from ~3,000 at 20,000 sets, to ~230, to ~30, to 0-4 by 80,000. Each 20,000-set interval of the loop slowed from 0.23 s to 0.9-1.6 s as they went, which is also why the time to the report line varied.
- The same split was there before lane exitleak1's teardown change. Teardown was 1.45-1.52 s against 2.75-2.89 s at 7c9db2e3a6, and 1.44 s against 2.68-2.85 s at 39db83dc56, with 3-4 of 14 runs fast in each: the mechanism predates both.

**Fix**: `WrapperCache` gets `webidl.utils.tombstones.TombstoneGuard`, the guard the instance registries already had.
- Every removal from the map counts, and `set` rehashes in place before an insert once the removals could take half the unused slots. This is WTF::HashTable's policy: `shouldExpand` counts deleted buckets, and `mustRehashInPlace` rebuilds at the same size.
- A rehash moves the map's slots, so it never runs while a walk over the map is reading them: each iteration that calls out takes `beginWalk`/`endWalk`, and an insert during one defers the rehash to the next insert.
- `unlinkCollected` no longer removes and re-inserts a replaced entry: it looks first and removes only its own.
- The entries themselves are separate allocations, so a `*CacheEntry` read before a rehash stays valid.
- Pinned by tests/v8/wrapper_cache_tombstones_test.zig:
  - a shortened gc_bench (24 rounds of 2,048 append/remove plus a collection) ended at capacity 4,096, live 3, free 0, mean miss 4,096 before the fix, and with 2,045 free slots and a mean miss of 1.7 after;
  - a direct put/remove churn;
  - an entry held across a rehash;
  - a walk that inserts.

**Takeaway**: **A bimodal timing whose slow mode costs exactly twice the fast one smells of a probe hitting a table's limit: count the FREE slots, not the load - and give every long-lived std hash map whose keys come and go a TombstoneGuard.**
