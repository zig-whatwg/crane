//! Q118: axis adapters retain real main math values before f adds parsing.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Value = css.style_values.Value;
const Axis = std.meta.Child(@FieldType(Value, "image_axis"));
const Anchor = @FieldType(@FieldType(Axis, "data"), "specified");
const Case = struct {
    declaration: []const u8,
    longhand: css.properties.Longhand,
    edge: @FieldType(Anchor, "edge") = null,
    tree: bool = false,
    random: bool = false,
    metric: bool = false,
};

fn expect(value: Value, case: Case) !void {
    try testing.expectEqual(case.tree, value.needsTreeCounts());
    try testing.expectEqual(case.random, value.needsRandomBase());
    try testing.expectEqual(case.metric, value.needsUnavailableMetrics(false));
    try testing.expect(!value.needsUnavailableMetrics(true));
}

fn check(allocator: std.mem.Allocator, case: Case) !void {
    const scalar = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.declaration);
        defer block.deinit();
        const value = (block.get(.margin_left) orelse return error.ExpectedTypedLength).value.value;
        value.retain();
        break :blk value;
    };
    defer scalar.release();
    // The declaration and its real random parse scope have already died.
    // Public constructors own the scalar and each list component in turn.
    const axis: Value = .{ .image_axis = try Axis.create(allocator, .{ .edge = case.edge, .offset = scalar }) };
    defer axis.release();
    try expect(axis, case);
    const fixed: Value = .{ .image_axis = try Axis.create(allocator, .{ .edge = null, .offset = Value.px(0) }) };
    defer fixed.release();
    try expect(fixed, .{ .declaration = "", .longhand = case.longhand });
    for (0..2) |index| {
        var pair = [_]Value{ fixed, fixed };
        pair[index] = axis;
        const list: Value = .{ .layers = try css.image_layers.Layers.create(allocator, case.longhand, &pair) };
        defer list.release();
        try expect(list, case);
    }
}

test "background axes and axis lists keep actual tree and random dependencies" {
    for ([_]Case{
        .{ .declaration = "margin-left:calc(sibling-index() * 1px)", .longhand = .background_position_x, .tree = true },
        .{ .declaration = "margin-left:calc(sibling-count() * 1px)", .longhand = .background_position_y, .edge = .bottom, .tree = true },
        .{ .declaration = "margin-left:random(1px, 2px)", .longhand = .background_position_x, .random = true },
        .{ .declaration = "margin-left:random(1px, 2px)", .longhand = .background_position_y, .random = true },
        .{ .declaration = "margin-left:random(fixed .5, 1px, 2px)", .longhand = .background_position_x },
        .{ .declaration = "margin-left:10px", .longhand = .background_position_x, .edge = .right },
        .{ .declaration = "margin-left:20px", .longhand = .background_position_y, .edge = .top },
        .{ .declaration = "margin-left:calc(1cap)", .longhand = .background_position_x, .metric = true },
        .{ .declaration = "margin-left:calc(1rcap)", .longhand = .background_position_y, .metric = true },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, check, .{case});
}
