//! The process's `std.Io`.
//!
//! Zig 0.16 moved the filesystem, networking, timers and synchronisation onto
//! `std.Io`, which is passed as a parameter the way `Allocator` is. Crane has
//! ~150 filesystem call sites, many of them in leaf code reached from C-ABI
//! callbacks that V8 invokes and that cannot take another parameter.
//!
//! This module owns one `Io.Threaded` for the life of the process so those sites
//! have something to call. It is a BRIDGE, not the destination.
//!
//! ## Why Io.Threaded and not Io.Evented
//!
//! `Io.Evented` is an alias that resolves per-platform (`std/Io.zig:31`):
//! Dispatch on Darwin/iOS, Uring on Linux/Android, Kqueue on the BSDs, and `void`
//! wherever `fiber.supported` is false - which excludes armv7 Android.
//!
//! More decisively, only `Io.Threaded` implements networking. Counting the
//! `net*Unavailable` stubs in each backend's vtable: Threaded 0, Dispatch 15,
//! Uring 13. So Evented cannot carry a browser's network stack on any platform
//! Crane targets, and running V8 on fibers is independently unsafe - Uring
//! work-steals fibers across OS threads and Dispatch uses a concurrent GCD queue,
//! while a V8 isolate is thread-affine and checks stack limits it recorded at
//! entry.
//!
//! ## The destination
//!
//! Per-agent `Io` reached through `ContextData`, so each agent (one isolate, one
//! thread) carries its own. When that lands, callers take `io` as a parameter and
//! this module shrinks to the single process-wide instance that `Host.init`
//! creates. Nothing here should acquire new callers in the meantime.
//!
//! ## Hazard: signals
//!
//! `Io.Threaded.init` installs process-wide `SIGIO` and `SIGPIPE` handlers and
//! restores them in `deinit`. Crane links V8, which installs its own handlers,
//! and the WPT runner forks. Exactly one `Io.Threaded` may be live per process -
//! hence the singleton - and `deinit` must run symmetrically, because in the
//! iOS/Android static-library build this mutates the *host application's* signal
//! disposition.

const std = @import("std");

var threaded: ?std.Io.Threaded = null;
var cached_io: ?std.Io = null;
var init_mutex: std.Io.Mutex = .init;

/// Initialise the process Io. Call once, early, from `main` (or from
/// `whatwg_runtime_init` in the library build).
///
/// `gpa` must outlive the process and must itself be thread-safe:
/// `Io.Threaded` allocates from it on worker threads.
pub fn init(gpa: std.mem.Allocator) void {
    std.Io.Threaded.mutexLock(&init_mutex);
    defer std.Io.Threaded.mutexUnlock(&init_mutex);
    if (threaded != null) return;
    threaded = .init(gpa, .{});
    // io() captures &threaded, so the Threaded value must never move after this.
    // It lives in this module's static storage precisely so it cannot.
    cached_io = threaded.?.io();
}

/// Release the process Io and restore the signal handlers `init` replaced.
pub fn deinit() void {
    std.Io.Threaded.mutexLock(&init_mutex);
    defer std.Io.Threaded.mutexUnlock(&init_mutex);
    if (threaded) |*t| {
        t.deinit();
        threaded = null;
        cached_io = null;
    }
}

/// The process Io.
///
/// Lazily initialises against `std.heap.smp_allocator` if `init` was never
/// called, so a leaf utility or a unit test cannot fail merely because nobody
/// wired up a `main`. Prefer calling `init` explicitly from the entry point: the
/// lazy path cannot choose the allocator, and in tests `std.testing.io` is better
/// still because it participates in leak checking.
pub fn io() std.Io {
    if (cached_io) |i| return i;
    init(std.heap.smp_allocator);
    return cached_io.?;
}

/// `std.Io.Dir.cwd()` bound to the process Io - the direct replacement for
/// `std.fs.cwd()`, whose methods now each take an Io.
///
/// `cwd()` itself takes no Io; only the operations on the returned Dir do. This
/// helper exists so call sites read `host.cwd().openFile(host.io(), path, .{})`
/// rather than reaching for two modules.
pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}

test "io() is stable across calls" {
    const a = io();
    const b = io();
    try std.testing.expectEqual(a.userdata, b.userdata);
    try std.testing.expectEqual(a.vtable, b.vtable);
}

test "cwd is usable for a real filesystem operation" {
    // Proves the Io is wired, not merely constructed.
    var dir = try cwd().openDir(io(), ".", .{ .iterate = true });
    defer dir.close(io());
}
