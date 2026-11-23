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

**Recurrence (2026-11-22, lane flk4)**: the same shape, one level down. A
NAVIGATION destroys the old document's child navigables
(HTMLIFrameElement `destroyChildNavigables`), but it only discarded each
child's browsing context: it left the child's realm with its `<iframe>`
element, which stays in the destroyed document and is freed by the collector
when that document goes. Its teardown (`iframeContextCleanup`) then called
`destroyWindowRealm`. On a realm the parent's detach had already detached,
that call is the OWNER'S END: it freed the Window while script still held the
frame's WindowProxy. html/webappapis/dynamic-markup-insertion/
opening-the-input-stream/event-listeners.window.js, "Standard event listeners
are to be removed from Window for an active but not fully active document",
failed about 1 run in 11 with "TypeError: Illegal invocation": whenever a full
collection ran between `frame.src = ...` and the outer frame's load event.
Reproduced on demand by crane/flk4-navigated-frame-window-survives-gc.html
(TestUtils.gc() x4 after the navigation): 5 of 9 subtests failed every run on
main 98160b541.
- Two levels down, the removal path had the same hole: a frame inside a
  removed frame.
- A frame inside an initial about:blank whose Window a same-origin
  navigation kept was never detached at all, and so never collected.

Browsers (tmp/probes/flk4-navwin): Chrome 157 (forced gc()), Firefox 159 and
Safari 27 all answer through such a proxy after collections: `document` is
the old document, `closed` is true, and addEventListener and dispatchEvent do
not throw. document.open's step 10 then erases the Window's listeners in
Chrome and Safari but not in Firefox. Crane erases them: the spec and two of
three.

Fix:
- `engine.detachWindowRealm`, an idempotent "its navigable was destroyed":
  it detaches an attached frame realm and leaves a detached or ended one
  alone. `destroyWindowRealm` keeps meaning "end it".
- The navigation hands each child's realm over as the removal does
  (dom.navigables.queueRemovedFrameRealmEnd, now shared).
- A frame element's teardown only detaches.

**Takeaway, refined**: **A realm has one owner for its end: its page, or the
collector. Every other path that learns its navigable was destroyed - a
removal, a navigation, an element's teardown - may only detach it, and
detaching twice must be harmless.**
