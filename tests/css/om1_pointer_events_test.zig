//! CSS UI 4 §6.2 / SVG 2 §15.6: one inherited property grammar.
const std = @import("std");
const css = @import("css");
const allocator = std.testing.allocator;

fn specified(input: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup("pointer-events") orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(allocator);
    }
    const valid = try css.properties.parseDeclaration(.{ .allocator = allocator }, property, input, &assignments);
    try std.testing.expectEqual(expected != null, valid);
    if (expected) |text| {
        try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeAssigned(assignments.items[0].longhand, assignments.items[0].value, &out, allocator);
        try std.testing.expectEqualStrings(text, out.items);
    }
}

fn resolved(style: *const css.computed_style.ComputedStyle, expected: []const u8) !void {
    const property = css.properties.lookup("pointer-events") orelse return error.MissingProperty;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try std.testing.expectEqualStrings(expected, out.items);
}

test "pointer-events accepts the full SVG grammar without a receiver" {
    const cases = .{
        .{ "auto", "auto" },                     .{ "none", "none" },                           .{ "bounding-box", "bounding-box" },
        .{ "visiblePainted", "visiblepainted" }, .{ "visibleFill", "visiblefill" },             .{ "visibleStroke", "visiblestroke" },
        .{ "visible", "visible" },               .{ "painted", "painted" },                     .{ "fill", "fill" },
        .{ "stroke", "stroke" },                 .{ "all", "all" },                             .{ "VISIBLEPAINTED", "visiblepainted" },
        .{ "n\\6f ne", "none" },                 .{ "/*a*/ visibleFill /*b*/", "visiblefill" },
    };
    inline for (cases) |case| try specified(case[0], case[1]);
    for ([_][]const u8{ "", "0", "hidden", "visible painted", "fill, stroke", "'none'", "none()" }) |value| try specified(value, null);
}

test "pointer-events computes the specified keyword and inherits it" {
    const initial = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{});
    defer initial.destroy();
    try resolved(initial, "auto");
    for ([_][]const u8{ "auto", "none", "bounding-box", "visiblepainted", "visiblefill", "visiblestroke", "visible", "painted", "fill", "stroke", "all" }) |value| {
        const source = try std.fmt.allocPrint(allocator, "pointer-events: {s}", .{value});
        defer allocator.free(source);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, source);
        defer block.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = initial }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        try resolved(parent, value);
        const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
        defer child.destroy();
        try resolved(child, value);
    }
}
