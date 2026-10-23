//! CSS UI 4 §6.1 / CSS Contain 2 §4: keyword grammars and computed values.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    const valid = try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, input, &assignments);
    try testing.expectEqual(expected != null, valid);
    if (expected) |text| {
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeAssigned(assignments.items[0].longhand, assignments.items[0].value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

fn computed(style: *const css.computed_style.ComputedStyle, name: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingProperty;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(property.longhand, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "user-select keyword grammar, CSS escapes, alias and rejection" {
    for ([_][]const u8{ "auto", "text", "none", "contain", "all", "inherit", "initial", "unset", "revert" }) |value| {
        try check("user-select", value, value);
        try check("-webkit-user-select", value, value);
    }
    try check("user-select", "TEXT", "text");
    try check("user-select", "t\\65 xt", "text");
    try check("user-select", "/* before */ none /* after */", "none");
    for ([_][]const u8{ "", "bogus", "none text", "text, none", "0", "'none'", "text()" }) |value| try check("user-select", value, null);
}

test "content-visibility keyword grammar and rejection" {
    for ([_][]const u8{ "visible", "hidden", "auto", "inherit", "initial", "unset" }) |value| try check("content-visibility", value, value);
    try check("content-visibility", "HIDDEN", "hidden");
    try check("content-visibility", "h\\69 dden", "hidden");
    for ([_][]const u8{ "", "none", "collapse", "visible hidden", "0", "'hidden'" }) |value| try check("content-visibility", value, null);
}

test "interaction longhands are non-inherited and retain specified computed keywords" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "user-select: none; content-visibility: hidden");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    try computed(parent, "user-select", "none");
    try computed(parent, "content-visibility", "hidden");
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    try computed(child, "user-select", "auto");
    try computed(child, "content-visibility", "visible");
    var inherit = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "user-select: inherit; content-visibility: inherit");
    defer inherit.deinit();
    const inherited = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &inherit, .source = .{ .origin = .author } }});
    defer inherited.destroy();
    try computed(inherited, "user-select", "none");
    try computed(inherited, "content-visibility", "hidden");
}
