# Architecture: An argument the callee must free leaks on the path that forgets

**Date**: 2026-09-29
**Lesson**: A callback interface argument (`*runtime.CallbackWrapper`) used to be handed to the impl to free, on every path. EventTarget freed the engine half and never the runtime half, and that half was a whole 16 KB page. Arguments are now borrowed for the call and the binding frees them; an impl that keeps the callback takes a value of its own.

**Why**: "The method that receives a callback owns it" means every impl, on every path (success, early return, error), has to free two objects correctly. The binding made two: the V8 CallbackWrapper and a runtime struct pointing at it. Both came from `std.heap.page_allocator.create`, which maps a whole page for a 40-byte struct. EventTarget called `wrapper.deinit()`, which freed only the V8 half. XPath and MediaQueryList never freed anything. Only node_filter freed both.

**What Happened**: Every `addEventListener` and `removeEventListener` call leaked one page for the runtime struct. gc_bench measured it with `--body=globalThis.f ??= () => {}; document.addEventListener('x', f); document.removeEventListener('x', f);`: 34,692 resident bytes per cycle before, two pages a cycle (669.4 MB over 20,000 cycles), and 1,930 after (44.3 MB). Nothing reported it. `std.testing.allocator` never saw a page_allocator allocation, and the V8 live-handle counters were flat because the V8 half was freed.

**Fix**:
1. `runtime.CallbackWrapper` is opaque (the adapter's own object) and BORROWED for the call, like every argument (AGENTS.md "The engine boundary", rule 3). The binding releases it in `freeConvertedArg` (`conversions.releaseCallbackWrapper`), so `CallbackOperations` and `v8_engine_interface` are gone.
2. An impl that keeps the callback takes its own value with `engine.takeCallbackInterface` (EventTarget, node_filter).
3. An attribute that gives the callback back (NodeIterator.filter, TreeWalker.filter) returns the callback's object: codegen types a callback interface attribute as `runtime.JSValue`.
4. The wrapper comes from `conversions.callback_allocator` (c_allocator). A test swaps in `std.testing.allocator`, and listeners added and removed in a loop then fail the test if any wrapper survives its call.

**Takeaway**: **Make arguments borrowed and let the keeper take its own copy. And never `page_allocator.create` a small object: it costs a page, and no allocator-level leak check sees it.**
