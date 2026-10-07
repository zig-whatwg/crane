# Architecture: A callback can end its own environment

**Date**: 2026-10-05
**Lesson**: When a task invokes script, the script can run the environment's end - a frame's lock callback that calls `frame.remove()` runs the unloading document cleanup steps for that frame, synchronously, inside the callback - so the end must not free what the running task still uses.

**Why**: Web Locks keeps a record per request (its promise, callback, signal) on the environment's LockManager. Two things free a record: the task that delivers the request's grant (once its callback has run), and the environment's end ("terminate remaining locks and requests", run from `dom.unloading_cleanup`), which frees the records still waiting. The grant task looked the record up, invoked the callback, then went on to make the waiting promise and react to it. The callback removed its own frame; the frame's cleanup step saw a record still "pending" and freed it; the task then wrote into the freed record and released its promise capability a second time.

**What Happened**: web-locks/frames.https.html ("Removed Frame as lock is granted": `frame.contentWindow.navigator.locks.request(res, () => { frame.remove(); ... })`) crashed the runner at the next navigation, with a segfault in `v8_Global_Dispose` under `LockManager.waitingDropped` - the realm's end dropping the reaction of a record whose memory had been reused. The ifAvailable path (callback invoked with null, record freed by a `defer`) had the same double free.

**Fix**: A record has a third phase, `.running`, set by the task BEFORE it creates the Lock and invokes the callback. The environment's end frees only `.pending` records (those no task holds); a `.running` record stays with its task, which finishes it whatever the callback did - its lock was already released by the termination, and releasing it again is harmless. Two Crane cases (crane/wl-frame-end.https.html: a frame removed by its own lock callback, and by its own ifAvailable callback) crash without the phase and pass with it.

**Takeaway**: **Before freeing per-environment records at the environment's end, ask which of them a task is in the middle of using: any callback the task invokes can end the environment re-entrantly. Mark the record as the task's before the script runs, and let the end skip it.**
