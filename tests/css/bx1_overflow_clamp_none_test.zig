//! Q65: legacy none has a coherent expansion and shorthand reconstruction.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

fn parseNone(allocator: h.Allocator) !void {
    var block = h.Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "-webkit-line-clamp", "none", ""));
    try testing.expectEqual(@as(usize, 3), block.length());
    try h.specified(&block, "max-lines", "auto", allocator);
    try h.specified(&block, "block-ellipsis", "no-ellipsis", allocator);
    try h.specified(&block, "continue", "normal", allocator);
    try h.specified(&block, "-webkit-line-clamp", "none", allocator);
    try h.specified(&block, "line-clamp", "none", allocator);
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "-webkit-line-clamp", "none", allocator);
    try h.expect(style, "line-clamp", "none", allocator);
}

fn roundTrip(allocator: h.Allocator) !void {
    var constituents = try h.Block.parse(.{ .allocator = allocator }, "max-lines:auto;block-ellipsis:no-ellipsis;continue:normal");
    defer constituents.deinit();
    try h.specified(&constituents, "-webkit-line-clamp", "none", allocator);
    try h.specified(&constituents, "line-clamp", "none", allocator);
    const explicit = try h.compute(allocator, &constituents, null);
    defer explicit.destroy();
    try h.expect(explicit, "-webkit-line-clamp", "none", allocator);
    inline for (.{ "", "max-lines:initial;block-ellipsis:initial;continue:initial", "line-clamp:none", "-webkit-line-clamp:none" }) |text| {
        var block = try h.Block.parse(.{ .allocator = allocator }, text);
        defer block.deinit();
        const style = try h.compute(allocator, &block, null);
        defer style.destroy();
        try h.expect(style, "-webkit-line-clamp", "none", allocator);
        try h.expect(style, "line-clamp", "none", allocator);
    }
}

fn controls(allocator: h.Allocator) !void {
    var block = try h.Block.parse(.{ .allocator = allocator }, "-webkit-line-clamp:3");
    defer block.deinit();
    try h.specified(&block, "max-lines", "3", allocator);
    try h.specified(&block, "block-ellipsis", "ellipsis", allocator);
    try h.specified(&block, "continue", "-webkit-legacy", allocator);
    try h.specified(&block, "-webkit-line-clamp", "3", allocator);
    try h.specified(&block, "line-clamp", "3 -webkit-legacy", allocator);
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "-webkit-line-clamp", "3", allocator);
    inline for (.{
        "max-lines:3 auto;block-ellipsis:ellipsis;continue:-webkit-legacy",
        "max-lines:3;block-ellipsis:no-ellipsis;continue:-webkit-legacy",
        "max-lines:3;block-ellipsis:ellipsis;continue:normal",
    }) |text| {
        var incompatible = try h.Block.parse(.{ .allocator = allocator }, text);
        defer incompatible.deinit();
        try h.specified(&incompatible, "-webkit-line-clamp", "", allocator);
        const computed = try h.compute(allocator, &incompatible, null);
        defer computed.destroy();
        try h.expect(computed, "-webkit-line-clamp", "", allocator);
    }
}

test "legacy clamp none parses all three initial longhands" {
    try parseNone(testing.allocator);
}

test "legacy clamp none round trips explicit and computed initial constituents" {
    try roundTrip(testing.allocator);
}

test "legacy clamp positive integers and incompatible numerics retain their behavior" {
    try controls(testing.allocator);
}

test "legacy clamp none and round trips release every failed allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, parseNone, .{});
    try testing.checkAllAllocationFailures(testing.allocator, roundTrip, .{});
    try testing.checkAllAllocationFailures(testing.allocator, controls, .{});
}
