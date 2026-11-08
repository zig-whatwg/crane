//! V8's platform starts once per process, whichever threads ask for it first.
//!
//! V8 allows one start per process: V8::InitializePlatform and V8::Initialize
//! advance a process-wide state machine and FATAL on a second or concurrent
//! start ("Wrong initialization order", "Multiple threads are initializating
//! V8": 13.1.203 src/init/v8.cc AdvanceStartupState). A host starts it once,
//! at process start (engine.initializeEngine, from crane.Process.init), as
//! Chromium's gin does (gin/v8_initializer.cc V8Initializer::Initialize, the
//! flags set inside the same start). An isolate made before that - a test, a
//! tool - starts it there instead (v8_Isolate_New's lazy start).
//!
//! That lazy start was guarded by an unlocked bool. Two threads making the
//! process's first isolates at once both read it false, both replaced the
//! platform, and the second V8::InitializePlatform aborted:
//! template_registry_isolation_test's two-thread test crashed every time it
//! ran alone (lane tlaunch2, 2026-11-01; 6/6 at one test per process).
//!
//! The start is now one v8_Platform_Start under a lock, its flags set
//! inside it, and an isolate made first starts V8 with the runtime flags, as
//! the host's start does (ffi.v8_Isolate_New). A start that asks for other
//! flags than V8 started with is told so, and its caller says so at err
//! level: V8's flags freeze when it starts.
//!
//! Each race needs a process in which nothing has started V8 yet, so those
//! tests skip when something has. Run this file alone, one test per process:
//!   zig build test-launch -Dspec=v8 -Dtest-file=tests/v8/platform_start_once_test.zig -Dlaunch-batch=1

const std = @import("std");
const builtin = @import("builtin");
const engine = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;

/// The flags V8's start applied in this process.
fn startFlags() ![]const u8 {
    return std.mem.span(ffi.v8_Platform_StartFlags() orelse return error.V8NotStarted);
}

/// Threads released together: each waits in `arrive` until all have
/// arrived, so their first V8 calls overlap rather than run in turn.
const StartGate = struct {
    expected: usize,
    arrived: std.atomic.Value(usize) = .init(0),

    fn arrive(self: *StartGate) void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        while (self.arrived.load(.acquire) < self.expected) std.atomic.spinLoopHint();
    }
};

const thread_count = 8;

/// One thread's part: make an isolate the moment the gate opens, end it.
const LazyStart = struct {
    gate: *StartGate,
    made: bool = false,

    fn run(self: *LazyStart) void {
        self.gate.arrive();
        const isolate = ffi.v8_Isolate_New() orelse return;
        self.made = true;
        ffi.v8_Isolate_Dispose(isolate);
    }
};

test "threads making the process's first isolates at once start V8 once" {
    if (ffi.v8_Platform_IsInitialized()) return error.SkipZigTest;
    var gate: StartGate = .{ .expected = thread_count };
    var parts: [thread_count]LazyStart = undefined;
    var threads: [thread_count]std.Thread = undefined;
    for (&parts, &threads) |*part, *thread| {
        part.* = .{ .gate = &gate };
        thread.* = try std.Thread.spawn(.{}, LazyStart.run, .{part});
    }
    for (threads) |thread| thread.join();
    for (parts) |part| try std.testing.expect(part.made);
    try std.testing.expect(ffi.v8_Platform_IsInitialized());
    // Started as a process starts it, by whichever thread was first.
    try std.testing.expectEqualStrings(v8.snapshot_loader.RUNTIME_V8_FLAGS, try startFlags());
}

/// The host's part of the next race: the engine's own start, as
/// crane.Process.init makes it.
const HostStart = struct {
    gate: *StartGate,
    result: engine.Error!void = {},

    fn run(self: *HostStart) void {
        self.gate.arrive();
        self.result = engine.initializeEngine(.{});
    }
};

test "the engine's start racing isolates made without it: V8 starts once and every caller gets it" {
    if (ffi.v8_Platform_IsInitialized()) return error.SkipZigTest;
    var gate: StartGate = .{ .expected = thread_count };
    var host: HostStart = .{ .gate = &gate };
    var parts: [thread_count - 1]LazyStart = undefined;
    var threads: [thread_count]std.Thread = undefined;
    threads[0] = try std.Thread.spawn(.{}, HostStart.run, .{&host});
    for (&parts, threads[1..]) |*part, *thread| {
        part.* = .{ .gate = &gate };
        thread.* = try std.Thread.spawn(.{}, LazyStart.run, .{part});
    }
    for (threads) |thread| thread.join();
    try host.result;
    defer engine.deinitializeEngine();
    for (parts) |part| try std.testing.expect(part.made);
    try std.testing.expect(ffi.v8_Platform_IsInitialized());
    // Whichever started it, with the same flags: initializeEngine found the
    // flags it asks for (a conflict would have logged an error).
    try std.testing.expectEqualStrings(v8.snapshot_loader.RUNTIME_V8_FLAGS, try startFlags());
}

test "the engine's start after an isolate made without it finds the flags it asks for" {
    if (ffi.v8_Platform_IsInitialized()) return error.SkipZigTest;
    // A test or tool that makes an isolate first: V8 starts here.
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Dispose(isolate);
    try std.testing.expectEqualStrings(v8.snapshot_loader.RUNTIME_V8_FLAGS, try startFlags());
    // The host's start then asks for the same flags: no conflict to report.
    try std.testing.expectEqual(ffi.PlatformStart.already_started, ffi.v8_Platform_Start(v8.snapshot_loader.RUNTIME_V8_FLAGS));
    try engine.initializeEngine(.{});
    engine.deinitializeEngine();
}

test "a start that asks for other flags than V8 started with is told so, and V8 keeps its own" {
    // Any process: V8 starts here, or started before this test.
    try engine.initializeEngine(.{});
    defer engine.deinitializeEngine();
    const started_with = try startFlags();
    // The same flags, by value, and no flags at all: nothing to report.
    const same = try std.testing.allocator.dupeSentinel(u8, started_with, 0);
    defer std.testing.allocator.free(same);
    try std.testing.expectEqual(ffi.PlatformStart.already_started, ffi.v8_Platform_Start(same.ptr));
    try std.testing.expectEqual(ffi.PlatformStart.already_started, ffi.v8_Platform_Start(null));
    // Other flags: told, not applied (setting a flag after V8 started is a
    // fatal CHECK, so this would have aborted had the start tried).
    try std.testing.expectEqual(ffi.PlatformStart.started_with_other_flags, ffi.v8_Platform_Start("--crane-flags-no-start-applies"));
    try std.testing.expectEqualStrings(started_with, try startFlags());
}

/// Whether libplatform can allocate a memory protection key here: V8 has
/// PKU write protection only on x86-64 Linux (13.1.203
/// src/base/build_config.h, V8_HAS_PKU_JIT_WRITE_PROTECT), and its
/// DefaultThreadIsolatedAllocator gets a key only where the CPU has PKU and
/// the kernel enabled it (/proc/cpuinfo's "ospke").
fn memoryProtectionKeysAvailable() bool {
    if (builtin.os.tag != .linux or builtin.cpu.arch != .x86_64) return false;
    const io = std.testing.io;
    const cpuinfo = std.Io.Dir.cwd().readFileAlloc(io, "/proc/cpuinfo", std.testing.allocator, .limited(4 << 20)) catch return false;
    defer std.testing.allocator.free(cpuinfo);
    var flags = std.mem.tokenizeAny(u8, cpuinfo, " \t\n");
    while (flags.next()) |flag| if (std.mem.eql(u8, flag, "ospke")) return true;
    return false;
}

/// Whether this process's start made V8's platform before any thread: the
/// Crane test runner calls engine.initializeBeforeThreadCreation() first in
/// main, as every host's main does, unless CRANE_TEST_ENGINE_EARLY=0 (build.zig
/// runs this file both ways: `addEngineLateRun`).
fn engineMadeEarly() bool {
    const value = std.testing.environ.getPosix("CRANE_TEST_ENGINE_EARLY") orelse return true;
    return !std.mem.eql(u8, value, "0");
}

test "V8 gets thread isolation exactly when the process start made its platform before any thread, on a CPU with memory protection keys" {
    // Made first in main: every thread a test makes inherits the key, and the
    // races above run with V8's thread isolation on. Skipped - the late runs:
    // the races above start V8 on a later thread beside others, and V8 must
    // then have no thread isolation, or the threads that existed before its
    // key fault on their first read of its JSDispatchTable (x86-64 Linux).
    if (!engineMadeEarly()) {
        // The fallback: V8 started by an isolate made now, or earlier by a
        // race above, gets no allocator.
        const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
        ffi.v8_Isolate_Dispose(isolate);
        try std.testing.expect(!ffi.v8_Platform_HasThreadIsolation());
        return;
    }
    try std.testing.expectEqual(memoryProtectionKeysAvailable(), ffi.v8_Platform_HasThreadIsolation());
}
