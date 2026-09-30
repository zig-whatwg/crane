# Architecture: A stored pointer is a Global only if a Global was stored

**Date**: 2026-09-29
**Lesson**: `engine.retainValue` reads a `.handle`'s pointer as a `Global<Value>*`. A getter that wraps a stored `*anyopaque` in `JSValue.fromHandle` and retains it crashes unless the thing stored really was a plain Global. A tagged callback-function handle, IndexedDB's serialized bytes and a platform object's Instance pointer all were stored that way.

**Why**: Part B made the binding release every value an impl returns, so a getter of a kept value returns `engine.retainValue(realm, kept).take()`. Before that, the getter handed the stored pointer to the binding as a borrowed `.handle`. The binding set it as the result without dereferencing anything that faulted. A wrong pointer came back as `undefined` or garbage, and the subtest failed quietly. `retainValue` makes a new Global from the old one, which dereferences the pointer, and a pointer that is not a Global kills the process.

**What Happened**: job42's full sweep of part B at 857998b92 turned six custom-elements files from OK or ERROR into CRASH. `valid-custom-element-names.html` alone went from 1975 passing subtests to a crash. `customElements.get()` and `whenDefined()` returned the definition's constructor through `fromHandle(def.constructor)`. `def.constructor` is `define()`'s callback-function argument as the binding converted it: a Global whose address carries a tag in its low bits (`pointer_tag.tagPointer(..., .global_handle)`, conversions.zig), so it is misaligned when read as a Global. An audit of every `fromHandle(@constCast(...))` of a stored pointer found the same shape three more times:

- `IDBCursorWithValue.value` handed over IndexedDB's serialized record bytes.
- `NavigateEvent.info` stored `JSValue.toAnyopaque()`, which is an Instance pointer for a platform object.
- `XSLTProcessor.setParameter` stored the same `toAnyopaque()` result.

**Fix**:
1. Read a callback-function argument through `engine.takeCallbackFunction`, which untags it. Retain the function from the result (`CustomElementRegistry.constructorValue`).
2. Keep only `.handle` values as handles (`XSLTProcessor`), or keep an `engine.Owned` made by `retainValue` at store time. The navigation lane's NavigateEvent rewrite does the second: `hold()` retains a platform object as its wrapper.
3. Where the stored thing is data, not a value (IndexedDB bytes), the getter must deserialize it. Until then it throws `NotImplemented` rather than pretending the bytes are a handle.

**Takeaway**: **Store an `engine.Owned`, never a `*anyopaque` you will later call a handle.** If the type that holds a value cannot say what it is, a later reader will guess. Every getter that reads a stored pointer through `fromHandle` is a guess.
