//! Q11: content delegates standard cross-fade to the typed image owner.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const a = std.testing.allocator;

fn computed(allocator: h.Allocator) !void {
    var block = try h.Block.parse(.{ .allocator = allocator }, "color:red;content:cross-fade(30% color-mix(in srgb, currentcolor, blue), white)");
    defer block.deinit();
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "content", "cross-fade(color(srgb 0.5 0 0.5) 30%, rgb(255, 255, 255))", allocator);
}

test "content standard cross fade resolves currentcolor like other typed images" {
    try computed(a);
}

test "content cross fade percentages clamp and malformed syntax rejects" {
    try h.check(a, "content", "cross-fade(calc(101%) red, green)", "cross-fade(rgb(255, 0, 0) 100%, rgb(0, 128, 0))", true);
    try h.check(a, "content", "cross-fade(50% red, green)", "cross-fade(red 50%, green)", false);
    inline for (.{ "cross-fade()", "cross-fade(red 101%, green)", "cross-fade(red 20% 30%, green)" }) |input|
        try h.check(a, "content", input, "", false);
}

test "content cross fade releases every temporary typed image on allocation failure" {
    try std.testing.checkAllAllocationFailures(a, computed, .{});
    try std.testing.checkAllAllocationFailures(a, h.check, .{ "content", "cross-fade(url(a) 50%, cross-fade(url(b), blue))", "cross-fade(url(\"a\") 50%, cross-fade(url(\"b\"), blue))", false });
}
