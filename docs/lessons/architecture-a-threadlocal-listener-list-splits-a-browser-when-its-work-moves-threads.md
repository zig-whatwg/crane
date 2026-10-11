# Architecture: A threadlocal listener list splits a Browser when its work moves to other threads

**Date**: 2026-10-11
**Lesson**: A threadlocal list of the objects that hear a shared store was correct while every realm of a Browser ran on one thread. Once workers ran on threads of their own, it quietly turned into one list per thread: a change made on a worker's thread was heard only by listeners on that thread, which was none.

**Why**: The cookie jar was already the Browser's, and it was locked for worker threads (workers lane 1A). Its change hook walked `CookieStore.listening`, a `threadlocal` list of the CookieStores that had registered on that thread. A page's CookieStore registers on the window thread. A dedicated worker's `fetch()` stores a response's `Set-Cookie` on the worker's thread, and the jar calls its hook there. The hook found that thread's list empty, so the page's `change` event never came. Nothing failed and nothing logged. The workers lane recorded it as a known gap ("jar hooks per thread"), and no test covered it until instances B3.

**What Happened**: Instances B3 (lane inst3) moved the Browser's shared stores onto its scope: the storage shed, the blob URL store and the jar. A unit test stores a cookie into the Browser's jar from another std.Thread, the way a worker's fetch does. It was red because the page's `cookieStore` heard nothing. The Crane test `crane/in-cookiestore-hears-worker-cookie.https.html` does the same end to end through a dedicated worker's `fetch()` of `/cookies/resources/set.py`.

**Fix**: The listeners became one list per Browser (`dom.cookie_change_listeners`, a BrowserScope supplement under a mutex). The Browser installs that list as its jar's change hook when it makes both, before any realm exists. Each entry records the thread it registered from and retains its realm's task sink.
- A change on the listener's own thread is delivered at once, after the lock is dropped, as before. Delivering on the same thread keeps the old order of a page's own events, and a delivery may run script that ends a listener.
- A change on any other thread is posted through the listener's task sink as a task, with a copy of the cookie. That task checks that the listener still listens, then delivers on the listener's own thread.

The blob URL store raised the same question for a lower layer. Fetch cannot import the store's module, and a process-wide resolver cannot know whose Browser is asking. So the request carries its client's store (`InternalRequest.blob_url_store`), set by "populate request from client", the same way it already carried the jar.

**Takeaway**: **When work moves to another thread, every `threadlocal` registry it used to reach becomes one partition per thread, and nothing reports it. Before moving work across threads, list the thread-scoped state it reads or writes, then give each item its real owner (Browser, agent or realm), with cross-thread delivery through that owner's task sink.**
