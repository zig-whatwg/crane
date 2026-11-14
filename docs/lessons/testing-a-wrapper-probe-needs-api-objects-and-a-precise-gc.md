# Testing: A wrapper probe needs API objects and a precise collection

**Date**: 2026-11-11
**Lesson**: A probe of V8 wrapper costs must make its objects the way the embedder does - from a FunctionTemplate's instance template - and must drop them with nothing on the stack or in an open HandleScope. Otherwise it measures a crash, or objects that never died.

**Why**: An `ObjectTemplate` with no constructor FunctionTemplate makes ordinary JS objects, which have no CppHeap pointer slot for `Object::Wrap` to write. Separately, a Local in an enclosing HandleScope is a root, and a collection with a conservative stack scan keeps whatever a stale stack slot names.

**What Happened**: Lane wrap1 batch 1 wrote a standalone C++ probe against the installed V8 15.7 archive to price each wrapper shape. Its first run crashed on `Object::Wrap` for every variant with no internal field (Bus error): the objects came from a bare ObjectTemplate. Its second printed "after drop: cpp 24.00" and "weak_reset 0": the array Local of the making loop sat in main's HandleScope, so nothing had died and every "dropped" figure was a kept one.

**Fix**: `FunctionTemplate::New(isolate)->InstanceTemplate()` for the objects; a HandleScope around the making loop; `RequestGarbageCollectionForTesting(kFullGarbageCollection, StackState::kNoHeapPointers)`. Then check that the drop row returns to the baseline (C++ heap 0.00, every weak handle reset) before reading any other row.

**Takeaway**: **A memory probe's first check is its own drop: if "after" is not back at the baseline, nothing it measured was garbage.**
