# Debugging: cppgc scans the stack - a stale pointer keeps a C++-heap object through a collection

**Date**: 2026-11-09
**Lesson**: A unified-heap collection started without a stack state scans the native stack conservatively for C++-heap pointers, and a dead frame's leftover word can keep an object - and everything it traces - alive for that cycle.

**Why**: V8's heap finds its roots precisely, so Crane's wrappers never depended on what the C stack held. cppgc does not: `MarkerBase::EnterAtomicPause` visits the stack when the heap's embedder stack state is `kMayContainHeapPointers`, the default for every collection V8 starts outside a task. The scan reads every word between the collector's frame and the stack's start. Frames that returned earlier leave their spilled locals in memory the collector's own frames then cover without writing every slot, so a pointer the code dropped long ago can still be read there.

**What Happened**: In the wrapper redesign's P4 a node wrapper points at a NodeAnchor on the agent's CppHeap, and the anchor's Trace keeps the wrapper's TracedReference. tests/v8/node_wrapper_inline_test.zig wraps a node directly (template_registry.wrapInstanceAsV8Object, whose v8_NodeWrapper_Attach holds the new anchor in a local), returns, and collects through `v8_Isolate_RequestGarbageCollection` (LowMemoryNotification). The wrapper nothing reached survived, 2 of 2 runs ("the new wrapper, unreached, goes the same way" failed: the slot was not empty). The anchor's address was still in a dead C++ frame below the collection's, and the scan treated it as a root. P2's weak `Global`s never had this exposure: V8's handles are not found by scanning.

**Fix**:
1. A requested collection is precise for the C++ heap: `v8_Isolate_RequestGarbageCollection` runs LowMemoryNotification under `cppgc::testing::OverrideEmbedderStackStateScope(heap, kNoHeapPointers)`. That is safe only because no Crane frame holds a C++-heap pointer across a requested collection: anchors and their registry are held by wrappers and a `cppgc::Persistent`, and their raw pointers live only in v8_wrapper.cpp frames that never call a collection. Write that argument down beside the call, and keep it true.
2. Collections V8 starts itself keep its default. A scanned stale pointer there only delays a wrapper by a cycle; it never frees anything early.
3. Tests that must see an object die collect precisely (`v8_test_Isolate_CollectWithoutDrain`, the P3 probe's `v8_test_CppHeapProbe_Collect`).
Chromium's web-test collector makes the same choice when its stack is known clean (content/web_test/renderer/gc_controller.cc `AsyncCollectAllWithEmptyStack`: `kNoHeapPointers`).

**Takeaway**: **Once a reachability decision moves onto cppgc, the native stack is a root. A collection that must be exact needs a precise stack state, and the claim that it is safe is a property of every frame, so write it beside the call.**
