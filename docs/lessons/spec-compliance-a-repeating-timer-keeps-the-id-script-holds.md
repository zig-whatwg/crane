# Spec Compliance: A repeating timer keeps the id script holds

**Date**: 2026-09-27
**Lesson**: The id setInterval returns names the timer for as long as it repeats; the scheduler's id for each armed run is a different thing, and keying the timer map on it makes clearInterval a no-op after the second run.

**Why**: HTML's timer initialization steps take a `previousId`: a repeat runs the same steps again with the same id, so the map of active timers keeps one entry per timer across repeats. The worker host re-registered an interval under each new timer-manager id, so the id script held went stale once the interval had fired twice.

**What Happened**: streams/readable-streams/general.any.js went OK to ERROR ("Error in remote rs-utils.js: TypeError: TypeError") in its worker half. rs-utils' RandomPushSource clears its interval and closes its stream; the interval kept running, and the next tick closed the closed stream. The stale id was old (it is in the worker host at 22ed59f30 too); 45fa1d65b made worker timer callbacks report their exceptions, and the swallowed TypeError became a harness error (see "Reporting an exception turns a swallowed failure into a harness ERROR").

**Fix**: The timer context carries the id script holds (`WorkerTimerContext.id`, from its own counter) and keys the map on it; the manager id (`current_timer_id`) changes on every repeat and is used only to cancel the armed run. crane/sweep-worker-timers.html: clear from inside the callback after three runs, and from outside after several.

**Takeaway**: **Whatever script holds must outlive the scheduler's handles. When a map is keyed on an id script sees, a reschedule updates the value, never the key.**
