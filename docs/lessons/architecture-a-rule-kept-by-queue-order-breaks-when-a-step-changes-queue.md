# Architecture: A rule kept by queue order breaks when a step changes queue

**Date**: 2026-10-04
**Lesson**: HTML discards a closing worker's tasks. Crane kept that rule for a worker's MessagePorts only because the worker's teardown timer was armed before the port's delivery timer and so ran first, ending the realm the delivery then found gone. When port deliveries became tasks drained before the timers, the rule silently stopped holding.

**Why**: While a worker's tasks run as timers on its creator's loop, nothing asks whether the worker is closing before a port task runs in its realm. The discard was an accident of ordering: close() armed the teardown, the next line posted to a port, and timers fire in the order they were armed. Nothing stated the rule, so nothing kept it when the order changed.

**What Happened**: Workers 1B-i moved MessagePort onto cross-thread channels (dom/port_channels.zig): a port's "has messages" is a task posted to its realm's TaskSink, run by the window loop before that turn's timers (so a message beats a setTimeout(0) armed after it, as in browsers). The paired pre-check against the frozen main runner showed webmessaging/message-channels/worker-post-after-close.any.js go OK -> ERROR: the worker called close(), made a MessageChannel and posted to it, and the message - now delivered before the teardown timer - ran the worker's handler, which posted "message received!" to the page.

**Fix**: State the rule where the task runs: MessagePort's delivery and close hooks return when the port's realm is a closing worker's (`worker_host.scopeClosing`, as BroadcastChannel already asks). Once a worker runs on its own thread (1B-ii), its own loop discards the tasks itself: it stops running tasks when the closing flag is set and drops what is queued and posted at its end.

**Takeaway**: **When a step moves to another queue, find every rule that held only because of the old queue's order - a closing worker's tasks discarded because its teardown ran first - and make each one an explicit check. A paired run of the area's files on the frozen base runner finds them before a sweep does.**
