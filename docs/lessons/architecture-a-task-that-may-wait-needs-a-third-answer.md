# Architecture: A task that may wait needs a third answer, and every "is there work" check must ask it

**Date**: 2026-10-18
**Lesson**: Keeping a non-runnable task queued (HTML: "the first runnable task in taskQueue") needs two
things the drop-it version never did: a classification that tells "not fully active, may be again"
from "never again", and every place that read `tasks.len > 0` as "there is work" rewritten to count
only the tasks that may run.

**Why**: `dom.document_activity.fullyActive` answered a bool, and the window event loop dropped every
task it said no to - correct only while no document ever became fully active again. A bool cannot
say "wait": a task of a destroyed, freed or windowless document must still be dropped (HTML "destroy
a document" step 5), and one of a cached document must stay. And once a task can stay queued, every
"is there work" check that counts the queue is wrong in a new way: the step 3 wait computed 0 ms
(a busy loop), `hasPendingWork` kept the WPT runner turning forever, the idle period never started
("has no runnable task") and the deferred teardown yielded to tasks that could not run.

**What Happened**: Lane bfcache-a (back/forward cache phase A) found four such checks in
src/browser/event_loop.zig - the wait, hasPendingWork, startIdlePeriod and runDeferredTeardown - before
writing the keep path. WebKit has the same split: `EventLoop::run` puts a suspended group's tasks
back in order and discards a stopped group's, and `hasTasksForFullyActiveDocument` - not
`m_tasks.isEmpty()` - is its "work" (WebCore/dom/EventLoop.cpp).

**Fix**: `document_activity.activity` returns `fully_active`, `inactive` or `gone` (`fullyActive`
stays for its other callers). `drainTasks` leaves inactive tasks in place, so they form a prefix of
the queue, and records its length (`waiting`); every work check asks `runnableQueued()`
(`tasks.len > waiting`). Unit tests drive the drain with an injected classifier (no agent needed).

**Takeaway**: **When a queue gains items that may not run yet, grep every "queue is non-empty"
check: each one is a busy-wait or a hang unless it counts only what may run.**
