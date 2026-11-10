# Testing: Test that a read faults in a forked child that catches the signal and exits

**Date**: 2026-11-10
**Lesson**: To prove that an address is inaccessible - a released reservation, a guard page, a retired span - read it in a `fork()`ed child whose SIGSEGV and SIGBUS handlers call `_exit(42)`, and have the parent check for exit status 42. The read cannot hurt the test process, and no crash report is written.

**Why**: A stale read that happens to land on mapped memory passes silently (lesson testing-a-use-after-free-that-reads-stale-bytes-passes-unmap-on-free.md), so the test must show the fault itself. Faulting in the test process kills it; a child that dies of the signal makes macOS's ReportCrash write a .ips report per test run, on every pool host.

**What Happened**: Lane h1's red tests for the per-Browser heap (tests/platform/h1_address_space_test.zig, tests/html/h1_browser_heap_test.zig) check that a released range, the cage's guard super page and every link value below the first node super page fault. Each uses `faultsReading(address)`: fork, install the handlers in the child, read one byte through a volatile pointer, `_exit(0)` if it did not fault; the parent waits and maps 0 to false and 42 to true.

**Fix**:

```zig
fn onFault(_: std.posix.SIG) callconv(.c) void { std.c._exit(42); }
// child:
const act: std.posix.Sigaction = .{ .handler = .{ .handler = onFault }, .mask = std.posix.sigemptyset(), .flags = 0 };
std.posix.sigaction(.SEGV, &act, null);
std.posix.sigaction(.BUS, &act, null);
_ = @as(*const volatile u8, @ptrFromInt(address)).*;
std.c._exit(0);
```

**And check the release first**: a small range just released is handed to the next mapping at once (the oss review's probe P4), and `fork()` itself maps memory under ThreadSanitizer - on chat2 a released 4-page range was mapped again before the child read it, and the read did not fault. Check `msync(MS_ASYNC)` answers ENOMEM for the range right after the release, before anything else can map, and release a range too large for an incidental mapping to fill.

**Takeaway**: **Prove a fault in a forked child that catches it: the parent reads an exit status, the test process survives, and no crash report is left on the host.**
