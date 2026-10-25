//! Q137/Q189/Q202: d2-owned object-position pair obligations, separated
//! from f-only controls. All paths retain allocation-failure checks.
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

test "object-position pair math computes with the real font and complements" {
    for ([_]Case{
        .{ .name = "object-position", .input = "calc(10px + 0.5em) calc(10px - 0.5em)", .expected = "30px -10px" },
        .{ .name = "object-position", .input = "right calc(10% + 1em) bottom calc(20% + 5px)", .expected = "calc(90% - 40px) calc(80% - 5px)" },
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

test "object-position math keeps tree and random dependencies after source release" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "object-position", "calc(sibling-index() * 1px) 2px", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "object-position", "1px random(2px, 4px)", false, true });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "object-position", "1px random(fixed 0.5, 2px, 4px)", false, false });
}
