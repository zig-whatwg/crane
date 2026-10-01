# Architecture: A namespace operation's runtime.Context is a process-wide stand-in

**Date**: 2026-09-26
**Lesson**: `namespace.zig` hands every namespace operation (console, TestUtils, ...) one process-global ContextData, created on the first call with THAT call's context; it had no Engine table, and a namespace impl's error came back to script as an Error object instead of a throw.

**Why**: The global ContextData's `engine_ctx` is whichever page called a namespace first. In a sweep it dangles once that page is gone, and console state is shared across pages and realms. With `.engine` unset, anything going through `ctx.getEngine()` failed with NoEngine - and `conversions.toV8Value`'s error_union arm turned the impl's error into a RETURNED `new Error("NoEngine")`.

**What Happened**: TestUtils.gc() moved onto the Engine table and silently returned an Error object instead of a promise; only a crane test (eb-runtime-impls-testutils-gc, 2/2 -> 1/2) caught it.

**Fix**: The missing `.engine` was set (one line, granted). Still open (tmp/plans/lifetime-queue.md): give a namespace operation `context_manager.get(<current context>) orelse <global>` - the running realm's own ContextData - and make the error_union arm throw.

**Takeaway**: **A namespace operation must take its realm from the running context, not from a shared stand-in - and an impl's error must throw, never be returned as a value.**

**2026-10-01, and one context per call**: the namespace binding's callback
took `v8_Isolate_GetCurrentContext` for every call and never released it, and
it handed V8 its result without releasing that either - the interface binding
releases both (`getterValueIsOwned`, the `result != .instance` rule). Each is a
Global into the calling realm, so every page that called `TestUtils.gc()` - or
`console.log()` - stayed for the process: crane/rl-frame-churn-dropped.html,
24 copies in one process under CRANE_HEAP_GC=1, read +1 native context and
+2.26 MB per page (a page that only called `TestUtils.gc()`: +2.27 MB), and
`leaks --atExit` named the Globals (`v8_Isolate_GetCurrentContext`,
`v8_PromiseResolver_GetPromise`, one each per call). Both are released now
(namespace.zig); the first calling realm's context is still kept as the
process-wide stand-in above (one page, not one per call). Any measurement of
page retention that calls `TestUtils.gc()` on an older tree is measuring this.
