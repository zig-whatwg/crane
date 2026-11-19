//! Lane css1: CSS Generated Content 3 §4.1 the quotes property -
//! auto | none | match-parent | [ <string> <string> ]+, inherited, initial
//! auto. match-parent computes to the parent's content language when the
//! inherited value is auto (serialized as match-parent), otherwise to the
//! inherited value. WPT css/css-content/parsing/quotes-valid.html and
//! quotes-computed.html (Chrome, Firefox and Safari 7/9 each; Firefox
//! Nightly 9/9 with match-parent).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;

fn specifiedOf(input: []const u8, out: *std.ArrayList(u8)) !bool {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    const set = try block.setProperty(.{ .allocator = testing.allocator }, "quotes", input, "");
    out.clearRetainingCapacity();
    try block.getPropertyValue("quotes", out);
    return set;
}

fn expectSpecified(input: []const u8, expected: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    _ = try specifiedOf(input, &text);
    try testing.expectEqualStrings(expected, text.items);
}

/// Computes `input` on a child of a parent whose quotes is `parent_input`
/// (null: the initial value) and reads the child's computed quotes.
fn expectComputed(parent_input: ?[]const u8, input: ?[]const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var parent_block = Block.init(allocator);
    defer parent_block.deinit();
    if (parent_input) |p| try testing.expect(try parent_block.setProperty(.{ .allocator = allocator }, "quotes", p, ""));
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var block = Block.init(allocator);
    defer block.deinit();
    if (input) |i| try testing.expect(try block.setProperty(.{ .allocator = allocator }, "quotes", i, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(.quotes, &text, allocator);
    try testing.expectEqualStrings(expected, text.items);
}

test "quotes is a supported, inherited property whose initial value is auto" {
    const property = css.properties.lookup("quotes") orelse return error.UnsupportedProperty;
    try testing.expect(property == .longhand);
    try testing.expect(property.longhand.inherited());
    try expectComputed(null, null, "auto");
}

test "quotes keywords parse case-insensitively and serialize lowercase" {
    try expectSpecified("none", "none");
    try expectSpecified("auto", "auto");
    try expectSpecified("match-parent", "match-parent");
    try expectSpecified("NONE", "none");
    try expectSpecified("Auto", "auto");
    try expectSpecified("Match-Parent", "match-parent");
}

test "quotes pairs of strings serialize as CSS strings" {
    try expectSpecified("\"\u{201C}\" \"\u{201D}\" \"\u{2018}\" \"\u{2019}\"", "\"\u{201C}\" \"\u{201D}\" \"\u{2018}\" \"\u{2019}\"");
    try expectSpecified("\"\u{00AB}\u{2005}\" \"\u{2005}\u{00BB}\" \"\u{2039}\u{2005}\" \"\u{2005}\u{203A}\"", "\"\u{00AB}\u{2005}\" \"\u{2005}\u{00BB}\" \"\u{2039}\u{2005}\" \"\u{2005}\u{203A}\"");
    try expectSpecified("\"\u{00BB}\" \"\"", "\"\u{00BB}\" \"\"");
    try expectSpecified("'a' 'b'", "\"a\" \"b\"");
    try expectSpecified("\"a\\\"\" \"b\"", "\"a\\\"\" \"b\"");
}

test "quotes rejects an odd number of strings, mixed values and other tokens" {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    for ([_][]const u8{ "\"a\"", "\"a\" \"b\" \"c\"", "none \"a\" \"b\"", "\"a\" \"b\" none", "auto none", "1px", "\"a\" b", "match-parent \"a\" \"b\"", "\"a\",\"b\"" }) |bad| {
        try testing.expect(!try specifiedOf(bad, &text));
        try testing.expectEqualStrings("", text.items);
    }
}

test "quotes computes as specified; match-parent follows the inherited value" {
    try expectComputed(null, "none", "none");
    try expectComputed(null, "\"a\" \"b\"", "\"a\" \"b\"");
    // The inherited value is auto: a content language, serialized match-parent.
    try expectComputed(null, "match-parent", "match-parent");
    try expectComputed("auto", "match-parent", "match-parent");
    // Otherwise the inherited value.
    try expectComputed("none", "match-parent", "none");
    try expectComputed("\"<\" \">\"", "match-parent", "\"<\" \">\"");
    // Inherited.
    try expectComputed("\"<\" \">\"", null, "\"<\" \">\"");
}
