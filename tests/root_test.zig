//! Tests migrated from src/root.zig
//! Basic library tests

const std = @import("std");
const whatwg = @import("whatwg");

test "basic add functionality" {
    try std.testing.expect(whatwg.add(3, 7) == 10);
}
