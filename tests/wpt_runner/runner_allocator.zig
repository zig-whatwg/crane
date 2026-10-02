//! The WPT runner's allocators, pinned so they behave the same in every build
//! mode the runner is built in.
//!
//! The runner builds Debug by default and ReleaseSafe on request
//! (build.zig, `-Dwpt-runner-optimize`), and what a run reports must not depend
//! on which.
//!
//! `std.heap.DebugAllocator`'s defaults do depend on it:
//!
//! - `safety` defaults to `std.debug.runtime_safety`: true in Debug and
//!   ReleaseSafe, false in ReleaseFast. It gates double-free detection
//!   ("Double free detected", the line sweep logs are grepped for) and the leak
//!   report at `deinit`. Pinned to true here, so neither can vanish with a mode.
//! - `stack_trace_frames` defaults to 6 in Debug and 0 in every release mode.
//!   The fast allocator wants 0 in every mode (see `Fast`); the traced one
//!   (`CRANE_LEAK_TRACES=1`) exists for its traces, and a ReleaseSafe runner
//!   would otherwise give it none.
//!
//! std-only, so `zig build test` runs these tests (main.zig links V8 and never
//! runs its own).

const std = @import("std");

/// The sweep allocator: leak and double-free DETECTION, no per-operation
/// stack capture.
///
/// A DebugAllocator that captures a trace per allocation and per free made a
/// two-subtest page take 37 seconds to exit: Zig 0.16's unwinder parses DWARF
/// CFI byte by byte for every capture, and tearing down one page frees
/// hundreds of thousands of objects
/// (docs/lessons/debugging-a-two-subtest-page-took-37-seconds-to-exit-and.md).
/// Zero frames keeps the count and the addresses of every leak and every
/// double free.
pub const fast_config: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 0,
    .safety = true,
};

/// `CRANE_LEAK_TRACES=1`: the same checks with six-frame traces, for the run
/// where the traces are the point (they named the setTimeoutCallback and
/// ProgressEvent leaks, and the two frees of every double free since).
pub const traced_config: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 6,
    .safety = true,
};

pub const Fast = std.heap.DebugAllocator(fast_config);
pub const Traced = std.heap.DebugAllocator(traced_config);

/// Whether `CRANE_LEAK_TRACES` asks for the traced allocator: set, non-empty,
/// and not starting with '0'.
pub fn wantsTraces(value: ?[]const u8) bool {
    const v = value orelse return false;
    return v.len != 0 and v[0] != '0';
}

/// Error-level reports DebugAllocator has logged in this process (a double
/// free, an invalid free, each leaked address at deinit). DebugAllocator logs
/// and carries on, so this count is the only trace of a report besides the log
/// line itself; the runner's log function feeds it (`noteLog`).
var reports: std.atomic.Value(usize) = .init(0);

/// Called by the runner's `std_options.logFn` for every message it logs.
pub fn noteLog(comptime level: std.log.Level, comptime scope: @TypeOf(.enum_literal)) void {
    if (level == .err and scope == .DebugAllocator) _ = reports.fetchAdd(1, .monotonic);
}

pub fn reportCount() usize {
    return reports.load(.monotonic);
}

pub const SelfCheck = struct {
    double_free_reported: bool,
    leak_reported: bool,

    pub fn passed(self: SelfCheck) bool {
        return self.double_free_reported and self.leak_reported;
    }
};

/// Seed one double free and one leak in a private `Fast` allocator and say
/// whether DebugAllocator caught each - `wpt_runner --allocator-self-check`.
///
/// Only meaningful inside the runner, whose log function calls `noteLog`; the
/// reports also reach stderr as "Double free detected" and "memory address ...
/// leaked", which is what a sweep log is grepped for. Not run by the unit
/// tests: the test runner fails any test that logs an error.
pub fn selfCheck() SelfCheck {
    var gpa: Fast = .{};
    const a = gpa.allocator();

    // A neighbour in the same size class keeps the slot's bucket mapped, so the
    // second free reaches the used-bit check rather than an unmapped page.
    const neighbour = a.create(u64) catch return .{ .double_free_reported = false, .leak_reported = false };
    const twice = a.create(u64) catch return .{ .double_free_reported = false, .leak_reported = false };
    a.destroy(twice);
    const before = reportCount();
    a.destroy(twice);
    const double_free_reported = reportCount() > before;

    // `neighbour` is never freed: the leak.
    _ = neighbour;
    const leak_reported = gpa.deinit() == .leak;
    return .{ .double_free_reported = double_free_reported, .leak_reported = leak_reported };
}

const testing = std.testing;

test "both allocators keep double-free and leak detection in every build mode" {
    // The default is std.debug.runtime_safety, which is false in ReleaseFast:
    // a runner built that way would report no double free and no leak, and
    // every sweep log would read clean. Pinned, not inherited.
    try testing.expect(fast_config.safety);
    try testing.expect(traced_config.safety);
}

test "the fast allocator captures no traces, the traced one six, whatever the mode" {
    // DebugAllocator's default is 6 frames in Debug and 0 in release modes, so
    // inheriting it would make the fast allocator slow in Debug (the 37-second
    // exit) and the traced allocator useless in ReleaseSafe.
    try testing.expectEqual(@as(usize, 0), fast_config.stack_trace_frames);
    try testing.expectEqual(@as(usize, 6), traced_config.stack_trace_frames);
}

test "a clean run deinits clean under the sweep allocator" {
    var gpa: Fast = .{};
    const a = gpa.allocator();
    const bytes = try a.alloc(u8, 64);
    a.free(bytes);
    try testing.expectEqual(std.heap.Check.ok, gpa.deinit());
}

test "CRANE_LEAK_TRACES: set and not starting with 0" {
    try testing.expect(!wantsTraces(null));
    try testing.expect(!wantsTraces(""));
    try testing.expect(!wantsTraces("0"));
    try testing.expect(wantsTraces("1"));
    try testing.expect(wantsTraces("yes"));
}
