# Architecture: A weak handle is armed on a Local of the object, never on one of our Globals

**Date**: 2026-10-11
**Lesson**: `v8_Value_ToWeakGlobal` takes a Local's slot (`v8_Global_Get`'s result); handed one of the wrapper's `Global<T>*` it arms the weak handle on whatever the Global's first word reads as, which V8 never collects, so the callback never fires and what it was meant to free lives for the agent's life.

**Why**: The wrapper hands Zig two kinds of pointer that look alike. A `v8_*` call's result is a heap `Global<T>*` (a pointer to a struct holding the handle's slot pointer). A Local is the slot pointer itself (`v8_Global_Get` escapes one into the caller's HandleScope). `v8_Value_ToWeakGlobal(isolate, local, ...)` reinterprets its argument as a Local: given a `Global<T>*`, the "slot" it reads is the Global struct, whose first word - the address of the global handle node - is aligned, so V8 reads it as a Smi. The weak handle it makes points at a Smi: never collected, never reset, never called back.

**What Happened**: intl_binding.zig's `setupWeakCallback` passed `v8_Object_New`'s Global straight to `v8_Value_ToWeakGlobal`. Every Intl object's registry entry was meant to be removed by that callback when the object was collected; none ever was. Together with the object's own result Global (never disposed) and its per-object FunctionTemplates (cached in the context for its life), no Intl object was ever collected, and every entry - three `std.heap.page_allocator` pages each - stayed until the host agent ended: gc_bench read ~50 KB of RSS and +224 B of global handles per `new Intl.Collator()` (lane callleak, lane intlleak). The weak handle on the Smi itself was one more live Global per object.

**Fix**: `if (v8.v8_Global_Get(isolate, @ptrCast(object))) |local| cell.weak = v8.v8_Value_ToWeakGlobal(isolate, local, cell, cellCollected);` (intl_binding.zig `adopt`), the shape tests/v8/weak_callback_ownership_test.zig already used. tests/v8/intl_object_lifetime_test.zig pins that a dropped Intl object's state is freed by a collection.

**Takeaway**: **A function that takes a `local: *anyopaque` wants `v8_Global_Get`'s result; passing it a `v8_*` result type-checks and silently makes a handle to nothing - test that the callback fires, not only that it was armed.**
