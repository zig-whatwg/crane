//! Q59-Q61: the pure CSS reader mirrors the generated CSSOM caller's route.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

fn resolved(allocator: h.Allocator, text: []const u8, parent_text: ?[]const u8, canonical: []const u8, alias: []const u8, canonical_expected: []const u8, alias_expected: []const u8) !void {
    var parent_block = try h.Block.parse(.{ .allocator = allocator }, parent_text orelse "display:block");
    defer parent_block.deinit();
    const parent = try h.compute(allocator, &parent_block, null);
    defer parent.destroy();
    var block = try h.Block.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    const style = try h.compute(allocator, &block, parent);
    defer style.destroy();
    try h.expect(style, canonical, canonical_expected, allocator);
    try h.expect(style, alias, alias_expected, allocator);
}

fn cases(allocator: h.Allocator) !void {
    inline for (.{
        .{ "display:none;transform:scale(2)", @as(?[]const u8, null), "none" },
        .{ "display:contents;transform:scale(2)", @as(?[]const u8, null), "matrix(2, 0, 0, 2, 0, 0)" },
        .{ "display:block;transform:scale(2)", @as(?[]const u8, "display:none"), "matrix(2, 0, 0, 2, 0, 0)" },
        .{ "display:block;transform:scale(1e308) scale(2)", @as(?[]const u8, null), "matrix(infinity, 0, 0, infinity, 0, 0)" },
    }) |case| try resolved(allocator, case[0], case[1], "transform", "-webkit-transform", case[2], case[2]);
    try resolved(allocator, "display:none;perspective:25px", null, "perspective", "-webkit-perspective", "25px", "25px");
    try resolved(allocator, "display:none;text-orientation:mixed", null, "text-orientation", "-webkit-text-orientation", "mixed", "vertical-right");
    try resolved(allocator, "display:block;text-orientation:upright", null, "text-orientation", "-webkit-text-orientation", "upright", "upright");
    try resolved(allocator, "display:block;-webkit-text-orientation:sideways-right", null, "text-orientation", "-webkit-text-orientation", "sideways", "sideways");
}

test "single-member wrappers resolve first and retain their existing spelling" {
    try cases(testing.allocator);
}

test "single-member resolved serialization releases every failing allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, cases, .{});
}

test "multi-member shorthands retain their computed reconstruction" {
    try h.check(testing.allocator, "margin", "1px 2px", "1px 2px", true);
    try h.check(testing.allocator, "flex-flow", "column wrap", "column wrap", true);
    try h.check(testing.allocator, "overflow", "hidden scroll", "hidden scroll", true);
}
