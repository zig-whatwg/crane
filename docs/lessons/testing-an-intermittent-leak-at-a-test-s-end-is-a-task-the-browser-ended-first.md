# Testing: An intermittent leak at a test's end is a task the Browser ended before it ran

**Date**: 2026-10-19
**Lesson**: A native Browser test that leaks "once in two runs" right after a step that queues work - `w.close()`, a postMessage, a port close - is usually that work's task, queued on a plain timer and dropped when the Browser ended before the loop turned again. Make "the Browser ends at once" a scenario of its own and the leak is deterministic.

**Why**: Whether the queued task runs depends on whether the test reads its answer before or after the next event-loop turn - a race the test does not control. When the task runs, it frees its data; when the Browser ends first, the timer manager drops the entry and, for a plain `setTimeout(0, run, data)`, nothing frees `data`.

**What Happened**: Lane httpcache1's popup test leaked one allocation in one of two runs, with and without the HTTP cache, and the lane stopped closing popups to stay green. Lane leaks6 wrote a test that opens and closes popups in every order (close after load, before load, from the popup, about:blank, never closed, two Browsers at once): all green, 4 runs each. The one scenario that was red - 4 of 4 runs, one 96-byte allocation per popup - closed the loaded popups from Zig and ended the Browser without turning the loop: Window.close's CloseTask, armed with a plain `setTimeout` on the popup's timer, which the popup's end dropped unrun. httpcache1's page answered right after `w.close()`, so its Browser ended before the close task ran exactly when the answer was read in the same turn.

**Fix**: Arm the task with `setTimeoutOwned(ms, run, data, drop)`, whose drop frees the data when the timer manager ends with it armed (the plain timer stays the fallback for an implementation that cannot promise the drop). In the test, a scenario that queues the work and ends the Browser with no loop turn in between.

**Takeaway**: **When a leak is intermittent at a test's end, end the Browser right after the last step on purpose - a task that loses the race leaks every time.** See also [A task queued on a loop that never runs again leaks its data](architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md).
