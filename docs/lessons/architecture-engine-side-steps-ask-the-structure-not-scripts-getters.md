# Architecture: Steps that run outside script ask the structure, not script's getters

**Date**: 2026-10-05
**Lesson**: Code that runs from the event loop or the network sweep - a
task's liveness check, a fetch's `alive` - must not answer "is this document
fully active?" with `Window.document`, nor tree order with
`Node.compareDocumentPosition`. The first is script's getter, with its
cross-origin check against the incumbent or current realm; the second is
incomplete. Ask the navigable (`BrowsingContext.ofWindow(window)`,
`getActiveDocument()`) and the NodeBase tree.

**What Happened**: an object element in a data: frame (an opaque origin)
never fired anything: its task and its fetch's `alive` asked
`interfaces.Window.get_document(window)`, which refused the accessor
(whatever realm was current from the network sweep) - mixed-content
iframe-data-inherit object-tag TIMEOUT 3/8 -> OK 6/8 once it asked the
navigable. And placing a new child navigable in tree order with
`compareDocumentPosition` reversed an iframe, an object and an embed:
it returns FOLLOWING for any two nodes neither of which contains the other
("TODO: full tree order comparison") - window[0] was the embed's.

**Fix**: `documentIsFullyActive` compares the navigable's active document;
`dom.navigables.follows` walks the NodeBase ancestor chains (unit-tested).

**Takeaway**: **An IDL getter is script's - its security checks assume a
script accessor and its implementation may be partial. Engine-side steps
read the structure the getter reads.**
