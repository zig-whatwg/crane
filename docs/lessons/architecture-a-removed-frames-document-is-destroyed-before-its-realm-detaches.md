# Architecture: A removed frame's document is destroyed before its realm detaches

**Date**: 2026-10-19
**Lesson**: Removing an iframe destroys its document at once ("destroy a child navigable" step 5) but ends its realm at a task of its own (dom.navigables.queueRemovedFrameRealmEnd) - so in between, the adapter's detached-realm guard (protocol_callbacks CallbackRealm.runnable, isDetached) still called the frame's callbacks.

**Why**: The realm end is deferred on purpose - a frame may remove its own container, and its realm must not end under its own script. Blink refuses a callback once the frame's ExecutionContext is destroyed (IsCallbackFunctionRunnable: IsContextDestroyed), which happens as the frame detaches, not when its context is collected.

**What Happened**: dom/traversal/TreeWalker-acceptNode-filter-cross-realm-null-browsing-context.html (Chrome and Firefox pass) removed the frame and called nextNode() on the parent's iterator with the frame's filter at once: the filter ran. Lane engine1 added a second test to runnable: the realm's global is a Window whose dom.document_activity is `.gone` (destroyed, its navigable closed, freed) - not `.inactive`, which a back/forward-cached page answers and which stays the cached-realm lesson's phase-C work. The traversal then throws (node_filter turns OperationFailed into an InvalidStateError).

**Fix**: decide runnability from the realm's Window's document state as well as the engine's detach state, and only on "can never be fully active again" - and only for an attached frame realm (protocol_realms.isAttachedFrame): the activity check walks the Browser's navigables, and a top-level realm ends or detaches with its document, so every top-level callback skips it.

**Takeaway**: **Two clocks end a frame - its document now, its realm later - and every guard must read the earlier one; a callback check that waits for the realm's detach runs script in a destroyed document.**
