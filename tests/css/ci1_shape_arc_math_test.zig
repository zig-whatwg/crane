//! Shapes1 §3.1.1 arc rotation is an angle component, with Values4 math.
//! The existing shape-function-valid.html:83–95 pins literal zero omission
//! and rotation syntax; math keeps its specified expression until compute.
//! Q142 FINAL: Chrome155/Firefox158/Safari27 agree; exact probe receipts:
//! tmp/analysis/integrator-probes-1024a/results/q142-{chrome,firefox,safari}.json.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Case = struct { input: []const u8, specified: ?[]const u8, computed: []const u8 };
fn stages(allocator: Allocator, case: Case) !void {
    const style = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "clip-path", case.input, ""));
        if (case.specified) |expected| {
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(allocator);
            try block.getPropertyValue("clip-path", &text);
            try testing.expectEqualStrings(expected, text.items);
        }
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.clip_path, &out, allocator);
    try testing.expectEqualStrings(case.computed, out.items);
}

test "shape arc rotation math keeps specified expressions and computes degrees or omitted zero" {
    for ([_]Case{
        .{ .input = "shape(from 0 0, arc by 10px 20px of 5px rotate calc(0.25turn + 90deg))", .specified = "shape(from 0px 0px, arc by 10px 20px of 5px rotate calc(180deg))", .computed = "shape(from 0px 0px, arc by 10px 20px of 5px rotate 180deg)" },
        .{ .input = "shape(from 0 0, arc by 10px 20px of 5px rotate calc(90deg - 180deg))", .specified = "shape(from 0px 0px, arc by 10px 20px of 5px rotate calc(-90deg))", .computed = "shape(from 0px 0px, arc by 10px 20px of 5px rotate -90deg)" },
        // Shapes1 §3.3 omits default computed components. Q142's three-browser
        // probe keeps specified math zero but omits literal zero at both stages.
        .{ .input = "shape(from 0 0, arc by 10px 20px of 5px rotate calc(360deg - 1turn))", .specified = "shape(from 0px 0px, arc by 10px 20px of 5px rotate calc(0deg))", .computed = "shape(from 0px 0px, arc by 10px 20px of 5px)" },
        .{ .input = "shape(from 0 0, arc by 10px 20px of 5px rotate 0deg)", .specified = "shape(from 0px 0px, arc by 10px 20px of 5px)", .computed = "shape(from 0px 0px, arc by 10px 20px of 5px)" },
        .{ .input = "shape(from 0 0, arc by 10px 20px of 5px rotate calc(10deg + 5deg))", .specified = "shape(from 0px 0px, arc by 10px 20px of 5px rotate calc(15deg))", .computed = "shape(from 0px 0px, arc by 10px 20px of 5px rotate 15deg)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, stages, .{case});
}

fn dependencies(allocator: Allocator, expression: []const u8, tree: bool, random: bool, metrics: bool) !void {
    const value = blk: {
        const input = try std.fmt.allocPrint(allocator, "shape(from 0 0, arc by 10px 20px of 5px rotate {s})", .{expression});
        defer allocator.free(input);
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "clip-path", input, ""));
        const value = block.get(.clip_path).?.value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(false));
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(true));
}

test "shape arc rotation retains tree random and unavailable angle-metric dependencies" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "calc(1turn)", false, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "calc(sibling-index() * 30deg)", true, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "random(10deg, 20deg)", false, true, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "random(fixed 0.5, 10deg, 20deg)", false, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "calc(1deg * sign(1cap - 10px))", false, false, true });
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};
fn inherited(allocator: Allocator, allowed: bool) !void {
    var counts: Counts = .{};
    const child = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;clip-path:shape(from 0 0, arc by 10px 20px of 5px rotate calc(30deg * sibling-index() + 1deg * sign(1em - 10px)))");
        defer user.deinit();
        try testing.expect(user.get(.clip_path) != null);
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "clip-path:revert");
        defer author.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
        defer parent.destroy();
        var inherit = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:5px;clip-path:inherit");
        defer inherit.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherit, .source = .{ .origin = .author, .tree_scope = .{ .serial = 1234 }, .tree_count_allowed = !allowed } }});
    };
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(.clip_path, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "shape(from 0px 0px, arc by 10px 20px of 5px rotate 91deg)" else "shape(from 0px 0px, arc by 10px 20px of 5px rotate 1deg)", out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    try testing.expect(!child.get(.clip_path).needsTreeCounts());
}

test "shape arc rotation uses the actual winning source and remains computed after parent release" {
    try testing.checkAllAllocationFailures(testing.allocator, inherited, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, inherited, .{true});
}

fn randomFallback(allocator: Allocator, fixed: bool) !void {
    const style = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (fixed)
            "clip-path:none;clip-path:shape(from 0 0, arc by 10px 20px of 5px rotate random(fixed 0.5, 10deg, 20deg))"
        else
            "clip-path:none;clip-path:shape(from 0 0, arc by 10px 20px of 5px rotate random(10deg, 20deg))");
        defer block.deinit();
        try testing.expect(block.get(.clip_path).?.value.value == .shape);
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.clip_path, &out, allocator);
    try testing.expectEqualStrings(if (fixed) "shape(from 0px 0px, arc by 10px 20px of 5px rotate 15deg)" else "none", out.items);
}

test "shape arc rotation unavailable random falls back while fixed random computes" {
    try testing.checkAllAllocationFailures(testing.allocator, randomFallback, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, randomFallback, .{true});
}

fn invalid(allocator: Allocator, expression: []const u8) !void {
    const input = try std.fmt.allocPrint(allocator, "shape(from 0 0, arc by 10px 20px of 5px rotate {s})", .{expression});
    defer allocator.free(input);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(!try block.setProperty(.{ .allocator = allocator }, "clip-path", input, ""));
}

test "shape arc rotation math rejects non-angle dimensions and untyped zero" {
    for ([_][]const u8{ "calc(1px)", "calc(10%)", "calc(2)", "calc(0)", "0" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, invalid, .{input});
}
