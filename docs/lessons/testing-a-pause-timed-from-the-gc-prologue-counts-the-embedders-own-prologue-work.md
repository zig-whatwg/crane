# Testing: A pause timed from the GC prologue counts the embedder's own prologue work - V8's second passes run before it

**Date**: 2026-11-10
**Lesson**: A full-collection pause timed from the first GC prologue callback to the epilogue (v8_wrapper.cpp GCPauses) includes whatever an embedder's later-registered prologue callback does, but not V8's pending second-pass phantom callbacks, which Heap::CollectGarbage runs before any prologue callback. Moving work from second passes into a prologue callback moves it into the measured pause, though the mutator waits for it either way.

**Why**: V8 13.1.203 src/heap/heap.cc Heap::CollectGarbage calls `InvokeSecondPassPhantomCallbacks()` and then `CallGCPrologueCallbacks()`, which run in the order they were added. GCPauses' prologue is added at the isolate's creation (installGCPauseRecorder), the node wrappers' drain prologue (nodeWrappersPrologue) later, at the first node wrap. So the drain's releases, and since lane wr1 batch 8 its anchor frees, are inside the window. P2's equivalent work, its weak Globals' second passes, ran outside it.

**What Happened**: After batch 8 freed scavenge-dropped anchors, gcdiag (100,000 dropped wrappers per forced full collection) still read the tip's pause at 4.8-5.1 ms against main's 1.6-1.7 ms. A diagnostic gc_bench, never committed, timed the drain that a mark-compact's prologue runs: 1.40-1.48 ms at 100,000 drops per collection, 1.54-1.56 ms at 10,000, 0.50-0.55 ms at 1,000. The rest of the gap was the anchors' weak processing for the young generation's wrappers that the full collection itself took (0.68-0.72 ms over about 22,000 slots), and V8's own atomic phases. Decision 7's gc_bench bodies, which drop far fewer wrappers per collection, all stayed inside their limits.

**Fix**:
1. When two designs move work between V8's second passes and an embedder callback, time that work on its own (a diagnostic counter around the callback) before reading a pause ratio as a GC cost.
2. Report the pause and the work inside its window separately, naming the callback order.

**Takeaway**: **A pause measured with callbacks is shaped by the callbacks' order: before comparing two designs' pauses, list what each runs inside the window - the embedder's prologue work is in it, V8's second passes are not.**
