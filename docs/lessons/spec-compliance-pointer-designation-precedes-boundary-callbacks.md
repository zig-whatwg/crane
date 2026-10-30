# Spec Compliance: Pointer designation precedes boundary callbacks

**Date**: 2026-10-27
**Lesson**: Update the selector-visible pointer designation before dispatching the boundary events caused by that move.

**Why**: A boundary listener can synchronously call matches(), querySelector() or getComputedStyle(). The event name and its relatedTarget do not update the state those APIs read.

**What Happened**: Crane's pointerMove dispatched the old target's pointerout, pointerleave, mouseout and mouseleave before updating the document's hovered element. Entering listeners ran after the update. One move therefore exposed two different designation states depending on which callback observed it.

**Fix**: Move only the existing hit-document and hovered-state update before the leaving callbacks. Keep the pointer's own hit assignment and all event dispatch order unchanged. This follows WebKit's Document::prepareMouseEvent updating hover before EventHandler dispatches boundary events (revision 3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c), taking the design rather than its code. Pin both leaving and entering callback observations, recording them in the callbacks and asserting afterward so listener exceptions cannot hide failures.

**Takeaway**: **Commit the state an event reports before invoking script that can inspect it.**
