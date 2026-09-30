# Debugging: A per-page slowdown with flat native contexts is a table, not a page

**Date**: 2026-09-30
**Lesson**: When one runner process gets slower page after page while `native_contexts` stays flat, no page is being kept whole. What grows is per-page state the process keeps: sample the slow page for time, and diff heap snapshots by type for memory.

**Why**: A leaked realm shows up as a rising `native_contexts`, and the older lessons find its holders (docs/lessons/debugging-find-what-keeps-a-page-alive-count-native.md). Two other kinds of per-page retention never move that count:
- **Tombstones in a process-wide hash map.** `std.HashMap` deletes by tombstone and hands the slot back to `available` (lib/std/hash_map.zig `removeByIndex`). So a map whose inserts and removes balance never grows. Growing is the only thing that clears tombstones on its own. A probe for a new key stops only at a FREE slot, so once the tombstones take the free slots, every insert walks most of the table.
- **Handles to values that belong to no realm.** A leaked `Global<String>` keeps its string alive and nothing else: strings have no native context.

**What Happened**: The 15 variants of encoding/legacy-mb-tchinese/big5/big5-decode.html were run in one process (each as a single-variant copy, so the journal has a record per variant). The first variant took 2.2 s and the thirteenth 46 s; the last two timed out. `native_contexts` was 2 throughout, and the heap after a forced collection rose 1,058 KB per page.
- `sample` on the twelfth variant put 70% of the main thread in `getOrPutAssumeCapacityAdapted` of three address-keyed side tables: EventTarget's internal-state registry, `dom.instance_bridge`, and `InstanceRegistry` (Node, Text, CharacterData, Element). Each page puts ~30,000 nodes into them and removes them again at its end.
- Heap snapshots after page 2 and page 6 differed only in strings held by "(Global handles)": 60,600 more a page. Those are the `dataset` values the test reads. The named property interceptor converted each one to a Global that `setReturnValue` only reads into a Local, and released none of them. The indexed getter and the named descriptor did the same (measured: 64 reads left 2,048, 2,048 and 4,096 bytes of global handles), and so, by reading the code, did the named query.

**Fix**:
1. `webidl.utils.tombstones.TombstoneGuard` counts removals, which bound the tombstones. Before an insert it calls std's in-place `rehash` once the removals could take half the unused slots. It never rehashes on removal, because owners remove entries while they iterate. InstanceRegistry, `dom.instance_bridge` and EventTarget's registry use it.
2. The interceptors release what they made, gated by `getterValueIsOwned`, the allowlist the attribute getters already used. It is now file-level and its default ("kept") is pinned in tests/v8/retention_predicate_test.zig.

Measured separately:
- With the rehash alone, all 15 variants took 2.1-2.4 s and all passed (14,651 subtests; before, the last two timed out). The heap still rose 1,058 KB a page.
- With the release added, the heap went 8,658 KB at the first variant to 8,722 KB at the twelfth.

To take such a curve, copy the page into `tests/wpt/crane/` once per variant (one `<meta name="variant">` each, absolute resource URLs) and run the copies in order in one process under `CRANE_HEAP_GC=1`. The journal's `wall_ms`, `heap_used_kb` and `native_contexts` per record are the curve.

**Takeaway**: **Flat native contexts with a rising curve means the process keeps something per page that is not a page: sample the slow page before theorising, and diff snapshots by type - a process-wide table and a realm-less handle are both invisible to the realm count.**
