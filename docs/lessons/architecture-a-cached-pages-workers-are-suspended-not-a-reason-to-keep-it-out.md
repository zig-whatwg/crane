# Architecture: A cached page's workers are suspended, and what they post must wait as the page's own task

**Date**: 2026-11-16
**Status** (2026-11-16, lane locks1): Fix step 4 changed. A contention now dooms the cached page and breaks the lock at once, so the request is granted without waiting, as in Chrome (c699bd7e6414). A page whose document holds a lock is kept too. See [A lock broken for a cached page needs a "doomed" mark](architecture-a-lock-broken-for-a-cached-page-needs-a-doom-the-restore-respects.md).
**Lesson**: Keep a page with workers in the back/forward cache by suspending its workers (HTML "run a worker" step 8), and make every cross-thread delivery to the page a global task of its Window, which the event loop keeps with the cached page.

**Why**: HTML has no "worker blocks the bfcache" rule: a worker whose owners' Documents are not fully active is "suspendable" (10.2.3), and step 8 suspends its script until it is not. Chrome, Firefox and Safari all keep and restore such a page (back-forward-cache/eligibility/dedicated-worker.html, shared-worker.html, shared-worker-active-client.window.js pass in all three). A blocker that keeps the page out passes the tests that want it out and fails the four that want it kept - and hides the real work: what keeps a suspended worker's effects from reaching a page that is not shown.

**What Happened**: Crane's Worker and SharedWorker installed bfcache blockers (".declined", "sharedworker"); four html/browsers/browsing-the-web files blocked the 0.1 gate. Lane nav4b2 replaced them with suspension (WorkerLink.suspended, WorkerEventLoop parks between tasks, its timers on a clock that stands still) driven by the cache's store and restore steps, with nested workers walked through the owner_sink chain and shared workers suspended only when no owner Document is fully active. Three paths then still reached a cached page:
- a message, error or start report the worker posted just before its suspension took hold (suspension is at a task boundary, as in Blink and Gecko): it arrives through a TaskSink, so its task names no document, and the window loop ran it in the cached page;
- a message a shared worker - kept running by another owner - posts to the cached page's port: it stayed queued and was never announced again after the restore;
- a SharedWorker constructor's connect task queued just before the page was cached: it joined the owner set as a fully active Document.
And web-locks/bfcache/contention (12 subtests, passing only because the blocker kept the page out) needed Chrome's eviction on contention once a cached page's worker could hold a lock.

**Fix**:
1. Suspend, don't block: store step = `WorkerRegistry.suspendOwnedByRealm` / `SharedWorkerManager.ownerInactive`; restore step = the resume twins; eviction = destroy = the existing unloading cleanup (terminate).
2. A task that reaches a page's object from another thread and is HTML's "queue a global task" re-queues itself through `dom.document_activity.queuedUntilFullyActive(object, run, drop, ctx)` when the Window is inactive: the task names the Window, the loop keeps it in the cached page's group, runs it at the restore and drops it at the eviction. A port that took no message re-enables its end from such a task.
3. Tasks queued on the owner's own loop (a constructor's connect, a start failure) are global tasks from the start: set `.document` to the Window and `.document_generation`.
4. Locks held by a suspended worker: the registry tells each holder on contention (`Delivery.contention`), and a suspended holder asks the window loop to evict the pages keeping it suspended (reason "weblocks-contention", Chrome's; HTML has none).

**Takeaway**: **"Not kept" is a workaround when the spec says "suspended": keep the page, suspend what it owns, and then find every path that reaches the page from another thread - a task posted through a sink names no document, so it runs in a cached page unless it re-queues itself as the Window's global task.**
