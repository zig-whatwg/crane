//! The V8 snapshot generator's progress log (snapshot_generator.zig): kept
//! in memory while the generator works, and written once it is done - to
//! stdout when it succeeded, to stderr when it failed.
//!
//! Why: the build runs the generator as a Run step with an output file
//! argument, which Zig 0.17's build runner treats as free of side effects:
//! it discards the step's stdout and shows its stderr. And it shows a
//! step's stderr - followed by a "failed command: <argv>" line - even when
//! the step succeeds (compiler/Maker.zig, the step's verbose context). The
//! generator's four [v8_SnapshotCreator_*] progress lines on stderr made every
//! passing build print that block, and it was read as a failure mid-build
//! (lane nav2, 2026-11-14; lane maj5, 2026-11-20: tmp/plans/maj5-evidence/
//! snapshot-flake.txt). So a passing generator writes nothing to stderr - the
//! build pins it (engine_build.zig `addStartupData`, expectStdErrEqual("")) -
//! and a failing one writes its whole log there, where the failed step shows
//! it. Run by hand (`zig build snapshot-generator`), its stdout is the
//! terminal and the log reads as before.
//!
//! std-only, so the test step runs it (v8-build-snapshot_generator_log: the
//! adapter's `facts.build_tests`).

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Log = struct {
    gpa: Allocator,
    text: std.ArrayList(u8) = .empty,

    pub fn init(gpa: Allocator) Log {
        return .{ .gpa = gpa };
    }

    pub fn deinit(log: *Log) void {
        log.text.deinit(log.gpa);
    }

    /// Adds a line (or part of one) to the log. Out of memory, the text is
    /// dropped: the log is a diagnosis, never the generator's failure.
    pub fn print(log: *Log, comptime fmt: []const u8, args: anytype) void {
        log.text.print(log.gpa, fmt, args) catch {};
    }

    pub const Outcome = enum { succeeded, failed };

    /// Writes the whole log where `outcome` sends it - `stdout` when the
    /// generator succeeded, `stderr` when it failed - and flushes it.
    pub fn finish(log: *const Log, outcome: Outcome, stdout: *Io.Writer, stderr: *Io.Writer) Io.Writer.Error!void {
        const w = switch (outcome) {
            .succeeded => stdout,
            .failed => stderr,
        };
        try w.writeAll(log.text.items);
        try w.flush();
    }
};

const testing = std.testing;

test "a generator that succeeds writes its log to stdout and nothing to stderr" {
    var log: Log = .init(testing.allocator);
    defer log.deinit();
    log.print("Step 1: Initializing V8 platform...\n", .{});
    log.print("  Window context added at index {d}\n", .{0});

    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    var err: Io.Writer.Allocating = .init(testing.allocator);
    defer err.deinit();
    try log.finish(.succeeded, &out.writer, &err.writer);

    try testing.expectEqualStrings("", err.written());
    try testing.expectEqualStrings("Step 1: Initializing V8 platform...\n  Window context added at index 0\n", out.written());
}

test "a generator that fails writes every line of its log to stderr, in order, and nothing to stdout" {
    var log: Log = .init(testing.allocator);
    defer log.deinit();
    log.print("Step 6: Creating snapshot blob...\n", .{});
    log.print("  ERROR: Failed to create snapshot blob\n", .{});

    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    var err: Io.Writer.Allocating = .init(testing.allocator);
    defer err.deinit();
    try log.finish(.failed, &out.writer, &err.writer);

    try testing.expectEqualStrings("", out.written());
    try testing.expectEqualStrings("Step 6: Creating snapshot blob...\n  ERROR: Failed to create snapshot blob\n", err.written());
}
