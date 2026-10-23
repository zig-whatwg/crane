//! Values 5 §10; Q44's borrowed provider and source-scope rules.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "tree counting functions keep specified syntax and clone scalar counts" {
    if (comptime !@hasField(css.math_values.Context, "tree_counts")) return error.TreeCountsNotImplemented;
    const parsed = try css.math_values.parse(testing.allocator, "calc(2px * sibling-index() + 1px * sibling-count())", .{ .kind = .length }) orelse return error.InvalidTreeFunction;
    defer parsed.expression.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try parsed.expression.serialize(&out, testing.allocator);
    const specified = try testing.allocator.dupe(u8, out.items);
    defer testing.allocator.free(specified);
    const computed = try parsed.expression.compute(testing.allocator, .{ .tree_counts = .{ .index = 3, .count = 8 } });
    defer computed.unref();
    try testing.expectEqual(@as(f64, 14), computed.computedNumber().?.value);
    out.clearRetainingCapacity();
    try parsed.expression.serialize(&out, testing.allocator);
    try testing.expectEqualStrings(specified, out.items);
    const naked = try css.math_values.parse(testing.allocator, "calc(sibling-index())", .{ .kind = .integer }) orelse return error.InvalidTreeFunction;
    defer naked.expression.unref();
    out.clearRetainingCapacity();
    try naked.expression.serialize(&out, testing.allocator);
    try testing.expectEqualStrings("sibling-index()", out.items);
    for ([_][]const u8{ "sibling-index(1)", "sibling-count(foo)", "sibling-count(,)" }) |bad| {
        const rejected = try css.math_values.parse(testing.allocator, bad, .{ .kind = .number });
        defer if (rejected) |p| p.expression.unref();
        try testing.expect(rejected == null);
    }
}

test "cascade asks for counts once and only for a winning permitted value" {
    if (comptime !@hasField(css.cascade.Context, "tree_counts")) return error.TreeProviderNotImplemented;
    const Probe = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) css.math_values.TreeCounts {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 3, .count = 8 };
        }
    };
    var probe = Probe{};
    const cases = .{
        .{ "opacity:.5;left:2px", true, 0, "2px" },
        .{ "left:calc(1px * sibling-index());left:2px", true, 0, "2px" },
        .{ "left:calc(1px * sibling-index());top:calc(1px * sibling-count())", true, 1, "3px" },
        .{ "left:calc(1px * sibling-index());top:calc(1px * sibling-count())", false, 0, "0px" },
        .{ "left:max(1px,calc(1px * sibling-index()));animation-duration:calc(1s * sibling-count());grid-template-columns:repeat(sibling-index(),1px)", true, 1, "3px" },
    };
    inline for (cases) |c| {
        probe.calls = 0;
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, c[0]);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .tree_counts = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_count_allowed = c[1] } }});
        defer style.destroy();
        try testing.expectEqual(@as(usize, c[2]), probe.calls);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try style.serializeResolved(.left, &out, testing.allocator);
        try testing.expectEqualStrings(c[3], out.items);
    }
}

test "tree counting inheritance keeps the parent's computed number" {
    if (comptime !@hasField(css.cascade.Context, "tree_counts")) return error.TreeProviderNotImplemented;
    const Probe = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) css.math_values.TreeCounts {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 3, .count = 8 };
        }
    };
    var probe = Probe{};
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:calc(10px * sibling-index());animation-duration:calc(1s * sibling-count())");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .tree_counts = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    try testing.expectEqual(@as(usize, 1), probe.calls);
    var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "animation-duration:inherit");
    defer inherited.deinit();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .tree_counts = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &inherited, .source = .{ .origin = .author } }});
    defer child.destroy();
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expectEqual(@as(f64, 30), child.get(.font_size).length.value);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try child.serializeResolved(.animation_duration, &out, testing.allocator);
    try testing.expectEqualStrings("8s", out.items);
}

test "source scope follows each winning nested value independently" {
    if (comptime !@hasField(css.cascade.Context, "tree_counts")) return error.TreeProviderNotImplemented;
    const Probe = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) css.math_values.TreeCounts {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 3, .count = 8 };
        }
    };
    var probe = Probe{};
    var inner = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:calc(1px * sibling-index());top:calc(1px * sibling-count());animation-duration:calc(1s * sibling-count())");
    defer inner.deinit();
    var outer = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:max(1px,calc(1px * sibling-index()));animation-duration:calc(1s * sibling-count())");
    defer outer.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .tree_counts = .{ .context = &probe, .get = Probe.get } }, &.{
        .{ .block = &inner, .source = .{ .origin = .author } },
        .{ .block = &outer, .source = .{ .origin = .author, .order = 1, .tree_count_allowed = false } },
    });
    defer style.destroy();
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expectEqual(@as(f64, 1), style.get(.left).length.value);
    try testing.expectEqual(@as(f64, 8), style.get(.top).length.value);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(.animation_duration, &out, testing.allocator);
    try testing.expectEqualStrings("0s", out.items);
}

test "tree counting math owns no provider during allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasField(css.math_values.Context, "tree_counts")) return error.TreeCountsNotImplemented;
    const parsed = try css.math_values.parse(allocator, "calc(sibling-count() * min(sibling-index(), 10))", .{ .kind = .number }) orelse return error.InvalidTreeFunction;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(allocator, .{ .tree_counts = .{ .index = 3, .count = 8 } });
    defer computed.unref();
    try testing.expectEqual(@as(f64, 24), computed.computedNumber().?.value);
}

// Q105: append to cv1_sibling_values_test.zig before the partial-product fix.
test "partial numeric products fold around unresolved sibling values" {
    const cases = .{
        .{ "calc(sibling-index() * 2rad * pi)", .angle, "calc(360deg * sibling-index())", @as(f64, 1080), .deg },
        .{ "calc(sibling-count() * 1rad * pi)", .angle, "calc(180deg * sibling-count())", @as(f64, 1440), .deg },
        .{ "calc(2px * 3 * sibling-index())", .length, "calc(6px * sibling-index())", @as(f64, 18), .px },
        .{ "calc(2px * sibling-index() * 3 / 2)", .length, "calc(3px * sibling-index())", @as(f64, 9), .px },
        .{ "calc(2px * sibling-index() * 3s / 2s)", .length, "calc(3px * sibling-index())", @as(f64, 9), .px },
        .{ "calc(sibling-index() * 2em * 3)", .length, "calc(6em * sibling-index())", @as(f64, 288), .px },
    };
    inline for (cases) |case| {
        const parsed = try css.math_values.parse(testing.allocator, case[0], .{ .kind = case[1] }) orelse return error.InvalidMath;
        defer parsed.expression.unref();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try parsed.expression.serialize(&out, testing.allocator);
        try testing.expectEqualStrings(case[2], out.items);
        try testing.expect(parsed.expression.needsTreeCounts());
        const computed = try parsed.expression.compute(testing.allocator, .{ .tree_counts = .{ .index = 3, .count = 8 } });
        defer computed.unref();
        try testing.expectEqual(case[4], computed.computedNumber().?.unit);
        try testing.expectApproxEqAbs(case[3], computed.computedNumber().?.value, 0.00001);
    }
}

test "partial products preserve unknown metric cancellation and nonfinite multiplication" {
    const cases = .{
        .{ "calc(sibling-index() * 0px * infinity)", @as(f64, 0) },
        .{ "calc(sibling-index() * 2px * NaN)", @as(f64, 0) },
        .{ "calc(sibling-index() * 2px * infinity)", std.math.floatMax(f64) },
    };
    inline for (cases) |case| {
        const parsed = try css.math_values.parse(testing.allocator, case[0], .{ .kind = .length }) orelse return error.InvalidMath;
        defer parsed.expression.unref();
        try testing.expect(parsed.expression.needsTreeCounts());
        const computed = try parsed.expression.compute(testing.allocator, .{ .tree_counts = .{ .index = 3, .count = 8 } });
        defer computed.unref();
        try testing.expectEqual(case[1], computed.computedNumber().?.value);
    }
    const unresolved = try css.math_values.parse(testing.allocator, "calc(2px * 3em / 1rem * sibling-index())", .{ .kind = .length }) orelse return error.InvalidMath;
    defer unresolved.expression.unref();
    try testing.expect(unresolved.expression.needsTreeCounts());
    try testing.expect(unresolved.expression.knownNumber() == null);
    const computed = try unresolved.expression.compute(testing.allocator, .{ .font_size = 10, .root_font_size = 20, .tree_counts = .{ .index = 3, .count = 8 } });
    defer computed.unref();
    try testing.expectEqual(@as(f64, 9), computed.computedNumber().?.value);
}
