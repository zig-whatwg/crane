# Architecture: V8 13.1 never frees a CppHeap given at isolate creation

**Date**: 2026-11-08
**Lesson**: `Isolate::CreateParams::cpp_heap` documents "V8 takes ownership of the CppHeap passed this way", but 13.1.203 never frees it. The header comment describes the API's intent, and the linked version's source is what decides who frees the object.

**Why**: In 13.1.203, `Heap::ConfigureHeap` puts the heap in `owning_cpp_heap_`. `Heap::StartTearDown`, inside `Isolate::Dispose`, then calls `owning_cpp_heap_.release()`, detaches the heap and terminates it, and nothing deletes it: `Heap::TearDown` finds `cpp_heap_` already null. V8 13.4.100 changed that line to `reset()` (1c079f473b1, "[cppheap] Change order of CppHeap teardown calls"). The commit message talks about teardown order and says nothing of a leak, so the fix is easy to miss in a changelog. Chrome at V8 13.1 (Blink's ThreadState) attached the heap with `AttachCppHeap` and owned it itself, so the CreateParams path had no browser user at that version.

**What Happened**: The wrapper redesign's design (section 4.9 step 5) said V8 owns and destroys the heap with the isolate. Lane wr2 read StartTearDown at the linked tag before relying on it (lesson debugging-read-the-linked-v8-patch-version.md): one heap would leak per agent, which means every Browser and every worker. Reading the same file at 13.1.203 also showed that V8 never calls `cppgc::InitializeProcess`. It is the embedder's job: Chromium's gin::InitializeCppgcFromV8Platform, V8's cctest. Without it, `CppHeap::Create` reads a CagedHeap that was never made.

**Fix**:
1. The adapter's per-isolate record also owns the heap (`IsolateData::cpp_heap`, a unique_ptr) and passes `.get()` in CreateParams.
2. The record is deleted after `Isolate::Dispose` returns, so the heap is freed once it is detached and terminated, and a failed creation frees it unused.
3. `static_assert(V8_MAJOR_VERSION == 13 && V8_MINOR_VERSION < 4)` makes an upgrade revisit the double ownership: from 13.4 on, V8 frees the heap itself.
4. `cppgc::InitializeProcess` runs once, in V8's start, with V8's platform's page allocator.
5. The proof is not `leaks --atExit`. It reported 0 leaks for the build that never frees the heap, the same as for the base, because the abandoned heap is still reachable from cppgc's process-wide heap registry: every HeapBase registers in its constructor and unregisters in its destructor (13.1.203 src/heap/cppgc/process-heap.cc). The registry's size is the measure. tests/v8/cpp_heap_test.zig counts it around createAgent and destroyAgent (`v8_test_CppgcLiveHeaps`, a test-only read of `HeapRegistry::GetRegisteredHeapsForTesting`): red on that build, green with the record's ownership.

**Takeaway**: **"Takes ownership" in a V8 header is a promise of the API's latest version: for every object you hand V8, read who deletes it in the linked tag's teardown, and pin what you find with a version assert. An object that is never freed but still referenced from a registry is invisible to `leaks`: count the registry instead.**
