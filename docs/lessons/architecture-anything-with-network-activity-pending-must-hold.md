# Architecture: Anything with network activity pending must hold its own wrapper

**Date**: 2026-09-25
**Lesson**: An XHR whose handlers close over nothing is unreachable from JS, so V8 collected it mid-fetch. Its deinit cancelled the fetch, and no event ever fired.

**Why**: XHR §3.2 forbids collecting an XHR with a request outstanding. Blink enforces that with `HasPendingActivity`; Crane had nothing equivalent until asynchronous XHR (the networking lane, increment 2).

**What Happened**: One `garbageCollect()` in a test file collected the XHRs of earlier subtests too, and the whole file timed out with 0 results. `xhr-timeout-longtask.any.js` and `event-error.sub.any.js` looked like timing bugs.

**Fix**: The pending fetch holds the XHR's wrapper through `same_object.Pin`, and releases it when the fetch ends.

**Takeaway**: **When moving work off the call stack, ask what keeps the object alive until the work finishes. A whole-file TIMEOUT with 0 subtests after a GC means something was collected, not that something is slow.**
