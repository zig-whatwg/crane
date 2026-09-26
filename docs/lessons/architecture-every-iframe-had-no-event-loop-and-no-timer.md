# Architecture: Every iframe had no event loop and no timer

**Date**: 2026-09-22
**Lesson**: A child context inherited an event loop only from the parent
ENTRY's own `V8EventLoop`, which a context the browser registers does not own
- so every iframe's runtime context had `event_loop = null` and `timer =
null`, and everything an impl queues from an iframe took its no-loop fallback
and ran inline.

**What Happened**: `window[0].postMessage(m, "*")` fired before the next line
could set `window[0].onmessage` (`webmessaging/without-ports/017.html`), and
an iframe's own deferred events - its load event, its scripts' error events -
went out before their listeners existed. It was invisible because every
fallback is "deliver now", which is right often enough to pass.

**Fix**: `context_manager.inheritedEventLoop` takes the parent entry's loop
when it owns one and otherwise the parent RUNTIME context's loop and timer.
Both child paths use it.

**Takeaway**: **A "no loop, run it now" fallback is a silent mode switch.
Grep `getOptionalEventLoop() orelse` and `getOptionalTimer() orelse` and ask
which contexts actually take the fallback - one probe from inside an iframe
answers it.**
