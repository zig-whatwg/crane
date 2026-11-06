# Architecture: A start time set outside the event step needs the event step's phase update

**Date**: 2026-11-06
**Lesson**: CSS animation and transition events come from comparing a phase "in the previous and current animation frame"; a second place that moves an animation's phase (a pending task completed at step 16) must run that comparison too, or a cancel before the next step 11 sees idle -> idle and queues no transitioncancel.

**Why**: css_events.update records the phase it saw; Crane ran it only in "update animations and send events" (step 11). C8 added a second completion point for pending play tasks, after the style update at step 16 (Blink PendingAnimations::Update). Blink's event delegate sees the phase change wherever the start time is set, so its transitionrun/start are decided then.

**What Happened**: crane/anim1-transition-cancel.html's display:none case timed out: the transition was made inside a frame's step 11 (a promise continuation of the previous test), committed at that frame's step 16 - its phase still "idle" in css_events - and canceled by `display: none` before the next step 11. The cancel compared idle with idle and queued nothing.

**Fix**: registry.commitPendingAnimations runs css_events.update for a CSS animation or transition right after its pending task completes; its events are queued then and dispatched at the next step 11.

**Takeaway**: **Every place that completes a pending task must also record the phase the event tables compare - otherwise the events depend on which step happened to set the start time.**
