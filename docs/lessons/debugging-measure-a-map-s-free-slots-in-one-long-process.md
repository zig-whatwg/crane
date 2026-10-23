# Debugging: Measure a map's free slots in one long process, and lint the rest

**Date**: 2026-10-23
**Lesson**: Whether a long-lived std hash map loses its free slots is a property of its keys and its owner's lifetime, not of any one page: measure it in ONE long runner process over a worklist sample, and let `zig build lint-tombstones` keep every map that removes from itself in view.

**Why**: std.HashMap deletes by tombstone and never counts one against its load (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`). A map whose puts and removes balance never grows, and growing is the only thing that clears tombstones. An insert of a key the map never saw takes a FREE slot unless a tombstone lies on its probe path, and nothing gives one back, so free slots fall toward zero; then every insert of a new key and every lookup that misses walks the whole table. Three things decide whether a map gets there:
- its keys: increasing ids (timers), fresh UUIDs (blob URLs) and addresses that are not reused (instances kept by the deferred teardown queue) are new every time; a key that comes back (a localStorage name, a reused allocation) reuses its own tombstone and costs nothing;
- its lifetime: a map that outlives a page sees every page's removals; one that is cleared or freed at a natural boundary (`clearRetainingCapacity`, `clearAndFree` when empty) starts over;
- its peak: one page that puts thousands of entries grows the table, and every later miss walks that capacity.

**What Happened**: Lane hashmaps1 instrumented 20 candidate maps (a temporary patch printing capacity, live, free and the mean miss probe at inserts) and ran a 1-in-12 worklist sample, 1,069 files, in one Debug runner process:
- NativeTimerManager.timers - one per Browser loop, ids only grow - sat at capacity 32 with NO free slot in 4,287 of 4,814 samples: every setTimeout and every clearTimeout of a fired id walked all 32.
- The window's timer_contexts, the custom element agent's pending reactions, the option state table, IDBServer.databases, the wrapper cache's edges_before_wrap (capacity 16,384, 73 free) and pending_before_wrap, and the tree scope's ID map all starved in some samples.
- The HTTP cache, the preflight cache and the blob URL store never did in the sample - their caps were never reached and few blob URLs were made - but a churn test that drives each owner to its steady state (a cache at its cap evicting for every insert) took them to capacity 128 or 16 with none free.
- The callback registry (freed when its last wrapper goes), the agent's element map (cleared whenever the agent is quiescent) and storage bottles (keys repeat) were empty or stable at every sample.

**Fix**:
1. `infra.tombstones.TombstoneGuard` (moved from webidl.utils so fetch, file and storage reach it; managed and unmanaged maps) on every map whose churn is real: `noteRemoval` after every removal, `beforeInsert` just before every insert of a possibly new key (after `ensureUnusedCapacity`, which a rehash keeps), `reset` where the map is cleared, never a rehash on removal.
2. Before guarding, prove two things per map, because a rehash moves every entry: no insert can happen while an iterator over the map is live (timer poll fires from a snapshot of due ids; reactions are taken out by lookup, one at a time) - test it by inserting from inside the callback under a forced rehash; and no `*V` from `getPtr`/`getOrPut` is held across an insert (heap nodes behind pointers, as the HTTP cache keeps, are safe).
3. A threadlocal map gets its guard as a FIELD: the variable's type becomes a struct of map and guard (same global-state key, no new variable).
4. `zig build lint-tombstones` (tools/lint_tombstones.zig, part of `zig build test`) flags every container field or container-level var std hash map its file removes from - by name, through a local bound to it, an if/while capture, or a function returning it - with no guard and no `// tombstones: <why>` exemption; tools/tombstones_baseline.txt only goes down.
5. `infra.tombstones.meanMissProbe` measures a table key-independently: the mean distance from each slot to the first free one.

**Takeaway**: **A map's free slots are decided by whether its keys come back and how long it lives, not by the page in front of you: measure them in one long process, drive each owner to its steady state in a test, and let lint-tombstones flag the next map that removes from itself without a guard.**
