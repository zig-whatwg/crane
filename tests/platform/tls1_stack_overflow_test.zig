//! A stack overflow is still reported (lane tls1): the fault handler runs on
//! the alternate signal stack the platform maps for the thread, and prints
//! the fault and its trace - on the main thread and on a spawned thread, in
//! the build modes that had the report before (ReleaseSafe: the release
//! console and the production WPT runner; Debug: the bug-finding runner's
//! Crane modules).
//!
//! Before this lane the stack was Zig std's (`std.Options.signal_stack_size`,
//! a 256 KB threadlocal array every thread touching a thread-local paid
//! for). Crane's roots now set it to null, and without the platform's stack
//! the same overflow would end the process with the fault's signal and print
//! nothing: what stack_overflow_fixture.zig's `unattached-*` modes show, and
//! what a thread nobody attached still gets.
//!
//! The fixture (stack_overflow_fixture.zig, built by build.zig in both
//! modes) is a real process: it is set up as Crane's roots are, runs its
//! stack out, and exits `reported_exit` once std's handler has printed.

const std = @import("std");
const builtin = @import("builtin");
const fixtures = @import("stack_overflow_fixtures");

const testing = std.testing;

/// stack_overflow_fixture.zig's `reported_exit`.
const reported_exit = 77;

const supported = switch (builtin.os.tag) {
    .windows, .wasi => false,
    else => true,
};

/// Run the fixture in `mode` and check its overflow was reported: the
/// handler's first line names the fault and its address, the trace names the
/// function that overflowed, and the process ended by the handler's abort.
fn expectReported(path: []const u8, mode: []const u8) !void {
    const result = try std.process.run(testing.allocator, testing.io, .{ .argv = &.{ path, mode } });
    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);
    errdefer std.debug.print("\n{s} {s}: term {any}; stderr ({d} bytes) starts:\n{s}\n", .{ path, mode, result.term, result.stderr.len, result.stderr[0..@min(result.stderr.len, 600)] });
    // macOS reports a write to a thread stack's guard page as a bus error
    // (a protection failure), Linux as a segmentation fault.
    const fault = std.mem.indexOf(u8, result.stderr, "Segmentation fault at address 0x") orelse
        std.mem.indexOf(u8, result.stderr, "Bus error at address 0x") orelse
        return error.TestExpectedFaultReport;
    // The trace: the recursion's frames, by name.
    try testing.expect(std.mem.indexOfPos(u8, result.stderr, fault, "overflow") != null);
    try testing.expect(result.term == .exited);
    try testing.expectEqual(@as(u8, reported_exit), result.term.exited);
}

test "ReleaseSafe: a stack overflow on the main thread is reported with its trace" {
    if (!supported) return error.SkipZigTest;
    try expectReported(fixtures.release_safe, "main");
}

test "ReleaseSafe: a stack overflow on a spawned thread is reported with its trace" {
    if (!supported) return error.SkipZigTest;
    try expectReported(fixtures.release_safe, "thread");
}

test "Debug: a stack overflow on the main thread is reported with its trace" {
    if (!supported) return error.SkipZigTest;
    try expectReported(fixtures.debug, "main");
}

test "Debug: a stack overflow on a spawned thread is reported with its trace" {
    if (!supported) return error.SkipZigTest;
    try expectReported(fixtures.debug, "thread");
}
