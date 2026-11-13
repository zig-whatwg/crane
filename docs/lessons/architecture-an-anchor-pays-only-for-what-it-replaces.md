# Architecture: On V8 15.7 an Object::Wrap anchor pays only for what it replaces

**Date**: 2026-11-13
**Lesson**: A `v8::Object::Wrappable` anchor per wrapper costs exactly what V8 15.7's own box for one aligned pointer costs, so moving a wrapper's instance from an internal field to `Object::Wrap` saves only the field - unless the anchor also replaces something else the wrapper carries.

**Why**: Since V8 15.5, `SetAlignedPointerInInternalField` boxes the pointer in a cppgc `EmbedderDataSlotWrapper` `{void*, tag}` (15.7.112.43 src/objects/embedder-data-slot-inl.h:209-227): 16 B and an 8 B header, plus a CppHeapPointerTable entry. A Wrappable has a vptr (it is a `cppgc::NameProvider`), so a minimal anchor `{vptr, instance}` is also 16 + 8 and also needs one table entry. The wrapper itself loses the 8 B field.

**What Happened**: Lane wrap1 measured it twice. Batch 1's standalone probe (chat2, 1,000,000 wrappers, resident bytes per wrapper): two fields and a pointer 92.9 B; two empty fields and an anchor 93.5 B; no field and an anchor 78.5 B. Batch 2 moved every non-node platform object's wrapper in the engine (v8_wrapper.cpp PlatformAnchor; tests/v8/wrap1_platform_anchor_test.zig): a kept Event wrapper went 24 -> 16 B of V8's heap and stayed 24 B on the C++ heap. The two places where the move paid more were both things the anchor REPLACED: a holder of nodes (a NodeList, an HTMLCollection) had V8's box for its field AND wr1's HolderAnchor, 56 B of C++ heap, and now has the one anchor, 32 B; and the wrapper cache's weak handle, callback record and entry - about 200 of the 312-320 B a kept non-node wrapper costs - which is the next batch's work, because only an anchor of our own can hold a traced reference to its wrapper.

**Fix**:
1. Before moving an object's native pointer onto the engine's heap to save memory, write the per-wrapper table by owner (the engine's heap, its C++ heap, its pointer tables, its handle nodes, your malloc, your records) and mark which rows the move deletes. The pointer's own row usually moves, not disappears.
2. Give templates no internal field once nothing reads one, and store no second pointer: Crane's brand check is the instance's state ancestry, so the tag names the wrapper's kind only.
3. Look for a second engine-heap object the wrapper already carries (here the holders' anchor): one object can do both jobs.

**Takeaway**: **Before moving an object onto an engine's heap to save bytes, list what the move replaces. The bytes are in the machinery it retires, not in the pointer it moves.**
