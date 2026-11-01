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
