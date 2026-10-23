//! Typed colors from main must keep dependencies through b1 aggregates.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn colorDependencies(allocator: std.mem.Allocator) !void {
    for ([_]struct { input: []const u8, property: css.properties.Longhand, tree: bool, random: bool }{
        .{ .input = "fill:url(p.svg) rgb(calc(sibling-index() * 20) 0 0)", .property = .fill, .tree = true, .random = false },
        .{ .input = "stroke:url(p.svg) rgb(random(0, 200) 0 0)", .property = .stroke, .tree = false, .random = true },
        .{ .input = "filter:drop-shadow(rgb(calc(sibling-index() * 20) 0 0) 1px 2px)", .property = .filter, .tree = true, .random = false },
        .{ .input = "filter:drop-shadow(rgb(random(0, 200) 0 0) 1px 2px)", .property = .filter, .tree = false, .random = true },
        .{ .input = "fill:url(p.svg) rgb(random(fixed .5, 0, 200) 0 0)", .property = .fill, .tree = false, .random = false },
    }) |case| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.input);
        defer block.deinit();
        const value = (block.get(case.property) orelse return error.ExpectedDeclaration).value.value;
        try testing.expectEqual(case.tree, value.needsTreeCounts());
        try testing.expectEqual(case.random, value.needsRandomBase());
    }
}

test "paint and drop-shadow forward typed Color tree and random dependencies" {
    try testing.checkAllAllocationFailures(testing.allocator, colorDependencies, .{});
}

fn expectDependency(value: css.style_values.Value, random: bool) !void {
    try testing.expectEqual(!random, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
}

fn scalarContainers(allocator: std.mem.Allocator, random: bool) !void {
    const Value = css.style_values.Value;
    const scalar: Value = blk: {
        // Non-fixed random keys require the actual declaration parse scope.
        // The aggregate must retain the expression after that scope ends.
        var declaration = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (random)
            "margin-left:random(1px, 2px)"
        else
            "margin-left:calc(sibling-index() * 1px)");
        defer declaration.deinit();
        const value = (declaration.get(.margin_left) orelse return error.ExpectedMath).value.value;
        value.retain();
        break :blk value;
    };
    defer scalar.release();
    try expectDependency(scalar, random);
    const Quad = std.meta.Child(@FieldType(Value, "image_quad"));
    const Size = std.meta.Child(@FieldType(Value, "image_size"));
    const Position = std.meta.Child(@FieldType(Value, "image_position"));
    const Layers = std.meta.Child(@FieldType(Value, "layers"));
    const Filter = std.meta.Child(@FieldType(Value, "filter"));
    for (0..4) |index| {
        var sides = [_]Value{Value.px(0)} ** 4;
        sides[index] = scalar;
        const quad: Value = .{ .image_quad = try Quad.create(allocator, sides, false) };
        defer quad.release();
        try expectDependency(quad, random);
    }
    for (0..2) |index| {
        var axes = [_]Value{Value.px(0)} ** 2;
        axes[index] = scalar;
        const size: Value = .{ .image_size = try Size.create(allocator, axes) };
        defer size.release();
        try expectDependency(size, random);
        const position: Value = .{ .image_position = try Position.create(allocator, .{
            .{ .edge = null, .offset = axes[0] }, .{ .edge = null, .offset = axes[1] },
        }, false) };
        defer position.release();
        try expectDependency(position, random);
        const layers: Value = .{ .layers = try Layers.create(allocator, .mask_size, &.{ Value.kw(.auto), size }) };
        defer layers.release();
        try expectDependency(layers, random);
    }
    for (0..3) |index| {
        var lengths = [_]Value{Value.px(0)} ** 3;
        lengths[index] = scalar;
        const filter: Value = .{ .filter = try Filter.create(allocator, &.{.{ .function = .{
            .kind = .drop_shadow,
            .argument = .{ .shadow = .{ .color = null, .lengths = lengths, .count = 3 } },
        } }}) };
        defer filter.release();
        try expectDependency(filter, random);
    }
}

test "scalar image components preserve tree and random dependencies at every position" {
    try testing.checkAllAllocationFailures(testing.allocator, scalarContainers, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, scalarContainers, .{true});
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};

fn sourceThroughColors(allocator: std.mem.Allocator, allowed: bool) !void {
    var counts: Counts = .{};
    const parent = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "fill:url(p.svg) rgb(calc(sibling-count() * 10) 0 0);" ++
            "filter:drop-shadow(rgb(calc(sibling-index() * 20) 0 0) 1px 2px)");
        defer user.deinit();
        try testing.expect(user.get(.fill) != null);
        try testing.expect(user.get(.filter) != null);
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "fill:revert;filter:revert");
        defer author.deinit();
        // Cascade 5 revert selects the user's source, not the author's scope.
        break :blk try css.cascade.cascade(.{
            .allocator = allocator,
            .parent = null,
            .tree_counts = .{ .context = &counts, .get = Counts.get },
        }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
    };
    defer parent.destroy();
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try parent.serializeResolved(.fill, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "url(\"p.svg\") rgb(70, 0, 0)" else "url(\"p.svg\") rgb(0, 0, 0)", out.items);
    out.clearRetainingCapacity();
    try parent.serializeResolved(.filter, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "drop-shadow(rgb(60, 0, 0) 1px 2px 0px)" else "drop-shadow(rgb(0, 0, 0) 1px 2px 0px)", out.items);

    // Computed inheritance keeps the selected result after declarations die.
    var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "fill:inherit;filter:inherit");
    defer inherited.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author, .tree_scope = .{ .serial = 1234 }, .tree_count_allowed = !allowed } }});
    defer child.destroy();
    inherited.clear();
    out.clearRetainingCapacity();
    try child.serializeResolved(.filter, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "drop-shadow(rgb(60, 0, 0) 1px 2px 0px)" else "drop-shadow(rgb(0, 0, 0) 1px 2px 0px)", out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
}

test "winning tree-count restrictions reach nested paint and filter colors through revert" {
    try testing.checkAllAllocationFailures(testing.allocator, sourceThroughColors, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, sourceThroughColors, .{true});
}

fn unavailableRandom(allocator: std.mem.Allocator, fixed: bool) !void {
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "fill:blue;filter:drop-shadow(red 3px 4px)");
    defer low.deinit();
    const input = if (fixed)
        "fill:url(p.svg) rgb(random(fixed .5, 0, 200) 0 0);filter:drop-shadow(rgb(random(fixed .5, 0, 200) 0 0) 1px 2px)"
    else
        "fill:url(p.svg) rgb(random(0, 200) 0 0);filter:drop-shadow(rgb(random(0, 200) 0 0) 1px 2px)";
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer high.deinit();
    try testing.expect(high.get(.fill) != null);
    try testing.expect(high.get(.filter) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .user } },
        .{ .block = &high, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.fill, &out, allocator);
    try testing.expectEqualStrings(if (fixed) "url(\"p.svg\") rgb(100, 0, 0)" else "rgb(0, 0, 255)", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(.filter, &out, allocator);
    try testing.expectEqualStrings(if (fixed) "drop-shadow(rgb(100, 0, 0) 1px 2px 0px)" else "drop-shadow(rgb(255, 0, 0) 3px 4px 0px)", out.items);
}

test "missing random input in nested colors selects lower candidates while fixed input computes" {
    try testing.checkAllAllocationFailures(testing.allocator, unavailableRandom, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, unavailableRandom, .{true});
}
