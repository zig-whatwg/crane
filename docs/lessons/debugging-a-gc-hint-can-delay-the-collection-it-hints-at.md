# Debugging: A GC hint can delay the collection it hints at - count before trusting it

**Date**: 2026-11-06
**Lesson**: In V8 13.1, `Isolate::ContextDisposedNotification(false)` (a top-level context let go) resets the old-generation and global allocation limits to their INITIAL size. On a small heap that limit is higher than the one V8 had computed, so the next collection comes LATER, and the navigated-away pages it was meant to free stay alive.

**Why**: Blink calls the notification when a main frame's context is disposed (`LocalWindowProxy::DisposeContext` -> `V8GCForContextDispose::NotifyContextDisposed` -> `ContextDisposedNotification(!is_main_frame)`). It pairs it with an idle-time collection shortly afterwards (`V8GCForContextDispose::NotifyIdle`), and the rest of Blink's scheduling relies on V8's memory reducer, whose delayed tasks fire seconds later. The notification alone only says "the old limits no longer describe this page" (13.1 `Heap::NotifyContextDisposed`: `ResetOldGenerationAndGlobalAllocationLimit()`, `memory_reducer_->NotifyPossibleGarbage()`).

**What Happened**: Lane perf1's DOM external-memory report left perf round 1's load.docs chain (10 loads of a 27.5 MB-DOM page in one tab) at 301-371 MB against main's 219. A diagnostic console printed per commit: native contexts, V8 heap, V8 external, the DOM figure, the queue. The counts showed navigated-away realms waiting for a collection once V8's limits had grown. The fix copied Blink's call into the adapter's detach. Its test passed: V8's disposal count moved. Then the same counted chain showed the following:
- with the report, contexts still climbed to 5 (279 MB);
- without it, i.e. main plus the hint, NO old page was ever collected: contexts 1 -> 10, DOM 249 MB, footprint 576 MB.
The fix was reverted (78b545f89e6).

**Fix**: Judge a GC hint by what it makes the collector do, counted (native contexts, live nodes, the engine's own external figure per step), on both arms: with the change and without the mechanism it is meant to complement. A test that the hint was delivered proves only the call. Read the engine's handler for the version you link (`git show <tag>:src/heap/heap.cc`) before copying another embedder's call: Blink's design is the call plus its idle GC.

**Takeaway**: **A hint changes the collector's limits, not just its timing. Count the objects it is meant to free, with and without it, before keeping it: "the engine was told" is not "the engine collected".**
