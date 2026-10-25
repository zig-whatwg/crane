//! Actual background-axis declarations must preserve main's dependency flags.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Case = struct {
    declaration: []const u8,
    name: []const u8,
    tree: bool = false,
    random: bool = false,
};

fn check(allocator: std.mem.Allocator, case: Case) !void {
    const property = css.properties.lookup(case.name) orelse return error.BackgroundAxisNotImplemented;
    const value = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.declaration);
        defer block.deinit();
        const value = (block.get(property.longhand) orelse return error.ExpectedBackgroundAxis).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(case.tree, value.needsTreeCounts());
    try testing.expectEqual(case.random, value.needsRandomBase());
}

test "background axes and axis lists keep actual tree and random dependencies" {
    for ([_]Case{
        .{ .declaration = "background-position-x:calc(sibling-index() * 1px)", .name = "background-position-x", .tree = true },
        .{ .declaration = "background-position-y:bottom calc(sibling-count() * 1px)", .name = "background-position-y", .tree = true },
        .{ .declaration = "background-position-x:0px,random(1px, 2px)", .name = "background-position-x", .random = true },
        .{ .declaration = "background-position-y:random(1px, 2px),0px", .name = "background-position-y", .random = true },
        .{ .declaration = "background-position-x:random(fixed .5, 1px, 2px)", .name = "background-position-x" },
        .{ .declaration = "background-position-x:right 10px", .name = "background-position-x" },
        .{ .declaration = "background-position-y:top 20px", .name = "background-position-y" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, check, .{case});
}
