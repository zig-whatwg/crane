# Architecture: A wrapped API object keeps a CppHeapPointerTable entry until the next full collection

**Date**: 2026-11-10
**Lesson**: Under V8's sandbox, `Object::Wrap` gives every wrapper an entry in the isolate's CppHeapPointerTable. Only a mark-compact frees an entry (V8 13.1.203 src/sandbox/cppheap-pointer-table.cc SweepAndCompact, called only from mark-compact.cc; still one space, swept only there, in V8 14.6 main). A wrapper a scavenge drops, and whose C++ side is freed at once, still leaves 8 bytes behind until a full collection - and the faster everything else is freed, the rarer the full collections that would take them.

**Why**: The table has no young space and the scavenger never touches it. Wrappers that carry their C++ pointer in an internal field (Crane's P2) have no entry at all. Nothing in V8's GC scheduling reads the table's size, so its growth does not bring the full collection that would shrink it.

**What Happened**: Lane wr1 batch 8 freed each scavenge-dropped wrapper's NodeAnchor after the scavenge, and gc_bench showed the C++ heap staying flat. The churn probe (8 rounds of 260,000 dropped divs in the release console) still grew: 102 -> 128 MB, against main's 96 -> 99/101. gc_bench at the probe's scale, with the event loop turned after each batch (`--loop`), separated it. Freed 2,059,262 of 2,059,262 anchors, 0 waiting, malloc and Zig-side bytes flat (15.5 -> 16.3 MB, 11.3 MB), C++ heap 0.6 MB, one full collection - yet resident memory climbed 8.6-8.9 B per element (70.3 -> 91.1 MB), while main stayed flat (70.5 -> 73.9). One table entry is 8 bytes.

**Fix**: none inside the adapter's rules for that batch. A GC flag, an artificial external-memory figure or a special case would each meet the condition without fixing the cause. Blink pays the same cost: every ScriptWrappable is Wrapped. The options belong to the integrator: accept it against P2's figure, or design a pointer to the C++ side that V8's marker follows without a table entry.

**Takeaway**: **Freeing an object's C++ side early frees only what you own: list every engine structure the object's creation filled (handles, table entries, remembered sets) and when the engine itself frees each one, before calling a footprint flat.**
