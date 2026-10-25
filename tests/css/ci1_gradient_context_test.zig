//! Images4 computed components use the actual winning Source (Q137).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn expectImage(allocator: Allocator, style: *const css.computed_style.ComputedStyle, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.background_image, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};

fn winningSource(allocator: Allocator, allowed: bool) !void {
    var counts: Counts = .{};
    const child = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "background-image:conic-gradient(at calc(sibling-index() * 1px) calc(sibling-count() * 1px), red, blue)");
        defer user.deinit();
        try testing.expect(user.get(.background_image) != null);
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "background-image:revert");
        defer author.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
        defer parent.destroy();
        var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "background-image:inherit");
        defer inherited.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author, .tree_count_allowed = !allowed } }});
    };
    defer child.destroy();
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    try expectImage(allocator, child, if (allowed) "conic-gradient(at 3px 7px, rgb(255, 0, 0), rgb(0, 0, 255))" else "conic-gradient(at 0px 0px, rgb(255, 0, 0), rgb(0, 0, 255))");
}

test "gradient pair computation uses the winning permission and survives all source owners" {
    try testing.checkAllAllocationFailures(testing.allocator, winningSource, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, winningSource, .{true});
}

fn randomCandidate(allocator: Allocator, fixed: bool) !void {
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "background-image:url(lower)");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (fixed)
        "background-image:conic-gradient(at random(fixed .5, 2px, 4px) center, red, blue)"
    else
        "background-image:conic-gradient(at random(2px, 4px) center, red, blue)");
    defer high.deinit();
    try testing.expect(high.get(.background_image) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .user } },
        .{ .block = &high, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    try expectImage(allocator, style, if (fixed) "conic-gradient(at 3px 50%, rgb(255, 0, 0), rgb(0, 0, 255))" else "url(\"lower\")");
}

test "gradient random positions skip unavailable candidates while fixed inputs compute" {
    try testing.checkAllAllocationFailures(testing.allocator, randomCandidate, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, randomCandidate, .{true});
}

fn metrics(allocator: Allocator, input: []const u8) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", input, ""));
        const value = (block.get(.background_image) orelse return error.ExpectedGradient).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expect(value.needsUnavailableMetrics(false));
    try testing.expect(!value.needsUnavailableMetrics(true));
    try testing.expect(!value.needsTreeCounts() and !value.needsRandomBase());
}

test "both gradient position axes preserve the unavailable metric query" {
    for ([_][]const u8{
        "radial-gradient(at calc(1cap) center, red, blue)",
        "radial-gradient(at center calc(1cap), red, blue)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, metrics, .{input});
}

fn center(allocator: Allocator, input: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    // Images4 §8: serialize the computed default position identically to
    // gradient-position-computed.html's center and 50% 50% controls.
    try expectImage(allocator, style, "conic-gradient(rgb(255, 0, 0), rgb(0, 0, 255))");
}

test "computed default gradient position is independent of its math spelling" {
    for ([_][]const u8{
        "conic-gradient(at calc(50%) calc(50%), red, blue)",
        "conic-gradient(at right calc(50%) bottom calc(50%), red, blue)",
        "conic-gradient(at calc(50% + 0px) center, red, blue)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, center, .{input});
}
