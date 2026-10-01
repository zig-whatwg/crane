# Testing: A single-path runner run has no stall watchdog

**Date**: 2026-09-30
**Status** (2026-10-01): fixed - an unsupervised run now carries the supervisor's deadline on a thread of its own (`stall_watchdog.SelfWatchdog`, lane/runner): no progress for `--stall-limit-ms` (150 s) ends it with exit 124 and, if it keeps a journal, a TIMEOUT record. Measured on the case below: traced, `--stall-limit-ms=20000`, ended at 54 s (34 s of traced startup before the file began). A hard limit around a pooled job is still good practice.
**Lesson**: `wpt_runner <path>` runs the file in-process, without the supervisor, so the stall watchdog (which lives in the supervise loop of `--from-file` / `--parallel` runs) never watches it. Under `CRANE_LEAK_TRACES=1` a single allocation-heavy file ran 38 minutes at 100% CPU inside a pooled job and held chat's whole WPT token pool.

**Why**: The per-file ceiling bounds only the wait for `__wpt_complete`; synchronous script and teardown are unbounded, and the watchdog that kills a stalled child exists only where there is a child. `CRANE_LEAK_TRACES=1` switches the runner to a DebugAllocator that captures a six-frame trace on every allocation AND every free - and Zig 0.16's unwinder parses DWARF to do it - so a file that frees hundreds of thousands of objects slows by orders of magnitude.

**What Happened**: A leak-trace measurement of `dom/ranges/Range-surroundContents.html` on main's runner (400,887 ownership checks; 6 s untraced in the sweep) never finished; the integrator stopped it after 38 minutes, with main's gate timers, main's baseline sweep and another lane queued behind it. Run untraced with a hard limit, the same measurement took 8 s: 1,700 leaked allocations on main, 17 on the fixed runner.

**Fix**: For a leak COUNT, run untraced (detection stays on, only the traces go) under a hard limit (`perl -e 'alarm shift; exec @ARGV' 300 <runner> ...` - chat has no `timeout`), detached, outside the pool for one short process. Take traces only on small files, or on a `--from-file` list so the watchdog applies.

**Takeaway**: **A runner process with no supervisor has no watchdog: bound it yourself. And `CRANE_LEAK_TRACES=1` is for small files - count leaks untraced first.**
