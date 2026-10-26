//! Backgrounds3 API shape only; see BORDERS4-DELTA.md for superseded assumptions.
//! Q170 preparation only. UNRUN. Existing owner predicates, no owner internals.
//! Values5 §§9–10; row118 Q17/Q83 availability and winning-source rules.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { input: []const u8, tree: bool = false, random: bool = false, metric: bool = false };

fn dependencies(allocator: Allocator, case: Case) !void {
    const p = css.properties.lookup("box-shadow") orelse return error.BoxShadowNotImplemented;
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        const input = try allocator.dupe(u8, case.input);
        defer allocator.free(input);
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "box-shadow", input, ""));
        const value = (block.get(p.longhand) orelse return error.ExpectedTypedShadow).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(case.tree, value.needsTreeCounts());
    try testing.expectEqual(case.random, value.needsRandomBase());
    try testing.expectEqual(case.metric, value.needsUnavailableMetrics(false));
    // Family components require absolute computed lengths; do not pass a
    // geometry-tolerant true flag to inner scalars at cascade preflight.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(p.longhand, value, &out, allocator);
    try testing.expect(out.items.len != 0);
}

test "ci1 box shadow every layer and component forwards existing math Color dependencies" {
    for ([_]Case{
        .{ .input = "red 1px 2px" },
        .{ .input = "red random(fixed .5, 1px, 2px) 2px" },
        .{ .input = "red calc(sibling-index() * 1px) 2px", .tree = true },
        .{ .input = "red 1px calc(sibling-count() * 1px)", .tree = true },
        .{ .input = "red 1px 2px random(1px, 2px)", .random = true },
        .{ .input = "red 1px 2px 3px random(1px, 2px)", .random = true },
        .{ .input = "rgb(calc(sibling-index() * 20) 0 0) 1px 2px", .tree = true },
        .{ .input = "red 1px 2px, rgb(random(0, 200) 0 0) 3px 4px", .random = true },
        .{ .input = "red 1px 2px, blue 3px 4px calc(1cap) 0", .metric = true },
        .{ .input = "red 1px 2px, rgb(calc(1cap / 1px) 0 0) 3px 4px", .metric = true },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{case});
}

fn unavailable(allocator: Allocator, input: []const u8) !void {
    const p = css.properties.lookup("box-shadow") orelse return error.BoxShadowNotImplemented;
    var lower = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "box-shadow:red 7px 8px");
    defer lower.deinit();
    var higher = css.declarations.DeclarationBlock.init(allocator);
    defer higher.deinit();
    try testing.expect(try higher.setProperty(.{ .allocator = allocator }, "box-shadow", input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &lower, .source = .{ .origin = .user } },
        .{ .block = &higher, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqualStrings("rgb(255, 0, 0) 7px 8px 0px 0px", out.items);
}

test "ci1 box shadow unavailable nested metric or random selects the real lower candidate" {
    for ([_][]const u8{ "blue random(1px, 2px) 2px", "blue 1px 2px, red 3px 4px 1cap", "rgb(calc(1cap / 1px) 0 0) 1px 2px" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, unavailable, .{input});
}

fn twentyLayers(allocator: Allocator) !void {
    const p = css.properties.lookup("box-shadow") orelse return error.BoxShadowNotImplemented;
    var input: std.ArrayList(u8) = .empty;
    defer input.deinit(allocator);
    for (0..20) |i| {
        if (i != 0) try input.appendSlice(allocator, ", ");
        try input.appendSlice(allocator, if (i % 2 == 0) "red 1px 2px" else "blue -3px 4px 5px -6px inset");
    }
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "box-shadow", input.items, ""));
    input.clearRetainingCapacity();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqual(@as(usize, 19), std.mem.count(u8, out.items, ", rgb"));
    try testing.expect(std.mem.startsWith(u8, out.items, "rgb(255, 0, 0) 1px 2px 0px 0px, rgb(0, 0, 255) -3px 4px 5px -6px inset"));
}

test "ci1 box shadow supports at least twenty ordered comma layers with allocation cleanup" {
    try testing.checkAllAllocationFailures(testing.allocator, twentyLayers, .{});
}

const Tree = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Tree = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 5 };
    }
};

fn winnerSource(allocator: Allocator, allowed: bool) !void {
    const p = css.properties.lookup("box-shadow") orelse return error.BoxShadowNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "box-shadow:rgb(calc(sibling-index() * 20) 0 0) calc(sibling-index() * 1px) 2px");
    defer block.deinit();
    try testing.expect(block.get(p.longhand) != null);
    var tree: Tree = .{};
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &tree, .get = Tree.get } }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_count_allowed = allowed } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "rgb(60, 0, 0) 3px 2px 0px 0px" else "rgb(0, 0, 0) 0px 2px 0px 0px", out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), tree.calls);
}

test "ci1 box shadow nested color and lengths use one winning tree-count source" {
    try testing.checkAllAllocationFailures(testing.allocator, winnerSource, .{true});
    try testing.checkAllAllocationFailures(testing.allocator, winnerSource, .{false});
}
