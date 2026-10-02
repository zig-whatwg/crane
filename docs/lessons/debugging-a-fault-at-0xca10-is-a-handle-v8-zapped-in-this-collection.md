# Debugging: A fault at 0xca10 is a handle V8 zapped in this collection

**Date**: 2026-10-01
**Lesson**: A SIGSEGV at address 0xca10 inside a V8 API call is a read through a
weak `Global` whose object died in the collection that is running: V8 stores
the value 0xCA11 in such a handle's slot until its own weak callback runs, and
the object's map load (tagged pointer minus 1) faults at 0xca10.

**Why**: `GlobalHandles::Node::CollectPhantomCallbackData`
(src/handles/global-handles.cc) zaps every dead phantom handle - "Zap with
something dangerous", `location().store(Tagged<Object>(0xCA11))` - and queues
its callback. `v8_Global_IsEmpty` still reads it as non-empty: the node is in
use, only its object is gone. So any code that walks handles from inside a
first-pass weak callback can meet another handle of the same collection in
that state. v8-weak-callback-info.h forbids it outright: "No v8 other api calls
may be called in the first callback. Should additional work be required, the
embedder must set a second pass callback."

**What Happened**: fetch/origin/assorted.window.js died with SIGSEGV at 0xca10
in `v8::Value::IsProxy` every run alone (and navigation-timing/
unload-event-same-origin-check.html in the 10,035-file sweep). Its form POST
navigations give each iframe's navigable a new Window, retiring the old realm
(`IFrameIntegration.retired_realms`); the parent then removes the iframe. The
removal hands only the current realm to its queued end task, so the retired
realm waited for `IFrameIntegration.deinit` - which, for a removed element, the
collector runs: `wrapper_cache.weakCallback` -> `gc.onObjectFreed` ->
`HTMLIFrameElement.deinit` -> `destroyRetiredRealm` -> `WrapperCache.deinit` ->
`severWrapper` -> `IsProxy` on a wrapper of the retired realm that had died in
the same collection. The trace printed 10,000 frames of
`InvokeFirstPassWeakCallbacks` (an unwinder lost in V8's frames); the frames
above them were the whole story.

**Fix**: the realm ends at the removal's task, never from the collector
(realms2, 677e88983). The red test is crane/c4-removed-frame-retired-realm-gc.html
(SIGSEGV 3/3 on main-815bc4793). Every instance deinit runs inside V8's first
pass today, so any deinit that touches a handle other than its own is this bug;
the contract's answer is running the Zig finalizer from a second-pass callback.

**Takeaway**: **0xca10 (or 0xca11) in a fault address means a handle zapped by
the running collection: find the weak callback on the stack and the engine call
it made - V8 allows none there.**
