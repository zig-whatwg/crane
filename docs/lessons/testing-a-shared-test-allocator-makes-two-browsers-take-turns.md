# Testing: A shared test allocator makes two Browsers take turns

**Date**: 2026-10-15
**Lesson**: A cross-thread race test whose two Browsers both allocate from `std.testing.allocator` runs them in lock-step, not at once: give each Browser a DebugAllocator of its own, without stack traces, and the race shows.

**Why**: `std.testing.allocator` is one process-wide DebugAllocator behind one mutex, and in Debug it captures a stack trace on every allocation by unwinding DWARF. Everything a Browser does allocates, so each thread spends most of its time inside that allocator, and the mutex hands the two threads the CPU in turns. A race whose window is a few instructions - an unlocked list link - then almost never sees the other thread inside it. `sample` on the slow, green run showed it: the top frames were `debug.Dwarf.Unwind` and `__ulock_wait`.

**What Happened**: Lane liveclassic's test ran classic scripts on two Browsers on two threads at once, each script linking a record into html.script_execution's process-wide, unlocked `live_classic_scripts` list. With both Browsers on `std.testing.allocator` it ran 16,000 scripts in 95 s and passed 6 of 6 runs on main, and 3 of 3 more under `MallocScribble=1`; an instrumented build showed the links and unlinks of the two threads interleaved one for one, so the overlap was there and only the timing hid it. Giving each Browser `std.heap.DebugAllocator(.{ .stack_trace_frames = 0 })` (its `deinit` still fails the test on a leak) made the same test fail 7 of 7 runs on main in 24 s: a record the list had lost was disposed of as a module script ("upcast of misaligned address ... for type 'v8::Global<v8::Module>'", the address being the record's nonce bytes). With the list on the agent (`AgentHost.classic_scripts`), 0 of 13 runs failed, in 6 s.

**Fix**: In a test that runs Browsers on several threads to find a race, allocate each Browser from its own `DebugAllocator(.{ .stack_trace_frames = 0 })` and check its `deinit()` for leaks; keep `std.testing.allocator` for single-threaded tests (tests/html/instances_classic_scripts_test.zig).

**Takeaway**: **A race test's threads must not share a lock the code under test does not take - std.testing.allocator is one, so give each Browser its own allocator.**
