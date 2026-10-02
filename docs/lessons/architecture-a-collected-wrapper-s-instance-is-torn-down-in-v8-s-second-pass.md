# Architecture: A collected wrapper's instance is torn down in V8's second pass

**Date**: 2026-10-02
**Lesson**: V8 allows no API call in the first pass of its weak callbacks, and
every instance's deinit ran there. The wrapper cache now only unlinks a
collected entry in the first pass and tears the instance down in the second
(`SetSecondPassCallback`), so a teardown may release values, end holds and
call any operation.

**Why**: v8-weak-callback-info.h: "No v8 other api calls may be called in the
first callback. Should additional work be required, the embedder must set a
second pass callback, which will be called after all the initial callbacks
are processed." In the first pass another handle of the same collection may
still hold the 0xCA11 zap value (its own callback has not reset it), so a
teardown that read one faulted at 0xca10 - realms2 found a removed frame's
retired realm ending that way, and listed every deinit that touches the
engine (Owned/Pin releases, markAsCleanedUp's SetWeak/ClearWeak, realm ends,
promise capabilities, XHR's response value). Blink had the same split before
Oilpan: `ScriptWrappable::firstWeakCallback` reset the wrapper and set
`secondWeakCallback`, which derefed the object (ScriptWrappable.h, Chromium
45).

**What Happened**: the move needed three things the old single callback did
not:
1. **Unlink in the first pass.** Between the passes - a posted task, or the
   next collection's prologue - script runs. An entry left in the cache would
   hand out its Reset (empty) wrapper; a node's `bound_v8_wrapper` likewise.
   `unlinkCollected` takes the entry out of the map, clears the alias and puts
   it on the cache's pending list: Zig bookkeeping, no V8 call.
2. **A wrap in between owns the instance.** The second pass skips the
   teardown when the cache holds a new entry for the same slot generation -
   Blink's deref dropped only the collected wrapper's reference for the same
   reason.
3. **Cancellation.** A handle disposed before its second pass cancels the
   finalizer (`releaseWeakArm` finds it in the per-thread pending map); the
   cache's end finalizes its pending entries itself (`finalizePending`), and
   `v8_Isolate_Dispose` frees records of second passes that never came.

**Fix**: `v8_Global_SetWeakFinalizer(handle, data, unlink, finalize)` in
v8_wrapper.cpp; the wrapper cache and the async iterator finalizer use it.
`v8_Global_SetWeak` keeps first-pass-only callbacks for pure bookkeeping
(context weak handles, no-op arms). The contract is the protocol's
(engine_protocol.zig 4.12, docs/engine-protocol.md): an instance's teardown
never runs while the engine is collecting. Tests: tests/v8
engine_pending_activity_test.zig (a deinit runs outside the first pass; a
deinit reads 32 handles of its own collection and finds them Reset; a re-wrap
before the second pass keeps the instance) and weak_callback_ownership_test
(record accounting, cancellation).

**Takeaway**: **A finalizer that touches the engine belongs in V8's second
pass; the first pass only makes the dying thing unreachable. Decide what may
reach it between the passes, and who frees it if the second pass never
comes.**
