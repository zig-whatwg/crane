# Spec Compliance: A native event takes its bubbles and cancelable from the spec's event table

**Date**: 2026-11-06
**Lesson**: An event Crane makes in Zig through an interface's constructor gets the constructor's EventInit defaults - `bubbles: false`, `cancelable: false` - unless the maker passes the values the defining spec's event table gives.

**Why**: A script-made event and a UA-made event go through the same constructor, but only the script's caller chooses its EventInit; for a UA event the spec's table ("Bubbles: Yes", "Cancelable: No" for every CSS transition and animation event, CSS Transitions 1 6.2, CSS Animations 1 4.2) is the caller. `.base = .{}` reads as "nothing special" and silently means "does not bubble".

**What Happened**: Lane anim1 (batch 2) made CSS transitions start from style. dom/events/webkit-transition-end-event.html still timed out at 4/13: its `waitForEventThenAnimationFrame` listens for `transitionend` on `window`, and css_events.zig queued every TransitionEvent and AnimationEvent with `.base = .{}` since lane rendering2 wrote it. The events were dispatched at the owning element and never reached `window`. Nothing had noticed because no CSS transition or animation had ever been made from style before.

**Fix**: css_events.queue passes `.base = .{ .bubbles = true }` for both kinds, citing the two tables; crane/anim1-transition-starts-at-frame.html checks `bubbles`, `cancelable` and `isTrusted` on a `transitionrun` caught at `document`. The file went to 13/13.

**Takeaway**: **When Zig makes a UA event through a constructor, copy Bubbles and Cancelable from the spec's event table into the EventInit, and test them on a listener above the target.**
