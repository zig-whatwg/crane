//! Paged Media3 §8.1; Q86 Chrome156/Firefox158/Safari27 probe,2026-10-27.
//! The main spec and both computed implementations choose noninheritance.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn specified(allocator: std.mem.Allocator, input: []const u8, expected: ?[]const u8) anyerror!void {
    const property = css.properties.lookup("page") orelse return error.MissingPageProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    const valid = try css.properties.parseDeclaration(.{ .allocator = allocator }, property, input, &assignments);
    try std.testing.expectEqual(expected != null, valid);
    if (expected) |want| {
        try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeAssigned(property.longhand, assignments.items[0].value, &out, allocator);
        try std.testing.expectEqualStrings(want, out.items);
    }
}

test "Q86 page custom identifiers preserve case and canonical escapes" {
    const cases = .{
        .{ "auto", "auto" },       .{ "AUTO", "auto" },       .{ "Foo", "Foo" },       .{ "FOO", "FOO" },
        .{ "f\\6f o", "foo" },     .{ "\\31 23", "\\31 23" }, .{ "a\\ b", "a\\ b" },   .{ "initial", "initial" },
        .{ "inherit", "inherit" }, .{ "unset", "unset" },     .{ "revert", "revert" }, .{ "revert-layer", "revert-layer" },
    };
    inline for (cases) |case| try std.testing.checkAllAllocationFailures(a, specified, .{ case[0], @as(?[]const u8, case[1]) });
}
test "Q86 page rejects values outside auto or custom-ident" {
    for ([_][]const u8{ "default", "DEFAULT", "Foo Bar", "Foo, Bar", "12", "'Foo'", "foo()" }) |text|
        try specified(a, text, null);
}
fn resolved(style: *const css.computed_style.ComputedStyle, expected: []const u8) !void {
    const property = css.properties.lookup("page") orelse return error.MissingPageProperty;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try style.serializeResolved(property.longhand, &out, a);
    try std.testing.expectEqualStrings(expected, out.items);
}

test "Q86 page is noninherited with auto initial value and explicit inherit support" {
    const property = css.properties.lookup("page") orelse return error.MissingPageProperty;
    try std.testing.expect(!property.longhand.inherited());
    const initial = try css.cascade.cascade(.{ .allocator = a, .parent = null }, &.{});
    defer initial.destroy();
    try resolved(initial, "auto");
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "page: Foo");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = a, .parent = initial }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    try resolved(parent, "Foo");
    const cases = .{
        .{ "", "auto" },            .{ "page: auto", "auto" },    .{ "page: inherit", "Foo" },
        .{ "page: unset", "auto" }, .{ "page: initial", "auto" }, .{ "page: Bar", "Bar" },
        .{ "page: FOO", "FOO" },    .{ "page: f\\6f o", "foo" },  .{ "page: \\31 23", "\\31 23" },
    };
    inline for (cases) |case| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, case[0]);
        defer block.deinit();
        const child = try css.cascade.cascade(.{ .allocator = a, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer child.destroy();
        try resolved(child, case[1]);
    }
}

test "Q86 page is the named fifth native custom-name classifier exception" {
    const property = css.properties.lookup("page") orelse return error.MissingPageProperty;
    if (comptime !@hasDecl(css.typed_om, "text_keywords")) return std.testing.expect(false);
    const cases = .{ .{ "Foo", "Foo" }, .{ "FOO", "FOO" }, .{ "\\31 23", "123" }, .{ "a\\ b", "a b" } };
    inline for (cases) |case| {
        var keywords = (try css.typed_om.text_keywords.classify(a, property.longhand, case[0])) orelse return error.TestExpectedValue;
        defer keywords.deinit();
        try std.testing.expectEqual(@as(usize, 1), keywords.items.len);
        try std.testing.expectEqualStrings(case[1], keywords.items[0]);
    }
    try std.testing.expect(try css.typed_om.text_keywords.classify(a, property.longhand, "Foo Bar") == null);
}
