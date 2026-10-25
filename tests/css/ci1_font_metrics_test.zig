//! Fonts5 §3.4 and Q27/Q46: unknown capability differs from known missing font.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const ready = @hasDecl(css, "font_size_adjust") and @hasField(css.cascade.Context, "font_metric_ratios");
const Checks = if (ready) struct {
    const State = struct { ratio: ?f64, called: bool = false, request_ok: bool = false };
    fn ratio(context: ?*anyopaque, request: css.font_request.View, metric: css.font_size_adjust.Metric) ?f64 {
        const state: *State = @ptrCast(@alignCast(context.?));
        state.called = true;
        state.request_ok = metric == .cap_height and request.families.len == 1 and
            request.families[0] == .named and std.mem.eql(u8, request.families[0].named.name, "Kept Font") and
            request.families[0].named.scope.serial == 31 and request.style == .oblique and request.style.oblique == 10 and
            request.weight == 700 and request.stretch_pct == 75 and request.size_px == 24;
        return state.ratio;
    }
    fn run(allocator: std.mem.Allocator, present: bool, returned: ?f64, expected: []const u8) !void {
        var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size-adjust:0.4");
        defer low.deinit();
        var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font:oblique 10deg 700 condensed 24px 'Kept Font';font-size-adjust:cap-height from-font");
        defer high.deinit();
        var state = State{ .ratio = returned };
        const resolver: ?css.font_size_adjust.MetricResolver = if (present) .{ .context = &state, .resolve = ratio } else null;
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .font_metric_ratios = resolver }, &.{
            .{ .block = &low, .source = .{ .origin = .user } },
            .{ .block = &high, .source = .{ .origin = .author, .tree_scope = .{ .serial = 31 } } },
        });
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try style.serializeResolved(css.properties.lookup("font-size-adjust").?.longhand, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
        try testing.expectEqual(present, state.called);
        if (present) try testing.expect(state.request_ok);
        const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = style }, &.{});
        defer child.destroy();
        out.clearRetainingCapacity();
        try child.serializeResolved(css.properties.lookup("font-size-adjust").?.longhand, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
} else struct {};

test "font size adjust skips unknown capability and retains the next candidate" {
    if (comptime !ready) return error.FontMetricResolverNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.run, .{ false, @as(?f64, null), "0.4" });
}
test "font size adjust knows missing font separately from missing capability" {
    if (comptime !ready) return error.FontMetricResolverNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.run, .{ true, @as(?f64, null), "none" });
}
test "font size adjust receives a complete scoped request and inherits its computed ratio" {
    if (comptime !ready) return error.FontMetricResolverNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.run, .{ true, @as(?f64, 0.61), "cap-height 0.61" });
}
