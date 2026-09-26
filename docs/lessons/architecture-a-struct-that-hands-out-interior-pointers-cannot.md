# Architecture: A struct that hands out interior pointers cannot be freed on its own schedule

**Date**: 2026-09-21
**Lesson**: `ContextEntry` is heap-allocated *precisely* so that `instance.ctx` can
point into it - and then `removeContext` and `destroyChildContext` freed it while
those Instances were still alive.

**Why**: `Instance.ctx` is `*ContextData`, and the ContextData lives inline in
`ContextEntry`. The comment on `ManagerState.contexts` spells the dependency out:
entries are heap-allocated and stored by pointer so that "any pointer into
entry.runtime_ctx (like Window.ctx or Element.ctx)" survives a rehash. But
teardown deliberately does **not** destroy that context's Instances - "the slab
allocator will batch-free all instances during full teardown anyway" - so freeing
the entry leaves every one of them holding an interior pointer into freed memory.
The invariant was written down in the file and broken 800 lines later.

**What Happened**: `state.allocator` is a `DebugAllocator`, which poisons freed
memory with 0xAA. So `entry.runtime_ctx._v8_wrapper_cache_storage` read back as
`0xAAAA_AAAA_AAAA_AAAA` - non-null, so `orelse return` passed it through, and 2
mod 4, so `markInstanceCleanedUp` died in its `@alignCast` with `panic: incorrect
alignment`. Stack: navigate -> `Context.deinit` -> `removeContext` ->
`destroyChildContext` -> `Window.deinit` -> `Document.deinit` -> `Node.deinit`.
Every other reader of `instance.ctx` was reading the same poison, just quietly.

**Fix**: retire the entry instead of freeing it. Clear the fields that can dangle,
push it onto `ManagerState.retired`, and free the whole list in `deinit()`, where
the Instances are going away anyway. One entry per destroyed context for the
manager's lifetime, all of it freed at the end.

**Takeaway**: **A structure that hands out pointers to its interior must outlive
every holder. When you cannot enumerate the holders, retire rather than free -
0xAA is not null, so a poisoned read is a crash, not a null check.**
