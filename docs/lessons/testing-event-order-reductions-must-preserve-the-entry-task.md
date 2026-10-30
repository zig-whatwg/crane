# Testing: Event-Order Reductions Must Preserve the Entry Task

**Date**: 2026-10-29
**Lesson**: Preserve how execution reaches a failing event-order assertion when reducing it; equal JavaScript bodies can run from different tasks.

**Why**: Replacing external scripts with inline code can remove a parser suspension and its queued continuation. Moving the same operation into a timer callback changes the event-loop position again. A smaller test can therefore lose the scheduling condition it was meant to isolate.

**What Happened**: Details and dialog ToggleEvent source tests failed because no opening toggle had fired before a subsequent zero-delay timer. A new four-case fixture passed for both elements, including opening from a timer turn. Pure reductions of each upstream first test still failed. Keeping those reductions' markup, listeners, global step_timeout, open operation and assertions identical, loading the helper externally failed for both elements while inlining the helper's exact bytes passed for both. The unused testdriver tags were removed from both members of each pair. This measured distinction supported a specific scheduling hypothesis: an external script's fetched task resumes parsing, whose new toggle task is outside the loop's initial drain budget, while the later timer poll can already include its zero-delay timer. That code-level cause remained for the event-loop owner to reproduce; the paired fixtures established the context distinction, not a verified implementation fix.

**Fix**: First reduce the original file to its first failing case without changing resource loading. Compare one execution-context change at a time, preserving the helper bytes and every assertion. Keep original and reduced results separate. Trace where each variant enters the event loop, then route evidence to its owner if the cause is outside the feature's implementation. Do not increase the timeout or substitute the passing inline variant for the upstream failure. Re-run the full original file after the actual fix.

**Takeaway**: **A task-order reproducer must preserve the task that starts it, not only the code it runs.**
