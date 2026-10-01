# Architecture: A deferred read defers the peer too - Nagle and the delayed ACK

**Date**: 2026-09-30
**Lesson**: A single-threaded engine that reads its sockets only between tasks
does not just learn late what has arrived: it can make the rest arrive late. A
peer behind Nagle holds its next small segment until the first is
acknowledged, and the client kernel sends that ACK on its delayed-ACK tick or
when the application reads. So the first read after a long task releases the
rest of the response one round trip later - after a timer that fired at the
same moment has already judged it.

**Why**: wptserve writes a response's status line and each header line with a
separate unbuffered `send()` (`socketserver` wfile, wbufsize 0). A browser's
network thread reads the first segment the moment it arrives; the ACK follows
and the whole response is in within a millisecond. Crane's networking advances
only between tasks.

**What Happened**: `xhr/xhr-timeout-longtask.any.js` (timeout 150 ms, response
at ~100 ms, a 200 ms long task after send()) passed or failed by where the
delayed-ACK tick fell: 2/2 in 8 of 13 runs on main. Traced (through a pipe -
see debugging-the-runner-writes-its-log-positionally-trace-through-a-pipe.md):
the request was on the wire at send(); in every failure the timer at ~201 ms
found the header block incomplete before and after its one network step, and
one more 1 ms socket wait completed it.

**Fix**: INTERIM `async_fetch.catchUp(fetch_slot, budget_ms)`: before a
deadline is judged, while the response has started arriving, pump and wait on
the sockets (bounded, inert - no script, no events). It emulates the reads a
network thread would have made during the long task. The real fix is
networking that progresses while script runs. `fetch()` with
`AbortSignal.timeout()` has the same shape and is not covered yet.

**Takeaway**: **"Give the network one step" is not enough after a long task:
the step itself is what releases the rest. Let a response that has started
arriving finish arriving before a timer decides against it.**
