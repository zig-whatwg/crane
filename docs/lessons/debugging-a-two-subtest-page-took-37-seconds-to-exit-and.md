# Debugging: A two-subtest page took 37 seconds to exit, and none of it was the test

**Date**: 2026-09-22
**Lesson**: `wpt_runner` ran a 2-subtest page in 50ms and then spent 37 seconds
exiting. A binary built before the day's changes took 31 seconds on the same
page, so this was never new - nobody had ever timed a runner's exit.

**Why**: the runner used `init.gpa`, a `DebugAllocator(.{})` whose Debug-mode
default is `stack_trace_frames = 6`. Every allocation and every free captures a
six-frame trace, and Zig 0.16's unwinder parses DWARF CFI byte by byte from a
138 MB debug binary to do it. Tearing down one page frees hundreds of thousands
of objects. `sample` showed 99% CPU in `Io.Reader.takeLeb128` under
`captureCurrentStackTrace`, after the test had finished.

**What it cost**: standalone runs pay it once at exit, so any `timeout` under
~40s reported "NO REPORT" for a run that had actually finished - which is how
`custom-elements/connected-callbacks.html` was misread as still crashing after
its crash was fixed. The runner's own "Duration" line is test time, not process
time, which is why this never showed in a log.

**Fix**: the runner owns a `DebugAllocator(.{ .stack_trace_frames = 0 })`.
Leak detection - the count and the addresses - survives; the per-operation
unwinding does not. `CRANE_LEAK_TRACES=1` selects the six-frame allocator for a
run where the traces are the point.

**Takeaway**: **Time the process, not the test.** A debug allocator that
captures a trace per operation turns teardown into the dominant cost of a
short run, and it hides behind every generous timeout.
