# Architecture: V8 15.7 gives every aligned pointer in an internal field a cppgc object of its own

**Date**: 2026-11-10
**Lesson**: Since V8 d04704a20fc (in 15.7.112.43), `Object::SetAlignedPointerInInternalField` and `Context::SetAlignedPointerInEmbedderData` allocate a cppgc `EmbedderDataSlotWrapper` on the isolate's CppHeap for every non-null pointer. A wrapper that keeps its instance in internal fields now costs a heap object per field. Only `Object::Wrap` stores a CppHeap pointer with no extra object.

**Why**: Under the V8 sandbox, embedder data slots and internal fields now hold CppHeapPointerTable handles instead of ExternalPointerTable handles ("[sandbox] Store CppHeapPointerHandles in EmbedderDataArray", bug 534317475). A raw C++ pointer does not live on the CppHeap, so V8 boxes it: `EmbedderDataSlot::store_aligned_pointer(isolate, DirectHandle<T>, index, ptr, tag)` runs `cppgc::MakeGarbageCollected<EmbedderDataSlotWrapper>(ptr, tag)` (src/objects/embedder-data-slot-inl.h:212-227; api.cc:6361-6372 calls it). Nothing in an `#ifdef` turns it off. The commit says "Future CLs will introduce a new API that allows storing CppGC pointers directly": V8 is steering embedders to `Object::Wrap` and `v8::Object::Wrappable`, which is Blink's model.

**What Happened**: In lane v8up batch 3, the first tests/v8 run on 15.7 failed cpp_heap_test's "a fresh agent's heap holds nothing" with 128,952 bytes. V8 allocates on the CppHeap it owns: its default MicrotaskQueue, `Managed<T>`'s `CppGCManagedWrapper`, and the slot wrappers. Reading why turned up the slot wrapper. Crane's `setInstanceWithTypeInfo` (interface.zig) stores two aligned pointers per platform-object wrapper: the instance and the WrapperTypeInfo. On 15.7 that is two cppgc allocations per wrapped object, about 24 B each, plus the major-GC work to mark and sweep them. On 13.1 the same stores cost two ExternalPointerTable entries.

**Fix**: Measure before deciding: gc_bench, and the perf pair's per-node bytes, on the 15.7 runner against 13.1. Two ways to remove the cost:
- An interim fix inside the adapter: make field 1 a Smi index into a WrapperTypeInfo table (`SetInternalField(1, Integer)` allocates nothing). That halves the cost.
- The full fix: wrap with `Object::Wrap(isolate, wrapper, wrappable, tag)`, one CppHeap pointer to a `Wrappable` (lane wr1's anchor), with the type check done by the tag range as Blink does. A realm's global follows the same path through `Object::WrapGlobal` (tmp/plans/v8-global-object-design.md 3.3).

**Takeaway**: **On V8 >= 15.7 an aligned pointer in an internal field is not free: each one is a cppgc object. Store one CppHeap pointer through `Object::Wrap`, and keep anything static (type info) out of pointer fields.**
