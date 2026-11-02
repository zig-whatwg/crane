//! A test executable with one test of each kind the launcher must tell
//! apart, run as real child processes by child.zig's tests. Index order is
//! declaration order: "poisons" runs before "needs a clean process" in a
//! batch, so that one fails only after it - an order dependence.
//! Not part of any suite: build.zig compiles it only for the launcher's tests.

const std = @import("std");

// The state "poisons" leaves behind for "needs a clean process". A fixture
// for an order dependence; this file is not engine code.
var poisoned: bool = false;

test "passes" {}

test "fails" {
    return error.Expected;
}

test "crashes" {
    @panic("the fixture crashes here");
}

test "hangs" {
    // Longer than the launcher's timeout in the fixture run.
    std.Io.sleep(std.testing.io, .fromSeconds(3600), .awake) catch {};
}

test "leaks" {
    _ = try std.testing.allocator.alloc(u8, 16);
}

test "poisons" {
    poisoned = true;
}

test "needs a clean process" {
    try std.testing.expect(!poisoned);
}

test "skips" {
    return error.SkipZigTest;
}

// The environment the launcher fixes for every test child (child.zig,
// `test_environment`): it passes only where the child sees exactly that.
test "sees the fixed environment" {
    const environ = std.testing.environ;
    try std.testing.expectEqualStrings("America/Los_Angeles", environ.getPosix("TZ") orelse return error.NoTimeZone);
    try std.testing.expectEqualStrings("en_US.UTF-8", environ.getPosix("LANG") orelse return error.NoLang);
    try std.testing.expectEqualStrings("en_US.UTF-8", environ.getPosix("LC_ALL") orelse return error.NoLcAll);
    for ([_][]const u8{ "http_proxy", "https_proxy", "all_proxy", "no_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY" }) |name| {
        if (environ.getPosix(name)) |value| {
            std.debug.print("{s}={s} reached the test\n", .{ name, value });
            return error.ProxyNotCleared;
        }
    }
}

// Verify mode's flake (verify.zig): passes alone, every time, and fails the
// third time it runs in one process - what ten runs in one process catch.
var runs_in_process: u32 = 0;

test "fails on its third run in a process" {
    runs_in_process += 1;
    if (runs_in_process == 3) return error.ThirdRunInThisProcess;
}
