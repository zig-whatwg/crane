//! Q59–Q63: elementless accepted-unavailable data and checked computed views.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Checks = if (@hasDecl(css, "font_request")) struct {
    const requests = css.font_request;
    fn unavailable(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{ "1cap serif", "calc(1cap) serif", "calc(1rcap) serif" }) |input| {
            var result = (try requests.parseForFontLoading(.{ .allocator = allocator }, input)) orelse return error.ExpectedAcceptedFont;
            defer result.deinit();
            try testing.expect(result == .accepted_unavailable);
            const partial = result.accepted_unavailable;
            try testing.expectEqual(@as(?f32, null), partial.size_px);
            try testing.expectEqual(@as(?f32, 400), partial.weight);
            try testing.expectEqual(@as(?f32, 100), partial.stretch_pct);
            try testing.expect(partial.style == .normal);
            try testing.expect(partial.line_height.? == .normal);
            try testing.expect(partial.families[0] == .generic);
        }
        for ([_][]const u8{ "1em/calc(1cap) serif", "16px/calc(1cap) serif" }) |input| {
            var result = (try requests.parseForFontLoading(.{ .allocator = allocator }, input)) orelse return error.ExpectedAcceptedFont;
            defer result.deinit();
            try testing.expect(result == .accepted_unavailable);
            try testing.expectEqual(@as(?f32, 16), result.accepted_unavailable.size_px);
            try testing.expect(result.accepted_unavailable.line_height == null);
        }
    }
    fn matching(allocator: std.mem.Allocator) !void {
        // Q60, integrator-probes-1023o: accepted by Chrome/Safari. CSS does
        // not turn the consumer's temporary matching fallback into a value.
        var weight = (try requests.parseForFontLoading(.{ .allocator = allocator }, "calc(1cap / 1px) 16px 'Face'")) orelse return error.ExpectedAcceptedFont;
        defer weight.deinit();
        try testing.expect(weight == .accepted_unavailable);
        try testing.expectEqual(@as(?f32, null), weight.accepted_unavailable.weight);
        try testing.expectEqual(@as(?f32, 16), weight.accepted_unavailable.size_px);
        try testing.expect(weight.accepted_unavailable.style == .normal);
        try testing.expectEqualStrings("Face", weight.accepted_unavailable.families[0].named.name);
        var angle = (try requests.parseForFontLoading(.{ .allocator = allocator }, "oblique calc(1cap / 1px * 1deg) 16px 'Face'")) orelse return error.ExpectedAcceptedFont;
        defer angle.deinit();
        try testing.expect(angle == .accepted_unavailable);
        try testing.expect(angle.accepted_unavailable.style == .oblique);
        try testing.expectEqual(@as(?f32, null), angle.accepted_unavailable.style.oblique);
        try testing.expectEqual(@as(?f32, 400), angle.accepted_unavailable.weight);
    }
    fn propagation(allocator: std.mem.Allocator) !void {
        const cases = [_]struct { text: []const u8, expected: ?requests.LineHeight }{
            .{ .text = "calc(1cap)/normal serif", .expected = .normal },
            .{ .text = "calc(1cap)/2 serif", .expected = .{ .number = 2 } },
            .{ .text = "calc(1cap)/10px serif", .expected = .{ .px = 10 } },
            .{ .text = "calc(1cap)/1in serif", .expected = .{ .px = 96 } },
            .{ .text = "calc(1cap)/2em serif", .expected = null },
            .{ .text = "calc(1cap)/125% serif", .expected = null },
            .{ .text = "calc(1cap)/calc(1em + 1px) serif", .expected = null },
            // Q63 deliberately conservatively defers every calculation.
            .{ .text = "calc(1cap)/calc(10px + 1px) serif", .expected = null },
        };
        for (cases) |case| {
            var result = (try requests.parseForFontLoading(.{ .allocator = allocator }, case.text)) orelse return error.ExpectedAcceptedFont;
            defer result.deinit();
            try testing.expect(result == .accepted_unavailable);
            try testing.expectEqualDeep(case.expected, result.accepted_unavailable.line_height);
        }
    }
    fn fallbacks(allocator: std.mem.Allocator) !void {
        const cases = [_]struct { text: []const u8, size: f32 }{
            .{ .text = "calc(1ex) serif", .size = 8 },
            .{ .text = "calc(1ch) serif", .size = 8 },
            .{ .text = "calc(1ic) serif", .size = 16 },
            .{ .text = "calc(1lh) serif", .size = 19.2 },
            .{ .text = "calc(1vw) serif", .size = 12 },
            .{ .text = "bold calc(1em + 2px) serif", .size = 18 },
        };
        for (cases) |case| {
            var result = (try requests.parseForFontLoading(.{ .allocator = allocator, .viewport_width = 1200, .viewport_height = 900 }, case.text)) orelse return error.ExpectedResolvedFont;
            defer result.deinit();
            try testing.expect(result == .resolved);
            try testing.expectApproxEqAbs(case.size, result.resolved.size_px, 0.0001);
        }
    }
    fn containerFallback(allocator: std.mem.Allocator) !void {
        // Q64/Q88: row118's six container units arrive through gated MAIN
        // (Q93). Pin the current parse rejection, then automatically require
        // the same 12px small-viewport fallback when the real unit exists.
        var result = try requests.parseForFontLoading(.{ .allocator = allocator, .viewport_width = 1200, .viewport_height = 900 }, "calc(1cqw) serif");
        defer if (result) |*value| value.deinit();
        if (comptime @hasField(css.math_values.Unit, "cqw")) {
            try testing.expect(result != null);
            try testing.expect(result.? == .resolved);
            try testing.expectApproxEqAbs(@as(f32, 12), result.?.resolved.size_px, 0.0001);
        } else {
            try testing.expect(result == null);
        }
    }

    fn checkedViews(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{
            "",                                           "font-size:calc(1cap)",             "font-weight:calc(1cap / 1px)",
            "font-style:oblique calc(1cap / 1px * 1deg)", "font-width:calc(1cap / 1px * 1%)",
        }) |input| {
            var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
            defer block.deinit();
            const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
            defer style.destroy();
            const view = requests.fromComputed(style) orelse return error.ExpectedComputedFont;
            try testing.expectEqual(@as(f32, 16), view.size_px);
            try testing.expectEqual(@as(f32, 400), view.weight);
            try testing.expectEqual(@as(f32, 100), view.stretch_pct);
            try testing.expect(view.style == .normal);
        }
        // Defensive typed checks reject a deliberately non-computed value.
        const style = try css.computed_style.ComputedStyle.initial(allocator);
        defer style.destroy();
        style.values[@intFromEnum(css.properties.Longhand.font_size)].release();
        style.values[@intFromEnum(css.properties.Longhand.font_size)] = .{ .length = .em(2) };
        try testing.expect(requests.fromComputed(style) == null);
    }
} else struct {};

test "font loading keeps unavailable size and line-height distinct from syntax and defaults" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.unavailable, .{});
}
test "font loading exposes unavailable weight and oblique angle without matching fallbacks" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.matching, .{});
}
test "unavailable size propagates conservatively to dependent and calculated line-height" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.propagation, .{});
}
test "font loading uses shared initial-font fallbacks and caller viewport" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.fallbacks, .{});
}
test "computed font request views check scalars after the default unavailable-metric predicate" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.checkedViews, .{});
}

test "font loading container fallback pins the owner gap and activates with the real unit" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.containerFallback, .{});
}
