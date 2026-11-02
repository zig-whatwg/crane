//! A test executable built with ThreadSanitizer (build.zig: sanitize_thread
//! on its module) whose middle test races, run as real child processes by
//! child.zig's tests: under the launcher's TSAN_OPTIONS (halt_on_error=1) the
//! race kills its process, and the launcher blames that test - not the one
//! after it, and not the process's exit.
//! Not part of any suite: build.zig compiles it only for the launcher's tests.

const std = @import("std");

// Written by two threads with no synchronisation: a data race by design.
var shared: u64 = 0;

fn increment() void {
    var i: u32 = 0;
    while (i < 100_000) : (i += 1) shared += 1;
}

test "passes before" {}

test "races" {
    const thread = try std.Thread.spawn(.{}, increment, .{});
    increment();
    thread.join();
}

test "passes after" {}
