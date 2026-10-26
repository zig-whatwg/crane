//! The (f) consumers use main's typed math and compose APIs. These expected
//! computed values come from background-size/position and clip-path WPT;
//! Q48 requires typed right/bottom complements without serialization/reparse.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Case = struct { name: []const u8, input: []const u8, expected: []const u8 };

fn computed(allocator: std.mem.Allocator, case: Case) !void {
    const property = css.properties.lookup(case.name) orelse return error.ExpectedProperty;
    const style = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.name, case.input, ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(case.expected, out.items);
}

test "background and mask math uses the real font and clamps only the size result" {
    for ([_]Case{
        .{ .name = "background-size", .input = "calc(10px + 0.5em) calc(10px - 0.5em)", .expected = "30px 0px" },
        .{ .name = "mask-size", .input = "calc(10px - 0.5em) calc(10px + 0.5em)", .expected = "0px 30px" },
        .{ .name = "background-position-x", .input = "right calc(10% + 1em)", .expected = "calc(90% - 40px)" },
        .{ .name = "background-position-y", .input = "bottom calc(20% + 5px)", .expected = "calc(80% - 5px)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{case});
}

test "typed shape math computes rect and xywh without assigning a geometry basis" {
    for ([_]Case{
        .{ .name = "clip-path", .input = "circle(calc(10px + 0.5em) at -50% 50%)", .expected = "circle(30px at -50% 50%)" },
        .{ .name = "clip-path", .input = "circle(calc(10px - 0.5em) at 50% -50%)", .expected = "circle(0px at 50% -50%)" },
        .{ .name = "clip-path", .input = "xywh(calc(0px) calc(1px + 1%) calc(2px + 2%) calc(3px + 3%))", .expected = "inset(calc(1% + 1px) calc(98% - 2px) calc(96% - 4px) 0px)" },
        .{ .name = "clip-path", .input = "rect(calc(0px) calc(1px + 1%) calc(2px + 2%) calc(3px + 3%))", .expected = "inset(0px calc(99% - 1px) calc(98% - 2px) calc(3% + 3px))" },
        // Mixed scalar/expression composition must not need a reparse of
        // the computed scalar. main.math_values.dimension constructs it.
        .{ .name = "clip-path", .input = "xywh(10px 20px calc(30% + 5px) calc(40% + 6px))", .expected = "inset(20px calc(70% - 15px) calc(60% - 26px) 10px)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{case});
}

fn dependencies(allocator: std.mem.Allocator, name: []const u8, input: []const u8, tree: bool, random: bool) !void {
    const property = css.properties.lookup(name) orelse return error.ExpectedProperty;
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, ""));
        const value = (block.get(property.longhand) orelse return error.ExpectedAssignment).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
}

test "actual image and shape math declarations keep tree and random dependencies after source release" {
    for ([_][]const u8{ "background-size", "mask-size" }) |name| {
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "calc(sibling-index() * 1px) 2px", true, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "1px random(2px, 4px)", false, true });
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "1px random(fixed 0.5, 2px, 4px)", false, false });
    }
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "clip-path", "circle(calc(sibling-count() * 1px))", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "clip-path", "xywh(1px 2px random(3px, 5px) 4px)", false, true });
}
