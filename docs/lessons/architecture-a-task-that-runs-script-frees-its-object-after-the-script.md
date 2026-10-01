# Architecture: A task that runs script frees its object after the script, never during it

**Date**: 2026-09-30
**Lesson**: When a task's own object can be freed by the script the task runs
(abort(), open(), a frame removed from an event handler), the task must hold
the object for as long as it is on the stack and do the free itself when it
returns. A "free when nothing holds it" check that does not count the running
task frees the object under the task, and the task's own cleanup frees it again.

**Why**: `XMLHttpRequest.PendingFetch` is freed by `maybeFree` once neither the
fetch nor a queued task holds it. `run` cleared `task_queued` before running
the task's steps, so while the steps ran script nothing held the request:
`cancel()` from that script freed it, and `run`'s trailing `maybeFree` freed it
a second time. `timedOut` had the same shape.

**What Happened**: the flakes lane's "abort a document" hook cancels a removed
frame's XHR fetches at removal. A WPT A/B sweep then showed one DebugAllocator
"Double free detected" per run in a 3-file list
(html/webappapis/dynamic-markup-insertion/opening-the-input-stream/012.html,
015.html, ...), on the lane only. Bisecting by reverting candidate changes
cleared four suspects; `CRANE_LEAK_TRACES=1` named both frees at once
(cancel <- abortFetchesIn <- iframeRemovingStepsCallback, and
run <- runQueuedTasks). It printed only an error line - no crash, no failed
subtest - so only the runner's log showed it.

**Fix**: a `running` flag set around `runTaskInRealm` in `run` and `timedOut`;
`maybeFree` returns while it is set, and the task frees after it clears it.

**Takeaway**: **Count the running task as a holder. And grep sweep logs for
"Double free detected" - DebugAllocator reports it and carries on, so no
journal status shows it; `CRANE_LEAK_TRACES=1` gives the two stacks.**
