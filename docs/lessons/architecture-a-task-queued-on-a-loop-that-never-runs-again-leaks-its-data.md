# Architecture: A task queued on a loop that never runs again leaks its data

**Date**: 2026-10-02
**Lesson**: A task armed with heap data (`timer.setTimeout(0, run, data)`) frees its data when it runs. A loop that ends drops its pending entries without running them, and the data goes with nothing.

**Why**: The timer interface takes an opaque `user_data` and has no destructor for it: `NativeTimerManager.deinit` frees its entries, not what they point at. Whoever queues the task owns its data until it runs - and must also be there when it will never run.

**What Happened**: When a worker ends, its ports are disentangled, and each entangled peer is sent `close` from a task of the PEER's realm (MessagePort's scheduleClose arms a PortTask on the peer's timer). Browser.deinit ends the workers first (endWorkersOn), so each of those tasks was queued on the page's loop, which never runs again: 6 leaked PortTasks per content-security-policy/gen/.../sharedworker-import file run alone, 2 per Crane test with one shared and one dedicated worker.

**Fix**: HTML "destroy a document" step 6.2 removes the document's tasks from the task queues without running them. Each port's internal state records its queued tasks (timer and id; a task takes itself off when it runs), and `disentangleIn(realm)` - the unloading cleanup step MessagePort already installs, which runs for every realm that ends - cancels them (`clearTimeout` returning true) and frees them. Not a new threadlocal list (docs/instances.md rule 1): the record lives with the port, and the cleanup already walks the realm's ports.

**Takeaway**: **Data you queue is yours until the task runs, and the task may never run. Tie it to something whose end you hear - the document's destruction removes its tasks - not to the loop's.**
