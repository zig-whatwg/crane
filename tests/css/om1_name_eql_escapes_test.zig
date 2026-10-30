//! CSS Syntax 3 §4.3.7 and §4.3.12: raw escape length is not name length.
//! Q117: keep the owning decoder and the ordinary-name comparison path.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn escapedName(allocator: std.mem.Allocator, name: []const u8, terminator: []const u8) ![]u8 {
    const hex = "0123456789abcdef";
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    for (name) |byte| {
        try out.appendSlice(allocator, "\\0000");
        try out.append(allocator, hex[byte >> 4]);
        try out.append(allocator, hex[byte & 15]);
        try out.appendSlice(allocator, terminator);
    }
    return out.toOwnedSlice(allocator);
}

fn wide(allocator: std.mem.Allocator, terminator: []const u8) !void {
    const text = try escapedName(allocator, "revert-layer", terminator);
    defer allocator.free(text);
    try std.testing.expect(text.len > 64);
    try std.testing.expect(css.tokenizer.nameEql(text, "revert-layer"));
    try std.testing.expect(css.tokenizer.nameEql(text, "REVERT-LAYER"));
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, css.properties.lookup("width") orelse return error.MissingProperty, text, &assignments));
    try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
    try std.testing.expect(assignments.items[0].value == .css_wide);
    try std.testing.expectEqual(css.style_values.CssWide.revert_layer, assignments.items[0].value.css_wide);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeAssigned(.width, assignments.items[0].value, &out, allocator);
    try std.testing.expectEqualStrings("revert-layer", out.items);
}

test "Q117 fully six-hex-escaped CSS-wide keyword with spaces" {
    try std.testing.checkAllAllocationFailures(a, wide, .{" "});
}

test "Q117 fully six-hex-escaped CSS-wide keyword with tabs" {
    try std.testing.checkAllAllocationFailures(a, wide, .{"\t"});
}

test "Q117 fully six-hex-escaped CSS-wide keyword with CRLF" {
    try std.testing.checkAllAllocationFailures(a, wide, .{"\r\n"});
}

fn gradient(allocator: std.mem.Allocator) !void {
    const name = try escapedName(allocator, "linear-gradient", " ");
    defer allocator.free(name);
    const source = try std.mem.concat(allocator, u8, &.{ name, "(red, blue)" });
    defer allocator.free(source);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, css.properties.lookup("background-image") orelse return error.MissingProperty, source, &assignments));
    try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeAssigned(.background_image, assignments.items[0].value, &out, allocator);
    try std.testing.expectEqualStrings("linear-gradient(red, blue)", out.items);
}

test "Q117 existing gradient caller accepts a long escaped function name" {
    try std.testing.checkAllAllocationFailures(a, gradient, .{});
}

test "Q117 a longer decoded name still does not match" {
    const text = try escapedName(a, "revert-layer-extra", " ");
    defer a.free(text);
    try std.testing.expect(!css.tokenizer.nameEql(text, "revert-layer"));
    try std.testing.expect(!css.tokenizer.nameEql("\\72 evert-layer", "revert"));
}

test "Q117 replacement code points never match an ASCII name" {
    for ([_][]const u8{ "\x00", "\xed\xa0\x80", "\\000000", "\\00d800", "\\110000" }) |raw| {
        const decoded = try css.tokenizer.decode(a, raw);
        defer a.free(decoded);
        try std.testing.expectEqualStrings("\u{FFFD}", decoded);
        try std.testing.expect(!css.tokenizer.nameEql(raw, "a"));
        try std.testing.expect(!css.tokenizer.nameEql(raw, ""));
    }
}

test "Q117 escape at EOF stays a replacement code point" {
    const decoded = try css.tokenizer.decode(a, "a\\");
    defer a.free(decoded);
    try std.testing.expectEqualStrings("a\u{FFFD}", decoded);
    try std.testing.expect(!css.tokenizer.nameEql("a\\", "a"));
    try std.testing.expect(!css.tokenizer.nameEql("a\\", "ab"));
}

fn decodeCase(allocator: std.mem.Allocator, raw: []const u8, expected: []const u8) !void {
    const decoded = try css.tokenizer.decode(allocator, raw);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
}

test "Q117 shared decoder keeps byte output and cleans up every allocation failure" {
    const cases = .{
        .{ "", "" },
        .{ "a\\41 B", "aAB" },
        .{ "\\000041\tB", "AB" },
        .{ "\\000041\r\nB", "AB" },
        .{ "a\\\nb", "ab" },
        .{ "a\\\r\nb", "ab" },
        .{ "a\\\x0cb", "ab" },
        .{ "\\é", "é" },
        .{ "\\\xc3", "\xc3" },
        .{ "\xff", "\xff" },
        .{ "\x00", "\u{FFFD}" },
        .{ "\xed\xa0\x80", "\u{FFFD}" },
        .{ "\\d800", "\u{FFFD}" },
        .{ "\\110000", "\u{FFFD}" },
        .{ "\\", "\u{FFFD}" },
    };
    inline for (cases) |case|
        try std.testing.checkAllAllocationFailures(a, decodeCase, .{ case[0], case[1] });
}
