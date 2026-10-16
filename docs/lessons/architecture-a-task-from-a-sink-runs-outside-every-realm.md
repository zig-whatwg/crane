# Architecture: A task taken from a sink runs outside every realm until it enters one

**Date**: 2026-10-16
**Lesson**: A cross-thread task (runtime.TaskSink) runs on its loop's thread with no realm entered. A worker's loop runs what its sink takes straight from `WorkerEventLoop.turn`, so a task that settles a promise or fires an event there must enter its realm first, with `engine.runTaskInRealm`.

**Why**: The sink is engine-neutral by design: a posted task is a `run` and a `drop` that free bytes, discard port ends and release references, and the receiving loop runs `run` as a plain task. The worker host's own deliveries wrap themselves in `WorkerHost.runTask` (a port message, a `connect`, a shared worker's start), which is why nothing had tripped over it. The window loop runs its tasks with the page's isolate entered, so the same task delivered to a window works there and only fails in a worker.

**What Happened**: Lane sw1's service worker manager posts a Delivery task (a job promise settled, a statechange, a controllerchange) to each realm's sink. The page's Deliveries worked. The first Delivery to a service worker's own realm - the resolution of `skipWaiting()`'s promise - crashed the WPT runner in `engine.resolvePromise`, called from `WorkerEventLoop.turn` with no isolate entered (crane/sw1-claim.https.html).

**Fix**: `RealmEnvironment.deliver` (src/service_worker/realm.zig) runs its steps through `engine.runTaskInRealm(realm, ...)`: the agent is entered, the realm is current, and the task ends the realm's way (a worker's end of task, a microtask checkpoint). The same holds for any host code that reaches a realm from a sink.

**Takeaway**: **A sink's task is not in any realm. Before it touches the engine, enter its realm with `runTaskInRealm` - and test the worker case, since the window loop hides the mistake.**
