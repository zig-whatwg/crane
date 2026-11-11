# Testing: V8 15.7 advances marking only in its own task - a GC-timing test must run the event loop's engine step

**Date**: 2026-11-11
**Lesson**: On V8 15.7 an external-memory report only STARTS incremental marking; the marking advances in V8's IncrementalMarkingJob task, which runs only when the embedder pumps the platform. A test that runs scripts back to back without the event loop's engine-task step measures collections no browser page has.

**Why**: V8 13.1's `Heap::HandleExternalMemoryInterrupt` advanced and finalized the marking on every report past its soft limit (`AdvanceAndFinalizeIfNecessary`). V8 15.7's `Heap::UpdateExternalMemory` only checks the allocation limits and starts marking (`StartIncrementalMarkingIfAllocationLimitIsReached`); it finishes a cycle at once only when the limit is overshot "by a large margin". Crane's event loop runs V8's posted tasks every turn (src/browser/event_loop.zig step 2b, `engine.runEngineTasks`), as Chrome's task runner does, so a page's cycles finish within a turn or two.

**What Happened**: Lane v8up b3d: tests/v8/external_memory_test "reported memory makes V8 collect dropped wrappers" (600 dropped divs, 1 MB reported each, at least 300 must be queued by their collection) read 302 on 15.7 at 1635a5f250a and 296 after the GlobalAnchor commit cd92f70a04d - deterministic, 3 of 3. A trace of every change of the queued count showed the same three cycles both times, finishing at i = 173, 302, 515 and 169, 296, 506: each 80-130 iterations after it began, on overshoot alone. The anchor's few cppgc bytes moved the cycles ~2% earlier; no object was lost. With the turn's engine-task step in the loop, 17 cycles finished 14-59 iterations apart, 563 were queued by the end, and a forced collection after the loop queued the remaining 37 (600 = 600).

**Fix**: The test's loop runs `engine.runEngineTasks(agent)` after each script, as one event-loop turn does, and asserts after the loop that a forced collection brings the total to exactly 600 - every dropped wrapper queued once. The 300 threshold was not lowered.

**Takeaway**: **A count that depends on when V8 collects is a count of the embedder's pumping as much as of V8: model the event loop's turn (task, then the engine's own tasks), and prove "none lost" with an exact count after a forced collection.**
