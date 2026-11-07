# Testing: A Child's id belongs to the thread that waits on it

**Date**: 2026-11-07
**Lesson**: In Zig 0.17's std.Io.Threaded, `Child.wait` ends in `childCleanupPosix`, which WRITES `child.id = null` (and closes the pipes) on the waiting thread. Any other thread that still reads `child.id` after handing the Child to a waiter races with that write.

**Why**: The race is invisible in an ordinary build - the read happens long before the child exits, so it always sees the pid - but ThreadSanitizer orders accesses by happens-before, not by wall time: a read on one thread and a later write on another with no synchronisation between them is a data race, and `-Dsanitize-thread` aborts the test.

**What Happened**: tools/perf_bench/runner.zig's test "ending processes by exact pid: TERM first, KILL after the grace time" spawned two children, started a Reaper thread on each (`c.wait(io)`, as launchd reaps Safari), slept 300 ms, and only then read `polite.id.?` and `stubborn.id.?` for the pid list. Under -Dsanitize-thread (found by lane listen1's many-Browsers TSAN run) it crashed alone 2/2: "Write of size 8 ... by thread T1: Io.Threaded.childCleanupPosix Threaded.zig:15906 ... Previous read of size 4 ... by main thread: runner.zig:703". The runner itself was already right: `Process` copies `child.id` into its own `pid` before it starts its waiter thread.

**Fix**: Read every pid (and anything else of the Child) BEFORE starting the thread that waits on it; after that the waiter owns the Child (badd016b029). Green: PASS, and 5 reruns with no ThreadSanitizer line.

**Takeaway**: **Copy a Child's pid before another thread waits on it: std's wait clears `id` on the waiting thread, so a later read from any other thread is a race TSAN reports even when the timing makes it look harmless.**
