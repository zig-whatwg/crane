//! Values 4 §6.1.1: dependencies and root metrics for relative lengths.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn style(text: []const u8, context: css.cascade.Context) !*css.computed_style.ComputedStyle {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(context, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}
fn expect(s: *const css.computed_style.ComputedStyle, property: []const u8, wanted: []const u8) !void {
    const p = css.properties.lookup(property) orelse return error.MissingProperty;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try s.serializeResolved(p.longhand, &text, testing.allocator);
    try testing.expectEqualStrings(wanted, text.items);
}

test "lh uses the computed line height and avoids font and line height cycles" {
    const parent = try style("font-size:16px;line-height:40px", .{ .allocator = testing.allocator, .parent = null });
    defer parent.destroy();
    const child = try style("width:2lh;height:calc(2lh);font-size:calc(1lh)", .{ .allocator = testing.allocator, .parent = parent });
    defer child.destroy();
    try expect(child, "width", "80px");
    try expect(child, "height", "80px");
    try expect(child, "font-size", "40px");
    const line = try style("font-size:20px;line-height:2lh", .{ .allocator = testing.allocator, .parent = parent });
    defer line.destroy();
    try expect(line, "line-height", "80px");
}

test "root rem and rlh use its own metrics outside font affecting properties" {
    const root = try style("font-size:20px;line-height:2;width:1rem;height:2rlh;margin-left:calc(2rlh)", .{ .allocator = testing.allocator, .parent = null, .is_root = true });
    defer root.destroy();
    try expect(root, "width", "20px");
    try expect(root, "height", "80px");
    try expect(root, "margin-left", "80px");
}

test "upright vertical ch and root rch use the font metric fallback rule" {
    const s = try style("writing-mode:vertical-rl;text-orientation:upright;width:1ch;height:calc(1ch);margin-left:calc(1rch)", .{ .allocator = testing.allocator, .parent = null, .root_vertical = true, .root_upright = true, .root_font_size = 20 });
    defer s.destroy();
    try expect(s, "width", "16px");
    try expect(s, "height", "16px");
    try expect(s, "margin-left", "20px");
}

test "logical viewport units use this box axis even on a font affecting property" {
    const s = try style("writing-mode:vertical-rl;font-size:calc(1vi);width:1vi;height:calc(1vb)", .{ .allocator = testing.allocator, .parent = null, .viewport_width = 1000, .viewport_height = 500 });
    defer s.destroy();
    try expect(s, "font-size", "5px");
    try expect(s, "width", "5px");
    try expect(s, "height", "10px");
}

test "known limitation: same-block cap fallback is removed by CSSOM" {
    // Q24: expected failure until font metrics exist. CSSOM correctly removes
    // the earlier duplicate; no hidden declaration history is permitted.
    const have_font_metrics = false;
    if (!have_font_metrics) return error.SkipZigTest;
    const s = try style("font-size:20px;font-size:2cap;line-height:30px;line-height:2rcap;width:2lh;height:calc(2rlh)", .{ .allocator = testing.allocator, .parent = null, .is_root = true });
    defer s.destroy();
    try expect(s, "font-size", "20px");
    try expect(s, "line-height", "30px");
    try expect(s, "width", "60px");
    try expect(s, "height", "60px");
}

test "unavailable cap metrics allow the next retained cascade candidate" {
    var earlier = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:20px;line-height:30px");
    defer earlier.deinit();
    var later = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:2cap;line-height:2rcap;width:2lh;height:calc(2rlh)");
    defer later.deinit();
    const s = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{
        .{ .block = &earlier, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &later, .source = .{ .origin = .author, .order = 2 } },
    });
    defer s.destroy();
    try expect(s, "font-size", "20px");
    try expect(s, "line-height", "30px");
    try expect(s, "width", "60px");
    try expect(s, "height", "60px");
}

test "cap dependent unitless scalars wait for metrics and cancellation does not" {
    for ([_][]const u8{ "font-weight", "opacity", "z-index" }, [_][]const u8{ "400", "1", "auto" }) |property, initial| {
        const declaration = try std.fmt.allocPrint(testing.allocator, "{s}:calc(1cap / 1px)", .{property});
        defer testing.allocator.free(declaration);
        const s = try style(declaration, .{ .allocator = testing.allocator, .parent = null });
        defer s.destroy();
        try expect(s, property, initial);
    }
    const cancelled = try style("font-weight:calc(100 * 1cap / 1cap);opacity:calc(1cap / 1cap);z-index:calc(1cap / 1cap)", .{ .allocator = testing.allocator, .parent = null });
    defer cancelled.destroy();
    try expect(cancelled, "font-weight", "100");
    try expect(cancelled, "opacity", "1");
    try expect(cancelled, "z-index", "1");
}

test "unknown scalar math kinds require available metrics by default" {
    const math = css.math_values;
    if (!@hasDecl(math.Expression, "needsUnavailableMetrics")) return error.MissingMetricGuard;
    const parsed = (try math.parse(testing.allocator, "calc(1cap / 1px * 1s)", .{ .kind = .time })) orelse return error.MissingTypedTime;
    defer parsed.expression.unref();
    // A newly introduced time-valued property is not named in the cascade.
    // Even a mistaken geometry allowance cannot make a non-length deferable.
    try testing.expect(parsed.expression.needsUnavailableMetrics(false));
    try testing.expect(parsed.expression.needsUnavailableMetrics(true));
}
