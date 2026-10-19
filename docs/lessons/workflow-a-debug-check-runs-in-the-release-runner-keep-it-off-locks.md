# Workflow: A Debug check runs in the ReleaseSafe runner - keep it lock-free on hot paths

**Date**: 2026-10-19
**Lesson**: The WPT runner is ReleaseSafe, but Crane's own modules keep Debug's builtin.mode
(tests/wpt_runner/build_mode.zig), so every `std.debug.runtime_safety` check in Crane code runs in every
WPT measurement, cost pages included. A "Debug-only" check is production code for cost.

**Why**: It is easy to put an assertion that takes a lock on a hot path in the belief that it costs
nothing outside Debug builds. In this repository the runner every A/B uses is, for Crane's code, a Debug
build with optimizations.

**What Happened**: Lane bfcache-b asserted, on every window timer's run, that the timer's page was not in
the back/forward cache. The check reached the Browser's cache through BrowserScope.existing - a mutex and a
scan of the scope's supplements. The setTimeout(0) burst cost page (crane/bfa-cost-timers.html) measured
4-8% slower than base in 7 alternating pairs. Removing the assertion (holdIfInactive already guards that
path), the clock read per scheduled timer and two new fields of the timer record (a suspension now asks
the native timer for its remaining wait, as WebKit's SuspendableTimer does) brought the 20k frame burst
back to parity (pairwise 0.991); the 50k burst stayed ~4.8% slower, and a `sample` profile of 39 runs
found the timer path's inclusive samples equal within 1% (the hot spot, NativeTimerManager.arm, is the
same in both) - so not every cost-page difference is attributable to work a change adds.

**Fix**: The cache answers "holds?" first from the event loop the caller already has (a cached page
always has a suspended task group there: no lock when there is none); no assertion on the timer task
path; remaining waits read from the native timer at suspend time. Measure, then profile the runner's
CHILD process (`pgrep -P <runner>`): the parent only waits.

**Takeaway**: **Treat a Debug check in Crane code as production code for cost: it runs in the runner
every measurement uses. And profile before attributing a cost-page difference to a change.**
