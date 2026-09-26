# Architecture: `var x = entry.field` is a copy, so clearing it clears nothing

**Date**: 2026-09-21
**Lesson**: `destroyChildContext` and `context_manager.deinit` both opened with
`var ctx_data = entry.runtime_ctx;` and then mutated `ctx_data`.

**Why**: `ContextEntry.runtime_ctx` is an inline `ContextData` and
`runtime.Context` is `*ContextData`, so every Instance created in that context
holds `&entry.runtime_ctx` - the entry's own field is the one everybody reads. A
`var` binding copies the struct, so `ctx_data.clearV8WrapperCacheStorage()`
cleared a stack copy that nothing else could see.

**What Happened**: after 4c freed the `WrapperCache`,
`entry.runtime_ctx._v8_wrapper_cache_storage` still pointed at it, and the realm
and context-data phases that run next can reach an Instance whose `ctx` is that
entry. Silent rather than loud, because a freed-but-aligned pointer sails past
`@alignCast`.

**Fix**: `const ctx_data = &entry.runtime_ctx;`. Nothing else changes - the
copy's `deinit()` was already freeing the original's buffers.

**Takeaway**: **A struct field read into a `var` is a copy; if you mean to clear
the original, bind a pointer. Grep for `var x = y.field` wherever a teardown
path "clears" something.**
