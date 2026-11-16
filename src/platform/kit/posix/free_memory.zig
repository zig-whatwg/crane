//! platform.releaseFreeMemory over the C library's allocator, on a thread of
//! the platform's own.
//!
//! The calls are the ones WebKit makes for its system malloc
//! (Source/WebKit/WebProcess/glib/WebProcessGLib.cpp and
//! cocoa/WebProcessCocoa.mm, WebProcess::releaseSystemMallocMemory;
//! Source/WTF/wtf/unix/MemoryPressureHandlerUnix.cpp,
//! MemoryPressureHandler::platformReleaseMemory):
//!
//! - glibc: malloc_trim(0). It consolidates every arena, gives back the top
//!   of the main heap and - what no malloc threshold does - every whole page
//!   inside a free block between live ones (malloc/malloc.c mtrim, glibc
//!   2.43). Measured on server1 (lane idle1, 2026-11-16): 275 MB of freed
//!   1,500-byte blocks returned in 8.4 ms, 244 MB of 64 KiB blocks in 5.1
//!   ms; a call with nothing to return 0.02 to 0.43 ms. It does not return
//!   the free top of a thread arena's heap (mtrim trims a top only for the
//!   main arena), and nothing of a free block smaller than a page. It
//!   answers only whether anything was returned, so the bytes are the fall
//!   in resident memory across the call - other threads' work is in that
//!   figure too, and a rise reads as 0.
//! - darwin: malloc_zone_pressure_relief(NULL, 0), every zone, no goal. It
//!   answers the bytes released. On macOS 26 and later the default
//!   allocator's entry for it is a stub (libmalloc
//!   malloc_zone_pressure_relief_fallback): it answers 0 and nothing leaves
//!   the footprint (chat2.local, macOS 27.0.1: all of 250 MB of freed 64 KiB
//!   blocks stayed). Freed pages wait there in a ring only the kernel drains;
//!   the one routine that drains it on request is not public
//!   (mach_vm_deferred_reclamation_buffer_flush) and is not called.
//! - any other C library (musl, bionic): nothing to call; 0.
//!
//! The level changes nothing here: neither call takes one.
//!
//! ## Why a thread of its own
//!
//! malloc_trim can be neither interrupted nor given a time limit, and it
//! takes milliseconds when there is much to return. Run on an event loop's
//! thread, a task posted meanwhile - a worker's reply - would wait for it.
//! Chrome keeps its foreground reclaim to about a millisecond, Firefox's
//! idle purge stops between spans when a task is ready, and WebKit moves
//! the darwin call to a background queue (WebProcessCocoa.mm): so the
//! caller only posts a request here, and one helper thread for the process
//! makes the call. What a release can still delay is an allocation: glibc
//! holds an arena's lock while it trims that arena, one arena at a time, and
//! a thread that allocates from it meanwhile waits for that arena's turn to
//! end.
//!
//! The thread is started by the first request (platform.spawnThread), parks
//! on a futex between requests, and is ended and joined by `stop`
//! (deinitializePlatform); a request it had accepted is served first. One
//! request at a time: a second one while the first waits or runs is not
//! accepted - its caller asks again later.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const clock = @import("clock");
const memory = @import("memory");

/// The call itself, on the calling thread: the bytes returned.
pub fn releaseNow() usize {
    if (comptime builtin.os.tag.isDarwin()) return malloc_zone_pressure_relief(null, 0);
    if (comptime builtin.os.tag == .linux and builtin.abi.isGnu()) {
        const before = memory.residentBytes();
        _ = malloc_trim(0);
        const after = memory.residentBytes();
        return (before orelse return 0) -| (after orelse return 0);
    }
    return 0;
}

/// <malloc.h>, glibc: return free memory to the system, keeping `pad` bytes
/// at the top of the main heap. 1 when any was returned.
extern "c" fn malloc_trim(pad: usize) c_int;

/// <malloc/malloc.h>, darwin: ask `zone` (null: every zone) to release
/// `goal` bytes (0: as much as it can). The bytes released.
extern "c" fn malloc_zone_pressure_relief(zone: ?*anyopaque, goal: usize) usize;

const Request = struct {
    level: platform.MemoryRelease,
    done: platform.MemoryReleaseDone,
};

const Helper = struct {
    /// Protects every field below but `wake`. Never held across a release
    /// or a `done`.
    mutex: std.Io.Mutex = .init,
    /// Bumped by every accepted request and by `stop`: the futex word the
    /// thread parks on.
    wake: std.atomic.Value(u32) = .init(0),
    /// The thread, from the first request until `stop` joins it. OWNED.
    thread: ?platform.Thread = null,
    /// The accepted request the thread has not taken yet.
    pending: ?Request = null,
    /// Whether the thread is inside a release or its `done`.
    busy: bool = false,
    /// `stop` is ending the thread: nothing more is accepted.
    stopping: bool = false,
};

// process-wide: the system allocator is one per process, and so is the thread that asks it for its free memory - whichever Browser's event loop posted the request; every field is read and written under its mutex (std.Io.Mutex) except the futex word, an atomic; the thread is started by the first request and joined by deinitializePlatform
var helper: Helper = .{};

fn lock() void {
    std.Io.Threaded.mutexLockUncancelable(&helper.mutex);
}

fn unlock() void {
    std.Io.Threaded.mutexUnlock(&helper.mutex);
}

/// A futex wait and wake are plain system calls on an address, the same
/// through any `Io.Threaded`: the standard library's static instance (as
/// runtime.TaskSink's wait).
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// platform.releaseFreeMemory: post the request to the helper thread,
/// starting it if this is the first. Never blocks on a release. False - and
/// `done` is never called - while another request waits or runs, while the
/// platform is ending, or when the thread cannot be started.
pub fn request(level: platform.MemoryRelease, done: platform.MemoryReleaseDone) bool {
    lock();
    defer unlock();
    if (helper.stopping or helper.busy or helper.pending != null) return false;
    if (helper.thread == null) {
        helper.thread = platform.spawnThread(.{ .name = .from("crane-memory") }, run, null) catch return false;
    }
    helper.pending = .{ .level = level, .done = done };
    _ = helper.wake.fetchAdd(1, .release);
    futexIo().futexWake(u32, &helper.wake.raw, 1);
    return true;
}

/// The helper thread: serve the request that waits, park until the next,
/// end when `stop` says so and nothing waits.
fn run(_: ?*anyopaque) callconv(.c) void {
    while (true) {
        // Read the word before looking: a request or a stop that lands after
        // the look has bumped it, and the wait below returns at once.
        const seen = helper.wake.load(.acquire);
        lock();
        const taken = helper.pending;
        helper.pending = null;
        if (taken != null) helper.busy = true;
        const stopping = helper.stopping;
        unlock();

        if (taken) |accepted| {
            const start = clock.monotonicNanos();
            const returned = releaseNow();
            const elapsed = clock.monotonicNanos() - start;
            const duration: u64 = @intCast(@min(@max(0, elapsed), std.math.maxInt(u64)));
            accepted.done.call(accepted.done.context, returned, duration);
            lock();
            helper.busy = false;
            unlock();
            continue;
        }
        if (stopping) return;
        futexIo().futexWaitTimeout(u32, &helper.wake.raw, seen, .none) catch {};
    }
}

/// deinitializePlatform: end the helper thread and wait for it. A request it
/// had accepted is served first (its `done` runs before this returns);
/// requests made meanwhile are not accepted. Afterwards a new request starts
/// a new thread - a process that starts the platform again finds it as new.
pub fn stop() void {
    lock();
    helper.stopping = true;
    const thread = helper.thread;
    helper.thread = null;
    unlock();
    _ = helper.wake.fetchAdd(1, .release);
    futexIo().futexWake(u32, &helper.wake.raw, 1);
    if (thread) |t| platform.joinThread(t);
    lock();
    helper.stopping = false;
    unlock();
}

/// Whether the helper thread exists now (tests).
pub fn threadRunning() bool {
    lock();
    defer unlock();
    return helper.thread != null;
}
