# Architecture: When V8 first collects in a realm, every object needs a stated reason to live

**Date**: 2026-09-26
**Lesson**: The old worker host leaked a HandleScope around worker script, so V8 never collected a wrapper in a worker's isolate; the new host closes its scopes, and every worker-realm object that had been alive only because nothing ever collected broke at once.

**Why**: A platform object must outlive what script holds of it whenever the engine still has work for it. Blink states that reason per class - `HasPendingActivity()` for an ActiveScriptWrappable, `Trace` for a [SameObject] child - and Crane had stated it for none of these, because in a worker it never had to.

**What Happened**: With the worker host moved onto the Engine table (45fa1d65b), in worker variants and nested workers:
- `AbortSignal.timeout(5)` signals nobody referenced were collected before their timer fired (dom/abort/timeout.any.js, "fire in order");
- a started MessagePort nobody referenced was collected before its message arrived, and `channel.port2` - a [SameObject] cached where V8 cannot see it - was collected while its channel lived (webmessaging .any.js worker variants timed out);
- a WebSocket's constructor pinned a wrapper the binding then replaced (see the lesson on Pins in constructors), so the first ~20 sockets of websockets/Create-blocked-port.any.js were freed before their first pump;
- a Worker made inside a worker and held only in a local was collected while its initialization timer, carrying the bare pointer, was pending - a bus error on the next allocation.

**Fix**: State each reason (fffc566c6, 4b80c975b, 2016d4f6c, 45fa1d65b): the Engine table's pending-activity hold (`keepPlatformObjectAlive` / `releasePlatformObject`, which also works before the wrapper exists) for a timeout signal until it fires, a port while started and entangled, a socket until closed, a Worker from construction until it has ended; a Pin from a channel to its ports; tasks that carry an Instance checked by slab generation. And once an object can outlive its document, ask whether its document is fully active before running its tasks (detached-iframe.window.js had passed only because the port was collected).

**Takeaway**: **When a change lets the GC run where it did not, the regressions are old bugs: give each object its reason to live (pending activity, a trace edge, a generation check) - never restore the leak.**
