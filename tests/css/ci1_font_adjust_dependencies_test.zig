//! Fonts5 §3.4: aspect math forwards dependencies and its winning source.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn dependencies(allocator: Allocator) !void {
    const property = css.properties.lookup("font-size-adjust") orelse return error.FontSizeAdjustNotImplemented;
    for ([_]struct { input: []const u8, tree: bool = false, random: bool = false, metric: bool = false }{
        .{ .input = "font-size-adjust:calc(sibling-index() / 10)", .tree = true },
        .{ .input = "font-size-adjust:random(.1, .9)", .random = true },
        .{ .input = "font-size-adjust:random(fixed .5, .1, .9)" },
        .{ .input = "font-size-adjust:calc(1cap / 1px)", .metric = true },
        .{ .input = "font-size-adjust:0.5" },
        .{ .input = "font-size-adjust:cap-height from-font" },
    }) |case| {
        const value = blk: {
            var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.input);
            defer block.deinit();
            const value = (block.get(property.longhand) orelse return error.ExpectedAdjustDeclaration).value.value;
            value.retain();
            break :blk value;
        };
        defer value.release();
        try testing.expectEqual(case.tree, value.needsTreeCounts());
        try testing.expectEqual(case.random, value.needsRandomBase());
        try testing.expectEqual(case.metric, value.needsUnavailableMetrics(false));
    }
}

test "font size adjust keeps owned aspect dependencies and literal from font controls" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{});
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};

fn treeSource(allocator: Allocator, allowed: bool) !void {
    const property = css.properties.lookup("font-size-adjust") orelse return error.FontSizeAdjustNotImplemented;
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size-adjust:calc(sibling-index() / 10)");
    defer low.deinit();
    try testing.expect(low.get(property.longhand) != null);
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size-adjust:revert");
    defer high.deinit();
    var counts: Counts = .{};
    const style = try css.cascade.cascade(.{
        .allocator = allocator,
        .parent = null,
        .tree_counts = .{ .context = &counts, .get = Counts.get },
    }, &.{
        .{ .block = &low, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
        .{ .block = &high, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "0.3" else "0", out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
}

test "font size adjust uses the reverted winning source for tree math" {
    try testing.checkAllAllocationFailures(testing.allocator, treeSource, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, treeSource, .{true});
}

fn parentMetrics(allocator: Allocator) !void {
    const property = css.properties.lookup("font-size-adjust") orelse return error.FontSizeAdjustNotImplemented;
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;font-size-adjust:calc(1em / 1px)");
    defer block.deinit();
    try testing.expect(block.get(property.longhand) != null);
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings("20", out.items);
}

test "font size adjust joins the font affecting parent metric rule" {
    try testing.checkAllAllocationFailures(testing.allocator, parentMetrics, .{});
}
