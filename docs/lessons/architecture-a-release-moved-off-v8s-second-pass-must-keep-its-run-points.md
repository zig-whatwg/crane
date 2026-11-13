# Architecture: A release moved off V8's second pass must keep the pass's run points

**Date**: 2026-11-09
**Lesson**: V8 runs second-pass weak callbacks at three points - the next collection's start, a forced collection's end, and a posted task - and code that relied on the pass relied on all three.

**Why**: 13.1 `Heap::CollectGarbage` first runs the second passes still pending ("Ensure that all pending phantom callbacks are invoked"), then the prologue callbacks. `GlobalHandles::PostGarbageCollectionProcessing` runs them synchronously after a collection made with the Forced, CollectAllAvailableGarbage or SynchronousPhantomCallbackProcessing flags, and otherwise posts one foreground task. During a long script the task cannot run, so the GC-start point is the one that keeps releasing.

**What Happened**: The wrapper redesign's P2 released a collected node wrapper's counted reference in V8's second pass. P4 moved node wrappers to cppgc anchors, which have no second pass: their weak processing records the releases in the atomic pause, and the drain had to be scheduled by hand. The first version posted a task after each full collection, plus a drain at a requested collection's end. tests/html/rc9_document_tasks_test.zig then failed: 600 documents made and dropped inside one script grew the slab by 425,850 slots against its bound of 300,000. No release ran until the script ended, so no tree reached the queue, and the queue's memory bound never applied. tests/v8/external_memory_test.zig's "V8 collects dropped wrappers with no forced collection" failed the same way.

**Fix**: The drain runs at V8's three points:
1. a GC prologue callback for every collection type (it drains if a collection found anchors dead);
2. the full-collection epilogue, synchronously when the flags are the forced ones;
3. otherwise one posted foreground task, dropped unrun if the agent ends first (its end drains everything).
tests/v8/node_anchor_test.zig pins the epilogue order, the pending task at the agent's end, and the drain by the event loop's pumping.

**Takeaway**: **Before replacing a mechanism the engine schedules for you, write down every point at which it runs; each one is something the old code relied on, and the hand-made replacement must keep them all or show why one is not needed.**

**Status (2026-11-13, lane wr1 batch 11)**: the three run points are gone. Node wrappers' releases join lane v8up's finalizer queue in the collection that found them dead, and run at the agent's safe points (a binding's return into script, the pump, a requested collection's return) - which run at least as often as the three points did, and no longer depend on V8's second pass at all (it becomes synchronous under Isolate::SetMemorySaverMode). What had kept the old timing was refcount step 7a's net, closed in the same batch (tests/v8/wr11_net_hole_test.zig). One of the three points turned out to carry a second job and needed its own replacement: the posted task also retried the explicit frees cppgc had refused, so the pump now retries them after a task has run (v8_wrapper.cpp `oweWaitingAnchorFrees`, tests/v8/wr8_anchor_free_test.zig). The lesson's method stands - list every point a mechanism runs at before replacing it - with an addition: list every JOB each point did.
