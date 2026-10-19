# Workflow: A Debug check runs in the ReleaseSafe runner - keep it lock-free on hot paths

**Date**: 2026-10-19
**Lesson**: The WPT runner is ReleaseSafe, but Crane's own modules keep Debug's builtin.mode
(tests/wpt_runner/build_mode.zig), so `std.debug.runtime_safety` checks in Crane code run in every WPT
measurement. A "Debug-only" assertion that takes a lock on a hot path shows up in the cost pages.

**Why**: The assertion that no timer runs for a cached page asked the Browser's back/forward cache,
which it reached through BrowserScope.existing - a mutex and a scan of the scope's supplements - on every
timer fire. setTimeout(0) bursts measured 4-9% slower (crane/bfa-cost-timers.html, 7 alternating pairs).

**What Happened**: The first cost-page round (lane bfcache-b) passed the task page and failed the timer
page by more than the 3% bar; the second confirmed it. Two costs were on the path: the assertion's lock,
and a clock read per scheduled timer for its due time.

**Fix**: The cache answers "holds?" first from the event loop the caller already has (a page in the cache
always has a suspended task group there, so a loop with none holds no page: no lock), and a timer armed
with no delay records no due time (it is due at once whenever it is suspended), so a burst reads no clock.

**Takeaway**: **Treat a Debug check in Crane code as production code for cost: it runs in the runner every
measurement uses.**
