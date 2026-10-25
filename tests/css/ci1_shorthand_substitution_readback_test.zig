//! Q208 middle-commit tests: generic shorthand substitution read-back seam.
const std = @import("std");
const testing = std.testing;
const checks = @import("ci1_shorthand_substitution_helpers.zig");

fn allocationCase(allocator: std.mem.Allocator, property: []const u8, function: []const u8, setter: bool) !void {
    try checks.allocationCase(allocator, property, function, setter);
}

test "parse margin var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "margin", "var(--ci1)", false });
}
test "parse margin env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "margin", "env(ci1)", false });
}
test "parse background var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "background", "var(--ci1)", false });
}
test "parse background env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "background", "env(ci1)", false });
}
test "parse border var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "border", "var(--ci1)", false });
}
test "parse border env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "border", "env(ci1)", false });
}
test "setProperty margin var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "margin", "var(--ci1)", true });
}
test "setProperty margin env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "margin", "env(ci1)", true });
}
test "setProperty background var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "background", "var(--ci1)", true });
}
test "setProperty background env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "background", "env(ci1)", true });
}
test "setProperty border var read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "border", "var(--ci1)", true });
}
test "setProperty border env read-back and all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ "border", "env(ci1)", true });
}
test "longhand var and env remain rejected controls" {
    try checks.rejectionControls();
}
