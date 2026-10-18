# Spec Compliance: A subclass's copy of an event concept hides what dispatch does to it

**Date**: 2026-10-18
**Lesson**: DOM's relatedTarget belongs to the event (DOM 2.2), and dispatch rewrites it for every path item. MouseEvent and FocusEvent each kept a copy of their own, with its own traced edge, so dispatch had nothing to retarget and the attribute returned the constructor's value.

**Why**: "Other specifications use relatedTarget to define a relatedTarget attribute" (DOM 2.2). UI Events' getters return the event's relatedTarget. Invoke step 4 sets it to the current item's retargeted value, and dispatch step 11 clears it when clearTargets is set. A copy kept in a subclass sees none of this.

**What Happened**: Every relatedTarget test failed: dom/events/relatedTarget.window.js 0/6, shadow-relatedTarget 0/2, and in shadow-dom/ event-with-related-target 0/18 and event-composed-path-with-related-target 4/13. The bug did not show without shadow trees, because there retargeting changes nothing.

**Fix**: One relatedTarget, in dom.event_dispatch.EventState, with the event's traced edge (`related_target_slot`) and a KeptInstance net. The constructors and init*Event set it through `setRelatedTarget`. Dispatch writes it raw for each item and keeps the value it ends with (`finishDispatch`, after step 11). MouseEvent and FocusEvent read it through `dom.event_dispatch.of`. crane/ev1-related-target-kept-across-dispatch.html drops the last script reference and collects during dispatch, then reads the retargeted host afterwards.

**Takeaway**: **A concept the base algorithm reads and writes has one home, the base's state; a subclass attribute that names it reads it there, never a copy of its own.**
