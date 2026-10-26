//! Row119 aggregates forward the dependency predicates supplied by main.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn dependencies(allocator: std.mem.Allocator, declaration: []const u8, longhand: css.properties.Longhand, tree: bool, random: bool) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, declaration);
    defer block.deinit();
    const value = (block.get(longhand) orelse return error.ExpectedDeclaration).value.value;
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
}

test "cursor URLs and numeric hotspots need neither tree counts nor random input" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "cursor:url(pointer.cur) 1 2, pointer", .cursor, false, false });
}

test "cursor hotspot function tokens cannot hide tree or random dependencies" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "cursor:url(pointer.cur) calc(1) 2, pointer", .cursor, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "cursor:url(pointer.cur) random(0, 1) 2, pointer", .cursor, false, true });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "cursor:url(pointer.cur) 1 calc(sibling-index()), pointer", .cursor, true, false });
}

test "flagged text-indent forwards sibling counts through its owned offset" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "text-indent:calc(sibling-count() * 1px) hanging", .text_indent, true, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "text-indent:2em hanging", .text_indent, false, false });
}

test "flagged text-indent forwards random input while a fixed base needs none" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "text-indent:random(1px, 2px) hanging", .text_indent, false, true });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "text-indent:random(fixed .5, 1px, 2px) hanging", .text_indent, false, false });
}

fn unavailableRandom(allocator: std.mem.Allocator) !void {
    var lower = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "text-indent:3px hanging");
    defer lower.deinit();
    var higher = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "text-indent:random(10px, 20px) hanging");
    defer higher.deinit();
    try testing.expect(higher.get(.text_indent) != null);
    // CSS Values 5 random input follows main's unavailable-input decision.
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &lower, .source = .{ .origin = .user } },
        .{ .block = &higher, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.text_indent, &out, allocator);
    try testing.expectEqualStrings("3px hanging", out.items);
}

test "an unavailable random input nested in text-indent selects the lower candidate" {
    try testing.checkAllAllocationFailures(testing.allocator, unavailableRandom, .{});
}
