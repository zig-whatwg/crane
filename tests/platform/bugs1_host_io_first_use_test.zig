//! host.io() asked first by several threads at once (lane bugs1).
//!
//! A process whose entry point adopts std.start's Io (`host.adopt`) sets the
//! process Io before any other thread exists. One whose entry point does not -
//! every test executable - sets it lazily, on the first thread that asks; two
//! asking at once used to race: io()'s unlocked read of the cached Io against
//! init's write of it under the lock. ThreadSanitizer reported it in every
//! lane gate's platform step, through tests/wpt_runner/wpt_server.zig's "two
//! runners starting together spawn one server between them" (src/platform/
//! host.zig:123 against :63 on main d29206edf1d).
//!
//! The race needs a process in which nobody has asked yet, which is what a
//! test run alone gets (test-verify's alone runs, `-Dtest-filter`, batch 1):
//! under -Dsanitize-thread those fail before the fix and pass after it. Run
//! after another test of its process asked, it checks only that every thread
//! is handed the same Io.
const std = @import("std");
const host = @import("host");
const testing = std.testing;

const Asker = struct {
    go: *std.atomic.Value(bool),
    got: std.Io = undefined,

    fn run(self: *Asker) void {
        while (!self.go.load(.acquire)) std.atomic.spinLoopHint();
        self.got = host.io();
    }
};

test "io() asked first by eight threads at once hands each the same Io" {
    var go = std.atomic.Value(bool).init(false);
    var askers: [8]Asker = undefined;
    var threads: [8]std.Thread = undefined;
    for (&askers, &threads) |*asker, *thread| {
        asker.* = .{ .go = &go };
        thread.* = try std.Thread.spawn(.{}, Asker.run, .{asker});
    }
    go.store(true, .release);
    for (threads) |thread| thread.join();
    // The process Io, now asked from this thread: the one each was handed.
    const process_io = host.io();
    for (askers) |asker| {
        try testing.expectEqual(process_io.userdata, asker.got.userdata);
        try testing.expectEqual(process_io.vtable, asker.got.vtable);
    }
    // And it works: a real filesystem operation through it.
    var dir = try host.cwd().openDir(process_io, ".", .{});
    dir.close(process_io);
}
