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
//! Each race needs a process in which nothing has started V8 yet, so those
//! tests skip when something has. Run this file alone, one test per process:
//!   zig build test-launch -Dspec=v8 -Dtest-file=tests/v8/platform_start_once_test.zig -Dlaunch-batch=1

const std = @import("std");
const engine = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;

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
}
