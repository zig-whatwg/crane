# Architecture: A wrapper outlives its realm - sever it when its instance goes

**Date**: 2026-09-30
**Lesson**: When a realm ends, its wrapper cache frees the instances it holds,
but a wrapper that script in ANOTHER realm still references survives, and its
internal field still points at the freed instance. Clear the field in the same
step that frees the instance, so the next read through the wrapper is a
TypeError in the binding, not a read of freed memory in an impl.

**Why**: the cache disposes its own handle to the wrapper; it does not own the
wrapper object, which V8 keeps alive for whoever else references it. 23 impls
unwrap `_internal.?` unchecked (82 sites), so a surviving wrapper panics - or,
once the slab reissues the slot, reads another object's state.

**What Happened**: ending a removed frame's realm at the removal's task (the
flakes lane's A-STEP) made an old hole deterministic: a page that made
`new frame.contentWindow.XMLHttpRequest()` and read `client.readyState` after
the frame was removed panicked in `XMLHttpRequest.getXHRState` every run. The
same hole existed before, at whatever GC ended the frame's realm, and for any
navigated-away realm whose objects another realm held. A tests/v8 case (a
frame's `Headers` held by its parent, the frame's realm ended, `get` called)
aborted in `Headers.call_get`.

**Fix**: `WrapperCache.deinit` calls `severWrapper(entry)` - clear internal
fields 0 and 1, through a proxy wrapper's target - in every branch where the
instance is freed, was already freed, or its slot now holds another object;
not for a node its tree owns or an instance another realm still wraps.
`severWindow` did this for a Window's global only. Blink:
`V8DOMWrapper::ClearNativeInfo`.

**Takeaway**: **Whoever frees an instance must sever every wrapper that can
outlive the free. Disposing your own handle to a wrapper does not make the
wrapper go away.**
