# Architecture: A lock broken for a cached page needs a "doomed" mark that the restore checks under the same lock

**Date**: 2026-11-16
**Lesson**: To break a cached page's Web Lock at once, as Chrome does, first mark the page doomed in the back/forward cache, under the lock that a restore's `take()` also takes. If a contention merely asks for an eviction later, a restore can win the race and show a page whose lock was taken away without a word.

**Why**: Chrome keeps a page that holds a lock (and a page whose worker holds one). When another context contends for the lock, Chrome evicts the page and breaks the lock synchronously (Chromium c699bd7e6414), so the contending request, ifAvailable too, is granted at once. Firefox and Safari grant it at once as well: Firefox never kept the page, and Safari released the locks when it stored the page. Crane's eviction runs on the window thread, at a task. The contention can come from any thread (a worker's request). So between the contention and the eviction, a traversal can still `take()` the page and restore it.

**What Happened**: Lane nav4b2 made contention with a suspended worker's lock post an eviction task, and the lock stayed held until the page's end. An ifAvailable request therefore got null, where all three browsers grant it. Lane locks1 then kept pages whose document holds a lock (Chrome + Safari keep them; Chrome + Firefox do not restore them after contention), and main asked for the synchronous break. A break is safe only if the page can never run script again. The cache's entries belong to the window thread, so the fix gave the cache a mutex over its entries list and an `Entry.doomed` flag. `doomRealms` (any thread, all or none) and `take()` decide under that mutex. The doom wins, and the traversal loads the page again; or the take wins, and the doom finds no page and nothing breaks. A shared worker is also closed under its manager's lock, so a page that connects meanwhile gets a new worker instead of resuming one that lost its lock.

**Fix**:
1. `dom.bfcache.doomRealms(scope, realms)`: the kept pages holding these realms (their own, or a frame's) can never be restored. It succeeds for all of them or for none.
2. `BackForwardCache`: `mutex` guards every change to the entries list (store, take, evictAt) and `doomed`. `take()` refuses a doomed page and queues its eviction.
3. Each contention hook (Delivery.contention) answers true only after it has doomed the page. The registry then breaks the lock (Chrome's BreakLock) and processes the queue. A query only notifies (Chrome's QueryState).
4. `dom.bfcache.queueRealmEvictions` posts one eviction task through a window-loop sink, for documents and workers alike.
5. Lock order: the web-locks registry, then the worker registry, then the shared worker manager, then the cache (a leaf).

**Takeaway**: **Taking something away from a cached page is only safe once a one-way "doomed" mark makes its restore impossible, and that mark must be decided under the same lock as the restore's take. A queued eviction does not close the race.**
