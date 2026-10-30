//! CSS Syntax 3 §4.3.12, CSS Values 4 §4.1.1, Cascade 5 §7.3.
//! An ident's decoded value determines its CSS-wide keyword meaning.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn keyword(allocator: std.mem.Allocator, name: []const u8, input: []const u8, expected: css.style_values.CssWide) !void {
    const property = css.properties.lookup(name) orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, input, &assignments));
    const count: usize = switch (property) {
        .longhand => 1,
        .shorthand => |shorthand| shorthand.longhands().len,
    };
    try std.testing.expectEqual(count, assignments.items.len);
    for (assignments.items) |item| {
        try std.testing.expect(item.value == .css_wide);
        try std.testing.expectEqual(expected, item.value.css_wide);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeAssigned(item.longhand, item.value, &out, allocator);
        try std.testing.expectEqualStrings(expected.name(), out.items);
    }
}

fn acrossProperties(input: []const u8, expected: css.style_values.CssWide) !void {
    for ([_][]const u8{ "width", "color", "margin" }) |name|
        try std.testing.checkAllAllocationFailures(a, keyword, .{ name, input, expected });
}

test "Q115 escaped initial sets and serializes every assigned longhand" {
    try acrossProperties("\\69 nitial", .initial);
}

test "Q115 escaped inherit sets and serializes every assigned longhand" {
    try acrossProperties("\\69 nherit", .inherit);
}

test "Q115 escaped unset sets and serializes every assigned longhand" {
    try acrossProperties("\\75 nset", .unset);
}

test "Q115 escaped revert sets and serializes every assigned longhand" {
    try acrossProperties("\\72 evert", .revert);
}

test "Q115 escaped revert-layer sets and serializes every assigned longhand" {
    try acrossProperties("\\72 evert-layer", .revert_layer);
}

test "Q115 escaped revert-rule sets and serializes every assigned longhand" {
    try acrossProperties("\\72 evert-rule", .revert_rule);
}

test "Q115 escaped keywords retain ASCII case-insensitive matching" {
    try acrossProperties("\\49 NHERIT", .inherit);
    try acrossProperties("r\\65 vert-layer", .revert_layer);
}

fn invalid(allocator: std.mem.Allocator, input: []const u8) !void {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, css.properties.lookup("width") orelse return error.MissingProperty, input, &assignments));
    try std.testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "Q115 escaped CSS-wide keyword with a trailing token stays invalid" {
    for ([_][]const u8{ "\\69 nherit 2px", "r\\65 vert-layer auto", "\\75 nset, initial" }) |input|
        try std.testing.checkAllAllocationFailures(a, invalid, .{input});
}

fn ordinaryName(allocator: std.mem.Allocator) !void {
    const property = css.properties.lookup("animation-name") orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, "F\\6f o", &assignments));
    try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
    try std.testing.expect(assignments.items[0].value == .value);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeAssigned(property.longhand, assignments.items[0].value, &out, allocator);
    try std.testing.expectEqualStrings("Foo", out.items);
}

test "Q115 an escaped non-wide custom identifier is unchanged" {
    try std.testing.checkAllAllocationFailures(a, ordinaryName, .{});
}

test "Q115 malformed escapes cannot become a CSS-wide keyword" {
    for ([_][]const u8{ "\\\ninherit", "inhe\\\nrit", "inheri\\", "\\000000nherit", "\\110000nherit" }) |input|
        try std.testing.checkAllAllocationFailures(a, invalid, .{input});
}
