//! Fonts4 effective values retain Values5 dependencies and the winning source.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Case = struct {
    property: []const u8,
    input: []const u8,
    tree: bool = false,
    random: bool = false,
    metric: bool = false,
};

fn dependency(allocator: Allocator, case: Case) !void {
    const property = css.properties.lookup(case.property) orelse return error.FontPropertyNotImplemented;
    const value = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.input);
        defer block.deinit();
        const value = (block.get(property.longhand) orelse return error.ExpectedFontDeclaration).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    // Queries operate on the owned typed value after the actual declaration
    // and random parse scope have gone away. No fabricated key or graph.
    try testing.expectEqual(case.tree, value.needsTreeCounts());
    try testing.expectEqual(case.random, value.needsRandomBase());
    try testing.expectEqual(case.metric, value.needsUnavailableMetrics(false));
    try testing.expectEqual(case.metric, value.needsUnavailableMetrics(true));
}

test "font scalar dependencies follow real typed declarations and effective duplicate tags" {
    for ([_]Case{
        .{ .property = "font-style", .input = "font-style:oblique calc(sibling-index() * 10deg)", .tree = true },
        .{ .property = "font-style", .input = "font-style:oblique random(0deg, 20deg)", .random = true },
        .{ .property = "font-style", .input = "font-style:oblique random(fixed .5, 0deg, 20deg)" },
        .{ .property = "font-style", .input = "font-style:oblique calc(1cap / 1px * 1deg)", .metric = true },
        .{ .property = "font-feature-settings", .input = "font-feature-settings:'liga' calc(sibling-count())", .tree = true },
        .{ .property = "font-variation-settings", .input = "font-variation-settings:'wght' random(100, 900)", .random = true },
        .{ .property = "font-variation-settings", .input = "font-variation-settings:'wght' random(fixed .5, 100, 900)" },
        .{ .property = "font-feature-settings", .input = "font-feature-settings:'liga' calc(1cap / 1px)", .metric = true },
        .{ .property = "font-feature-settings", .input = "font-feature-settings:'liga' calc(sibling-count()),'liga' 1" },
        .{ .property = "font-feature-settings", .input = "font-feature-settings:'liga' 1,'liga' calc(sibling-count())", .tree = true },
        .{ .property = "font-variation-settings", .input = "font-variation-settings:'wght' random(100, 900),'wght' 400" },
        .{ .property = "font-variation-settings", .input = "font-variation-settings:'wght' 400,'wght' random(100, 900)", .random = true },
        .{ .property = "font-feature-settings", .input = "font-feature-settings:'liga' calc(1cap / 1px),'liga' 1" },
        .{ .property = "font-feature-settings", .input = "font-feature-settings:'liga' 1,'liga' calc(1cap / 1px)", .metric = true },
        .{ .property = "font-style", .input = "font-style:oblique 14deg" },
        .{ .property = "font-width", .input = "font-width:condensed" },
        .{ .property = "font-variant-alternates", .input = "font-variant-alternates:styleset(sibling-index, random)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, dependency, .{case});
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};

fn expectResolved(style: *const css.computed_style.ComputedStyle, allocator: Allocator, name: []const u8, wanted: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.FontPropertyNotImplemented;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(wanted, out.items);
}

fn winningSource(allocator: Allocator, allowed: bool) !void {
    var counts: Counts = .{};
    const child = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-style:oblique calc(sibling-index() * 10deg);" ++
            "font-feature-settings:'liga' calc(sibling-count());" ++
            "font-variation-settings:'wght' calc(sibling-index() * 100)");
        defer user.deinit();
        for ([_][]const u8{ "font-style", "font-feature-settings", "font-variation-settings" }) |name| {
            const property = css.properties.lookup(name) orelse return error.FontPropertyNotImplemented;
            try testing.expect(user.get(property.longhand) != null);
        }
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-style:revert;font-feature-settings:revert;font-variation-settings:revert");
        defer author.deinit();
        var source: css.cascade.Source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed };
        const parent = try css.cascade.cascade(.{
            .allocator = allocator,
            .parent = null,
            .tree_counts = .{ .context = &counts, .get = Counts.get },
        }, &.{
            .{ .block = &user, .source = source },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
        defer parent.destroy();
        // Cascade5 §7.3: revert selects the user's declaration and permission.
        // Inheritance then keeps its result, not a borrowed Source pointer.
        source.tree_scope.serial = 1234;
        source.tree_count_allowed = !allowed;
        var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-style:inherit;font-feature-settings:inherit;font-variation-settings:inherit");
        defer inherited.deinit();
        break :blk try css.cascade.cascade(.{
            .allocator = allocator,
            .parent = parent,
            .tree_counts = .{ .context = &counts, .get = Counts.get },
        }, &.{.{ .block = &inherited, .source = source }});
    };
    defer child.destroy();
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    try expectResolved(child, allocator, "font-style", if (allowed) "oblique 30deg" else "normal");
    try expectResolved(child, allocator, "font-feature-settings", if (allowed) "\"liga\" 7" else "\"liga\" 0");
    try expectResolved(child, allocator, "font-variation-settings", if (allowed) "\"wght\" 300" else "\"wght\" 0");
}

test "font computations use the winning tree permission once and own inherited results" {
    try testing.checkAllAllocationFailures(testing.allocator, winningSource, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, winningSource, .{true});
}

fn randomCandidate(allocator: Allocator, fixed: bool) !void {
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-style:italic;font-feature-settings:'liga' 2");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (fixed)
        "font-style:oblique random(fixed .5, 0deg, 20deg);font-feature-settings:'liga' random(fixed .5, 0, 20)"
    else
        "font-style:oblique random(0deg, 20deg);font-feature-settings:'liga' random(0, 20)");
    defer high.deinit();
    for ([_][]const u8{ "font-style", "font-feature-settings" }) |name| {
        const property = css.properties.lookup(name) orelse return error.FontPropertyNotImplemented;
        try testing.expect(high.get(property.longhand) != null);
    }
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .user } },
        .{ .block = &high, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    try expectResolved(style, allocator, "font-style", if (fixed) "oblique 10deg" else "italic");
    try expectResolved(style, allocator, "font-feature-settings", if (fixed) "\"liga\" 10" else "\"liga\" 2");
}

test "font random candidates skip missing inputs while fixed random remains computable" {
    try testing.checkAllAllocationFailures(testing.allocator, randomCandidate, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, randomCandidate, .{true});
}
