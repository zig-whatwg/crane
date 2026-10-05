# Architecture: A thread waits on a futex without the process Io

**Date**: 2026-10-04
**Lesson**: Zig 0.16 moved futexes onto `std.Io` (`io.futexWaitTimeout`, `io.futexWake`) and `std.Thread` has no futex any more; the process's own Io (`host.io()`) is reserved for its filesystem bridge. A worker loop that must sleep until another thread posts uses `std.Io.Threaded.global_single_threaded.io()`, whose futex calls are plain system calls on an address.

**Why**: An event loop on a worker thread has nothing to do most of the time. Polling in 1 ms slices (the window loop's way, since native_timer knows only timers) wakes every idle worker a thousand times a second. A futex word that every post bumps lets the loop sleep until a post, the next timer, or a bound - and a post wakes it at once.

**What Happened**: Writing runtime.TaskSink (workers 1B-i) needed a blocking wait with a timeout. `std.Thread.Futex` is gone in 0.16; `std.Io.Threaded`'s `futexWait`/`futexWake` helpers are private; `host.io()` says "Nothing here should acquire new callers". The static single-threaded instance's futex vtable entries ignore its missing concurrency and cancelation (a raw thread has no cancelation state), and both calls go straight to `__ulock_wait2`/`__ulock_wake` (macOS) or `futex` (Linux).

**Fix**: In src/runtime/task_sink.zig:

```zig
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}
// waiter: read the word BEFORE looking for work, so a post that lands after
// the look has already changed it and the wait returns at once
const seen = self.wake.load(.acquire);
if (self.hasPosted() or self.isClosed()) return;
futexIo().futexWaitTimeout(u32, &self.wake.raw, seen, .{ .duration = .{ .raw = .fromNanoseconds(ns), .clock = .awake } }) catch {};
// poster: append under the lock, then bump and wake
_ = self.wake.fetchAdd(1, .release);
futexIo().futexWake(u32, &self.wake.raw, 1);
```

**Takeaway**: **Block a thread on `global_single_threaded.io()`'s futex, reading the word before checking for work; never poll in slices on a thread that is idle most of the time.**
