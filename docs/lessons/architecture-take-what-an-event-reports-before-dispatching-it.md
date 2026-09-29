# Architecture: Take what an event reports before dispatching it

**Date**: 2026-09-29
**Lesson**: Dispatching an event runs script, and the microtasks that script releases run before the dispatch returns. Anything the event is built from that script can add to must be taken out before the dispatch, or those additions are cleared along with it.

**Why**: `CookieStore`'s `fireChangeEvent` built its CookieChangeEvent from the observer's pending changes, dispatched it, and cleared the list in a `defer`. A listener that resolves a promise releases `await`s that run inside the dispatch. `cookieStore.set()` there records a change and queues the next change task, which it sees as needed. Then the `defer` cleared that change with the ones already reported. The queued task found an empty list, and no event ever came.

**What Happened**: cookiestore/change_eventhandler_for_already_expired.https.window.js went OK -> TIMEOUT once change events existed. Its second test waited forever for an event. A copy of the file's sequence, with a guard that dumps a log at two seconds, showed one event and then nothing:
`EVENT changed=alt-cookie | t1 verified | t2 begins | t2 expired set | t2 alt-cookie=IGNORE | HUNG`.
The first test's `verifyCookieChangeEvent` resolved inside the first event's dispatch. The first test's cleanup and the whole of the second test's setup ran in that same microtask checkpoint.

The fix exposed a second ordering bug with the same cause. Cookie Store promises were settled at once ("indistinguishable to script"). So the next test's listener was added before the cleanup's deletion event fired, and one event carried both tests' changes. The spec settles these promises from "in parallel" steps, which means from a task. Settling them from a task queued behind the change event the call made puts the event first, as in a browser.

**Fix** (d96c3da80, 20a9b6864):
1. `fireChangeEvent` moves `observer.pending_changes` into a local list and empties the observer before it dispatches. Changes made during the dispatch stay for the task they queued.
2. `cookie_values.settledInTask` creates the promise now and settles it from a task on the realm's event loop. The in-parallel results and failures of get, getAll, set and delete go through it. The steps that run before "in parallel" still reject at once.
3. Crane test `crane/net-cookie-change-events.https.html` pins both: a change made in a listener, or in a microtask the listener releases, gets the next event; and a change awaited before a listener is added is not in that listener's event.

**Takeaway**: **Before you dispatch, take ownership of everything the event reports. Script runs inside the dispatch, and so do its microtasks. A cleanup after the dispatch also clears whatever they added.**
