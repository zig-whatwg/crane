# Architecture: A synchronous navigation still owes its load event

**Date**: 2026-09-22
**Lesson**: `iframe.src = <http url>` loaded the document and fired nothing.

**Why**: `IFrameIntegration.navigateToSrc` fetches, parses and commits before
it returns - Crane has no async navigation. Both places that set an iframe's
src fired `load` only for `data:` and `javascript:`, guarded by a comment
reading "HTTP URLs are async and would need async load event firing". That was
true of the spec and false of this engine: by the time `setSrc` returns, the
HTTP document is already committed.

**What Happened**: every page waiting on an iframe hung to the ceiling. The
WPT helpers are all written as `iframe.addEventListener("load", ...)` around
a src assignment - `waitForIframe`, `setupSentinelIframe`, `insertIframe` -
so this was not a corner. On a 52-file slice of
`navigating-across-documents/replace-before-load/` and
`origin-keyed-agent-clusters/1-iframe/`: **45 TIMEOUT / 7 OK before, 15
TIMEOUT / 37 OK after**.

**Fix**: queue the event as a MICROTASK rather than firing it inline, and
open a `JsScope` before dispatching. Three deferral shapes were tried; the
measurement picked the winner, not the spec:

1. **Synchronous** - wrong. The event arrives before any listener exists:
   `setupSentinelIframe` sets `src`, appends, and only then awaits, and a
   parser-created `<iframe src>` is appended during tree construction, before
   the document's scripts have run at all.
2. **A task**, which is what §4.8.5 actually says - measured WORSE. On the same
   52-file slice, more files in `replace-before-load/location-setter-*` looped
   under the task form than under the microtask form, because delivering later
   let those tests re-navigate. Its supposed advantage - that
   `waitForCompletion` pumps the loop in <=50ms slices against the per-file
   deadline - does not exist either: `V8EventLoop.runOnceBlocking` drains with
   `while (self.tasks.items.len > 0)`, so a task that queues a task never
   returns to the deadline. HTML §8.1.7.3 runs *one* task per turn; this runs
   the transitive closure. **Bounding that drain by the queue length at entry
   would put every runaway task loop back under the per-file ceiling** - left
   alone here only because that queue is shared with worker startup, whose
   comment says it depends on the cascade completing in one call.
3. **A microtask** - what shipped. It drains at the end of the current script,
   by which point the listener is attached. One file
   (`location-setter-during-pageshow.html`) still loops; the supervisor's
   stall watchdog bounds it.

The task attempt also produced a lesson of its own: a callback reached from
the event loop rather than from V8 has **no HandleScope and no entered
context**, so `Event.call_constructor` died in `HandleScope::CreateHandle` -
a **SIGTRAP**, not an error return, so the whole file went CRASH rather than
failing a subtest. 20 of 52 files crashed that way. `v8.JsScope.init` fixes
it, and is kept in the microtask path too: it costs a nested scope and makes
the callback correct wherever it is called from.

Fire on a failed navigation too: §4.8.5 fires load for the error document, and
not firing leaves the page hung.

The deferral token comes from a process-wide counter, not a per-instance one.
The slab recycles instance addresses, so a callback holding a
`*runtime.Instance` can find a different element's state there; a
zero-initialised per-instance counter would match that stale state and
dispatch at an unrelated iframe.

**Takeaway**: **When an engine does synchronously what the spec does
asynchronously, the events still have to fire - and which deferral to use is a
measurement, not a reading of the spec. Whatever you pick, a callback reached
from the event loop rather than from V8 must open its own HandleScope before it
touches a Local, or it SIGTRAPs the whole file instead of failing a subtest.**
