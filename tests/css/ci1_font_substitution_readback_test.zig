//! Q208 e2-commit tests: font shorthand substitution read-back.
const std = @import("std");
const testing = std.testing;
const checks = @import("ci1_shorthand_substitution_helpers.zig");

fn allocationCase(allocator: std.mem.Allocator, property: []const u8, function: []const u8, setter: bool) !void {
    try checks.allocationCase(allocator, property, function, setter);
}

test "parse font var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "font", "var(--ci1)", false });
}
test "parse font env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "font", "env(ci1)", false });
}
test "setProperty font var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "font", "var(--ci1)", true });
}
test "setProperty font env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "font", "env(ci1)", true });
}
