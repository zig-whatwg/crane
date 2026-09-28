# Architecture: A step deferred to a loop dies with the loop

**Date**: 2026-09-28
**Lesson**: A worker's end is a 0 ms timer on its owner's event loop. When the owner was a Browser that was itself ending, the page's teardown armed that timer and `event_loop.deinit` dropped it unfired, so the worker's realm, its isolate and its host lived until the process exited.

**Why**: The worker host never ends a worker from the call that ended it, because that call can be the worker's own script, a GC weak callback, or the page's teardown. That rule is right, but it assumes the loop will turn again. `TimerManager.deinit` frees its timers without calling them, so a step armed during the loop's last turn never runs. Nothing reports this. `destroy()` saw the teardown still armed and waited for it, correctly, and the wait never ended.

**What Happened**: The networking lane found 13-17 leaks per worker file under `CRANE_LEAK_TRACES`, reported at `WorkerHost.classicScript`. The records were already tied to the realm and freed when it ended. The traces also showed `WorkerHost.init`'s own allocations, which meant the whole host was leaking, not the records, and so the realm had never ended. In a sweep, the next navigation's loop turns fired the timer, so this hit only the last file of each process and any file run alone. The isolate is invisible to the gpa and was the larger leak.

**Fix**: `worker_host.endWorkersOn(timers)` runs every worker's remaining steps now: "terminate a worker" if it is still running, then the realm, then the agent. `Browser.deinit` calls it BEFORE the page's teardown. There the page realm is still entered, which is also how things stand when the timers fire. After the page's teardown no isolate is entered, and the V8 adapter read a worker agent that ended then as the thread's host agent (see [An agent's role is recorded when it is made](architecture-an-agent-s-role-is-recorded-when-it-is-made.md)). The Worker objects let go later, during the page's teardown, find their hosts disposed, and free them. cors-basic.any.js went from 13 leaks to 0.

**Takeaway**: **Every step deferred to a timer needs an answer for the loop ending first. Whoever ends the loop runs what is still armed on it, under the same conditions the timer would have had.**
