# Testing: gc_bench never scavenges, so it cannot show a wrapper V8 drops in a young-generation collection

**Date**: 2026-11-10
**Lesson**: gc_bench's `--gc` forces two full collections after every batch, and in this tree no young-generation collection ever runs in it. `minor_gc_count` stayed at 3 from start to end in every body, even with 100,000 createElement in one batch. So anything only a scavenge does - since the wrapper redesign's P8, dropping an unmodified wrapper that only its droppable TracedReference reaches - never happens there. Measure such cases in the release console, the page's own run shape.

**Why**: The redesign's P8 makes a node's wrapper slot a droppable TracedReference (v8_wrapper.cpp, `IsDroppable`). V8 may then reclaim an unmodified API object in a scavenge when nothing else reaches it, and the adapter frees its anchor eagerly. A full collection does not drop it: the tree walk keeps every wrapper of a live tree. So the bytes a wrapped-but-unreferenced node costs depend on whether scavenges ran, and gc_bench's harness shape decides that, not the engine.

**What Happened**: Lane nodedata batch 1 reconciled a byte map with tests/perf/elements.json, where an attached div costs 422 B and a detached one 492. gc_bench put the attached div at 500.7 and the detached one at 504.5: no gap at all. The release console, running elements.js's own steps, gave attachedDiv 431.7 and a new case, attachedKept (the same divs, also stored in the JS slots), 487.2. Keeping a JS reference restores the detached figure. malloc_history in the console at the after-reading confirmed the drop: 2.46 B of TracedNode per attached div against 16.23 for a kept one, and 1.37 B of registry against 10.55. About 85% of the attached divs' wrappers had been dropped. Each drop leaves its CppHeapPointerTable entry until a mark-compact, so the V8 region does not fall by the full wrapper cost.

**Fix**:
1. For any figure that depends on the young generation, measure in the release console with the page's steps (tmp/redesign/nodedata .nodedata/con.sh: vmmap at two marks, `MSL=1` for malloc_history).
2. Read `minor_gc_count` in gc_bench's counters before trusting a gc_bench figure for such a case.
3. Pair every "unreferenced" case with a kept twin (attachedKept), so the gap is measured, not inferred.

**Takeaway**: **A harness that forces full collections hides everything the young generation does. Check the scavenge count before comparing gc_bench with a page, and pair each unreferenced case with a JS-kept twin.**
