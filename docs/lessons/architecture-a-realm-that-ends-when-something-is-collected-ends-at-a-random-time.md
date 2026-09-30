# Architecture: A realm that ends when something is collected ends at a random time

**Date**: 2026-09-30
**Lesson**: A removed iframe's realm ended when the collector freed the removed
`<iframe>` element, so what script could still do with the frame's WindowProxy
changed at a GC-chosen moment. Anything script can observe must change at a
point the spec names - a task, a step - never at a collection.

**Why**: `IFrameIntegration.onRemovedFromDocument` deliberately left the realm
alive ("the child V8 context must remain alive ... while JS may still be
executing"), and the only other path that ended it was the element's own
teardown: removed, the element is a root node, freed when its wrapper is
collected -> `HTMLIFrameElement.deinit` -> `IFrameIntegration.deinit` ->
`cleanupRealmContext` -> `engine.destroyWindowRealm`, which DETACHED the global
(`v8_Context_DetachGlobal`). From then on every read through the WindowProxy -
even `w.self`, an own data property - threw V8's "no access".

**What Happened**: `html/browsers/the-window-object/self-et-al.window.js` read
5 of 8 alone every time, 6 and 7 in its sweep prefix, and anything from 0 to 7
in full sweeps; lanes called it "the known flake". Per subtest: the four iframe
cases check `w.frames`, `w.globalThis`, `w.self`, `w.window` two timer turns
after `frame.remove()`, and each failed with "no access" exactly when a
collection had freed its removed element first. Popups never flaked: the
opener's page ends them (`Window.auxiliary_navigables`), at a fixed point.
`crane/fl-removed-frame-window-survives-gc.html` reproduced it on demand:
right after removal the self-references answered; after `TestUtils.gc()` x2,
"no access". Chrome, Edge and Firefox pass 8/8: Blink's
`LocalWindowProxy::DisposeContext(kFrameIsDetached)` never detaches the global
(only a navigation, `kGlobalObjectIsDetached`, does).

**Fix** (A-STEP): the removal queues a task that ends the frame's realm
(HTML "destroy a child navigable"), handing it over so the element's collection
no longer does. `engine.destroyWindowRealm(realm, .navigable_destroyed)` skips
`DetachGlobal` and severs the still-attached global from the Window the host
frees (`severAttachedGlobal`); the `window` getter answers from its own realm
(HTML: this's relevant realm's global this value - no Window needed). Stated
deviation, pinned by the Crane test: a removed frame's other Window members
throw once its realm has ended; the spec keeps the Window (closed reads true).
The full model - the Window alive as long as its WindowProxy, children traced
instead of pinned - is tmp/plans/frame-realm-tracing-design.md.

**Takeaway**: **Tie every script-observable lifetime to a spec step, not to a
collection.** When a result flips with process history, find what ends at GC
time and ask which step should have ended it.
