# Architecture: A collector callback that cannot hold its agent finds it through the collecting isolate - not a global, not a link-time export

**Date**: 2026-11-09
**Lesson**: When a GC object is too small to carry a pointer to its agent, the per-agent state it needs is reached through the isolate the collection runs on (V8's current isolate in the atomic pause, as Blink's Trace reaches ThreadState::Current()), with a check that it IS the collecting one - and every host entry that starts a collection outside script enters that isolate first.

**Why**: Crane's node anchor is 16 bytes (cppgc's header and one slot pointer); one more pointer makes it 24, on every wrapped node. Its Trace still needs its agent's record (the Zig callbacks, the walk's per-collection visited set). Two shortcuts fail: an `export fn` from the adapter's Zig is compiled into every binary that imports the module - a module-only test binary (`test src-dom`) that links no V8 then fails to link (undefined `v8_Isolate_GetCurrent`, `v8_Isolate_NodeWrappers`) - and a process-wide function pointer is new global state, which the global-state baseline forbids. The collection itself knows its isolate: V8 runs the pause on the isolate's thread, and Crane can make sure that isolate is the current one.

**What Happened**: The wrapper redesign's P5 first called the walk through an `export fn`; the oracle run over tests-dom found the link error. The second proposal, a reviewed process-wide atomic pointer, was refused (the baseline only goes down). The integrator's shape: `Isolate::TryGetCurrent()->GetData(slot)` gives the record; NodeAnchor::Trace takes it only after checking that the current isolate's CppHeap handle is the anchor's heap and that heap is in its atomic pause (abort otherwise). Requested collections, heap snapshots, external-memory adjustments and V8 task pumping (IncrementalMarkingJob::Task finalizes collections) now enter their isolate when it is not current (`CollectingScope`). tests/v8/wrapper_walk_test.zig collects each of two agents on one thread while the other is current: each walk counts only in its own registry.

**Fix**:
1. Per-agent callbacks live in the isolate's record; the GC object reaches the record through the current isolate, checked against its own heap.
2. Every C entry that can start a full collection enters its isolate if another (or none) is current, and leaves after.
3. A test with two agents on one thread, each collected while the other is current.

**Takeaway**: **Per-agent state belongs to the agent's record; a collector callback finds it through the isolate being collected and checks that it is - never through a global, and never through an `export` that every importer of the module must then be able to link.**
