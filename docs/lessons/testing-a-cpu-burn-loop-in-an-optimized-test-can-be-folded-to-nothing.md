# Testing: A CPU-burn loop in an optimized test can be folded to nothing

**Date**: 2026-11-20
**Lesson**: A test that "burns CPU until a reading moves" must burn by reading a clock it can measure, because an arithmetic loop in a ReleaseSafe build may be computed in closed form and cost nothing.

**Why**: tools/perf_bench's tests build at ReleaseSafe, as the tool does. LLVM turns `for (0..n) |i| x +%= i *% c` into its closed form (a polynomial in n), so `std.mem.doNotOptimizeAway(x)` keeps the RESULT and none of the WORK. The burn the test relied on did not exist.

**What Happened**: tools/perf_bench/proc.zig "this process reads: CPU and a footprint, and instructions where the host counts them" burned 2,000 rounds of a 20,000,000-iteration loop until the process's CPU reading moved. On macOS the reading (proc_pid_rusage) is in nanoseconds and moves at once, so the test passed. On Linux the reading (/proc/<pid>/stat utime + stime) moves in 10 ms ticks, and the only CPU the loop really spent was its own 2,000 /proc reads: 11.5 ms on average on server1, about one tick. So the test was not green in 14 of tmpl1's 20 server1 launches, and failed lanes' Linux gates at random. The launcher's verdicts were FAIL, FLAKY and ORDER-DEPENDENT at random, and it was read as load or as order dependence. A probe built the same way measured one 20,000,000-iteration round at 1-5 us of CPU on chat2 and 0.3-2 us on server1, and replayed the old loop 50 times on server1: 27 failed.

**Fix**:
1. `burnCpu(io, ns)` spends CPU by reading the process's own CPU clock (`std.Io.Clock.cpu_process`, nanoseconds on both hosts) until it has moved `ns`. The work is the clock reads, which no optimizer can drop.
2. The test waits on the condition, the reading moving, one millisecond of burn at a time. The cap is CPU spent, 2 s (200 Linux ticks), and it is only the failure guard.
3. A test pins the primitive: "a CPU burn spends the CPU it is asked for, by the process's own clock". It was red with the old loop on macOS too.

**Takeaway**: **Busy work in an optimized build is whatever the optimizer leaves. Measure the burn with a clock, and pin the burn primitive with its own test, which also fails on the host where the reading is precise.**
