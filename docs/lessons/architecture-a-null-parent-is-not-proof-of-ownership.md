# Architecture: A null parent is not proof of ownership

**Date**: 2026-09-21
**Lesson**: `DomTreeAdapter.deinit` decided what to free by re-reading
`getParent(node) == null` over every node the parser had ever created.

**Why**: The adapter's map outlives the nodes in it. A node the parser attached
belongs to V8 from that moment - the wrapper cache holds it and a weak callback
can hand its Instance handle back to the slab whenever. And a recycled handle
still *looks* like an Instance: `SlabAllocator.free` overwrites only offset 0
(the vtable, with the free-list link) and `alloc` re-stamps `state` and `ctx`
with `undefined`, which is 0xAA bytes in a safe build. Nothing about the 24
bytes says "this is not the node you mapped".

**What Happened**: on a document big enough for one GC during the parse, the
sweep followed a recycled pointer into an instance belonging to a context that
had already been torn down, and `markInstanceCleanedUp` panicked at
`@ptrCast(@alignCast(cache_storage))` with `incorrect alignment` - the
`_v8_wrapper_cache_storage` it read came out of freed memory, and `0xAAAA…AAAA`
is not null, so `orelse return` passed it straight to `@alignCast`. Roughly 40
crashes in `encoding/*-encode-form-*` alone. The same sweep also freed nodes a
script had detached but still held, which is the same bug pointing the other way.

**Fix**: record membership when you take it. `unattached_nodes` gains a node in
`onNodeCreated` and loses it the instant `appendChild` succeeds; `deinit` sweeps
that set. An unattached node is unreachable from script, so nothing can have
wrapped or collected it, so its pointer is still valid.

**Takeaway**: **Ownership is a fact you record at the moment you take it, never
a predicate you re-evaluate later - by then the object may be someone else's.**
