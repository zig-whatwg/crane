# Architecture: A per-realm cache set through the WindowProxy follows the proxy to the next realm

**Date**: 2026-11-18
**Lesson**: A value a realm keeps for itself must hang on something only that realm's global object holds (its retained store), never on `context->Global()`.

**Why**: `context->Global()` is the realm's global PROXY. V8 stores a private symbol set through an attached proxy on the global OBJECT it is attached to at that moment (LookupIterator::GetStoreTarget), and reads it from there. After a navigation hands the WindowProxy on (DetachGlobal, then the new realm's attach), the old realm's `Global()` still answers the same proxy - now attached to the NEW realm's global object.

**What Happened**: `engine.globalBuiltinFunction` kept each realm's ByteLengthQueuingStrategy/CountQueuingStrategy size function under a private on `Global()`. streams/queuing-strategies-size-function-navigation.window.js was 0/24: after the iframe navigated, a strategy of the old realm answered the new realm's function (wrong Function.prototype), and a function the old realm made first after the hand-on became the new realm's. The adapter's own 2.6 test pinned the proxy as the holder, so the bug had a green test.

**Fix**: keep the function on the realm's retained store (`realm_global.retainedStore(realm)`): the store belongs to the realm's GlobalAnchor, which the realm's own hidden global object keeps - an edge, never a root, and still the old realm's after the hand-on (the context manager's entry keeps the anchor the realm was attached with). With no store (no anchor, global gone) make the value anew per call rather than root it. protocol_tracing already hangs a Window's traced edges there (`tracedEdgeHolderOfWindow`).

**Takeaway**: **Anything per realm goes on the realm's retained store, not through the proxy - and a test that pins `v8_Object_GetPrivateRef(Global(), ...)` pins the bug.**
