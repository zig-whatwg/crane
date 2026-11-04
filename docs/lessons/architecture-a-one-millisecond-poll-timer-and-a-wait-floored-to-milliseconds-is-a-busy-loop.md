# Architecture: A one-millisecond poll timer and a wait floored to milliseconds is a busy loop

**Date**: 2026-11-04
**Lesson**: An idle page with an open WebSocket kept the ReleaseSafe console at 62% of a core, at a prompt, with no script running. The WebSocket drains its connection from a self-rearming 1 ms timer, and the event loop computes its wait in whole milliseconds rounded down, so after every pump the next one reads as "due now" and the turn polls without sleeping until it is.

**Why**: `NativeTimerManager.getNextTimerDeadline` answers whole milliseconds, rounded down, and `pollBlockingEach` sleeps only when that is above 0. A timer armed 1 ms ahead reads as 0 a few microseconds later, so the loop spins through the rest of the millisecond; the WebSocket re-arms the moment it fires (`POLL_INTERVAL_MS = 1` in WebSocket.zig), so the spin never ends while the socket is open. The same floor is the virtual-clock hang of [A clock that stands still must be woken to the exact deadline](architecture-a-clock-that-stands-still-must-be-woken-to-the-exact-deadline.md); on a real clock it costs CPU instead of a hang.

**What Happened**: lane console3 measured the console the user had found slow on dockyard.com. ReleaseSafe and libc malloc took `document.title` from 5-27 s to 1-2 ms and navigation from ~6 s to 0.3 s, but idle CPU at the prompt stayed at 61.6-62.5% (main's Debug console: 100%), while about:blank idled at 1.7%. `sample` of the idle console showed no script at all: `runOnceBlocking`, `AgentFetches.pump` and libcurl's hash walk, 1,449 samples in `mach_absolute_time`, and only 37% of the time asleep. dockyard.com is Phoenix LiveView, which keeps a WebSocket open for the page's life.

**Fix**: queued as EVENT LOOP BLOCKING WAIT (tmp/plans/lane-console-handoff.md): sleep to the exact deadline in ns, never treat "under 1 ms" as due; block on the TaskSink futex bounded by the next timer, slicing only while a fetch is in flight or the engine has pending work (the worker loop's `waitBound` already does); drain a WebSocket on socket readiness, not a 1 ms timer.

**Takeaway**: **A poll timer of one millisecond plus a wait floored to whole milliseconds is a busy loop. Measure idle CPU on a live page - one with a socket open - not only on about:blank, and `sample` the process before blaming the page's script.**
