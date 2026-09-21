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
    if (cached_io != null) return;
    threaded = .init(gpa, .{});
    seedEnviron(&threaded.?);
    // io() captures &threaded, so the Threaded value must never move after this.
    // It lives in this module's static storage precisely so it cannot.
    cached_io = threaded.?.io();
}

/// Adopt the `Io` the process entry point was handed, instead of building one.
///
/// Prefer this wherever a `std.process.Init` is in hand. `std.start` has already
/// built exactly one `Io.Threaded` for the process, so adopting it keeps the
/// one-per-process invariant this module's header demands rather than installing
/// a second set of SIGIO/SIGPIPE handlers - and it carries the process
/// environment, which a self-built `Threaded` does not (see `seedEnviron`).
pub fn adopt(process_io: std.Io) void {
    std.Io.Threaded.mutexLock(&init_mutex);
    defer std.Io.Threaded.mutexUnlock(&init_mutex);
    if (cached_io != null) return;
    cached_io = process_io;
}

/// Seed a self-built `Threaded` with the real environment block.
///
/// `Io.Threaded.init` starts from `Environ.empty`; only `std.start` populates
/// `environ` (start.zig, `callMainWithArgs`). An `Io` that reports an empty
/// environment spawns children with NO variables at all - no PATH, no HOME.
///
/// That is not theoretical. It is what made `wpt serve` die on
/// `FileNotFoundError: [Errno 2] ... 'sysctl'` in every one of its server
/// subprocesses, surfacing as `error.ServerStartTimeout`, while the byte-for-byte
/// identical command run from a shell worked. Anything reading an env var through
/// this `Io` would likewise have seen nothing.
fn seedEnviron(t: *std.Io.Threaded) void {
    // Windows takes its environment from the PEB, not from a C `envp` array.
    if (@import("builtin").os.tag == .windows) return;
    const c_environ = std.c.environ;
    var n: usize = 0;
    while (c_environ[n] != null) : (n += 1) {}
    const block: std.process.Environ.Block = .{ .slice = c_environ[0..n :null] };
    t.environ = .{ .process_environ = .{ .block = block } };
    t.environ_initialized = block.isEmpty();
}

/// Release the process Io and restore the signal handlers `init` replaced.
pub fn deinit() void {
    std.Io.Threaded.mutexLock(&init_mutex);
    defer std.Io.Threaded.mutexUnlock(&init_mutex);
    if (threaded) |*t| {
        t.deinit();
        threaded = null;
    }
    // Also clears an Io taken by `adopt`, which this module does not own and
    // must therefore not deinit - only forget.
    cached_io = null;
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

test "a self-built Io reports the process environment, not an empty one" {
    // Regression guard. `Io.Threaded.init` leaves `environ` empty; only std.start
    // fills it in. An Io with an empty environment spawns children with no PATH,
    // which is invisible until something exec's a helper and cannot find it.
    if (@import("builtin").os.tag == .windows) return error.SkipZigTest;

    var t: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer t.deinit();

    // Before seeding, the block is empty - this is the defect being guarded.
    try std.testing.expect(t.environ.process_environ.block.isEmpty());

    seedEnviron(&t);

    // PATH is the variable whose absence actually broke the WPT server, so assert
    // on it specifically rather than merely on a non-empty block.
    const path = t.environ.process_environ.getPosix("PATH");
    try std.testing.expect(path != null);
    try std.testing.expect(path.?.len > 0);
}
