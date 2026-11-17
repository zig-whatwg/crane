# Architecture: A task that waits in a sink must not hold a reference to the sink's owner

**Date**: 2026-11-17
**Lesson**: A cross-thread task whose data is a counted reference to the object that owns the sink it waits in is a reference cycle, and only the sink's close ends it - so on any path where the loop never starts, or never closes its sink, the owner is never freed.

**Why**: A posted task stays in the TaskSink's inbox until the receiving loop takes it or the sink is closed (`TaskSink.close` drops what is queued). A WorkerLink owns its worker's sink (`worker_sink`, released by the link's last `release`). A task queued in that sink with `data = link.retain()` gives: link -> sink -> task -> link. The link's count cannot reach zero while the task is queued, and the sink is closed only by `WorkerEventLoop.deinit` - which never runs when the worker's loop was never made (its init failed, its thread was never spawned). The existing cross-thread tasks to a worker do not have this shape: a message task owns its message, and the wake task carries null.

**What Happened**: Lane mp1 delivered the OS's memory-pressure event: a critical event posts one collection task to every registered worker's sink (`WorkerRegistry.collectUnderPressure`), and the task needs the worker's agent on the worker's own thread. The approved design said `data = link.retain(), drop = link.release()` - the pattern the worker's END task uses, which is posted to the OWNER's sink, not the link's own. Reading where the worker's sink is closed (one place, the loop's deinit) showed the cycle before any test ran. The fix needs no reference at all: the task runs only inside the worker's loop, and the worker's thread holds the worker side's reference from before the loop is made until after it ends (worker_thread.zig `main`), so the link is alive whenever the task can run; a task that never runs is dropped without touching its data.

**Fix**:
1. Before giving a posted task a counted reference, ask who owns the sink it will wait in. If that owner is (or is kept by) the referenced object, the reference is a cycle.
2. Prefer a borrowed pointer when the receiving loop's own lifetime already covers the object: the loop's thread holds it for as long as tasks can run, and `drop` does nothing. The window loop's pressure task carries the loop itself the same way.
3. Pin both ends with a test on std.testing.allocator: post to a worker that is terminated before its loop runs the task, and to one terminated before its script ran (tests/html/mp1_memory_pressure_test.zig).

**Takeaway**: **A reference carried by a queued task is only as safe as the queue's close: when the task waits in a sink its own referent owns, carry a borrowed pointer the receiving loop's lifetime already covers, never a counted one.**
