# Architecture: A cached realm is attached, so the engine's detached-realm guard misses it

**Date**: 2026-10-19
**Lesson**: The V8 adapter refuses to run a callback whose realm is DETACHED (protocol_callbacks
CallbackRealm.runnable, isDetached) - the guard that stops a navigated-away frame's listeners. A page the
back/forward cache keeps has a realm that is never detached (its global stays attached to its own
WindowProxy, so its script still reaches its own Window when restored), so that guard says "runnable".

**Why**: "Not fully active" used to mean "detached or destroyed". The cache adds a third state: alive,
attached, and still not allowed to run script until its restore.

**What Happened**: Lane bfcache-b relied, for phase B, on nothing reaching a cached page's script: its
tasks wait in an event loop group, its timers are suspended, its idle period requests are held, and no
other realm holds its objects (alone in its browsing context group, no frames). Paths that bypass tasks -
a WebSocket's 1 ms pump, a BroadcastChannel delivery posted through the sink, IndexedDB's versionchange,
a service worker delivery - each had to be found and made to defer or evict.

**Fix**: dom.bfcache.assertNotCached (Debug) at each point host code enters a Window's realm for script
(timers, animation frames, a socket's deferred close, a channel's message), and eviction where a delivery
cannot wait (Blink's kIgnoreEventAndEvict). Phase C, whose cached pages keep frames that other code can
call into, must revisit an engine-level suspension (engine.suspendRealm).

**Takeaway**: **A realm that may not run script but is not detached needs its own check wherever script
is entered - grep every path that enters a realm without a document-tagged task.**
