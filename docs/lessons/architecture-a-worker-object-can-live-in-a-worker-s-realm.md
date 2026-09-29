# Architecture: A Worker object can live in a worker's realm

**Date**: 2026-09-29
**Lesson**: Worker.zig delivered `message` and `error` to a Worker object with
`engine.runInRealm`, which ends no task. That was harmless while every Worker
object lived in a window's realm, whose task end is the host loop's. A nested
worker's Worker object lives in the OUTER worker's realm, whose task has an
end of its own, and nothing ran it.

**Why**: `runInRealm` is a realm switch inside a task already running;
`runTaskInRealm` is a task of that realm, and ends it the realm's way
(`ContextData.end_of_task`). Only worker realms have one: a microtask
checkpoint, the engine's posted tasks, and what the worker posted leaving for
its owner. Delivering to an object is a task of the object's realm, and which
realm that is depends on who made the object, not on the kind of object.

**What Happened**: In a nested dedicated worker, setTimeout(0) and fetch()
looked dead: the page never heard back. The Crane test
(`crane/net-nested-worker.html`) had a case that settled it: the inner worker's
timer result, relayed by the outer worker from a timer of its OWN, arrived.
So the inner timer fired; the outer worker's handler ran and posted, and the
post sat in its queue, because the task that ran the handler never ended. The
control case (the inner worker posting from its first script) passed only
because another path flushed the queue later. The report's hypothesis - the
worker timer threadlocal - was a real defect, but not this one: every worker
on the page shared the loop it named.

**Fix**: `runTaskInRealm` for both deliveries (`dispatchMessageEvent`,
`dispatchWorkerErrorEvent`). A window owner is unchanged: its realm has no
`end_of_task`. The threadlocal went too: a `WorkerHost` records the loop its
tasks run on when it is made, from its creator's realm, so a worker made by an
iframe no longer moves every other worker's timers to the iframe's loop.

**Takeaway**: **Deliver to an object as a task of its own realm
(`runTaskInRealm`); `runInRealm` is only for a step inside a task that is
already running. And when a report names a cause, write the case that would
tell it apart from the others before fixing it.**
