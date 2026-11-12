//! Lane cssprop1 batch 2 (cluster C41): two CSS parsing rules outside the
//! property table.
//! - Values 4 Appendix C and Color 4 Appendix B: a quirky length or color
//!   is valid only in the properties they list, never in a shorthand that
//!   merely includes one (quirks/unitless-length/excluded-properties-003.html
//!   and quirks.html's "Excluded property" cases: inset, border-*, font).
//! - Media Queries 5 §8.1: a custom media query's <extension-name> keeps
//!   its case, and outside a boolean context its parentheses are a
//!   <general-enclosed> (css/mediaqueries/mq-escaped-serialization.html).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn lookup(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.UnsupportedProperty;
}

fn quirksAccepts(name: []const u8, text: []const u8) !bool {
    var list: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (list.items) |assignment| assignment.value.release();
        list.deinit(testing.allocator);
    }
    return css.properties.parseDeclaration(.{ .allocator = testing.allocator, .quirks = true }, try lookup(name), text, &list);
}

test "quirky lengths and colors only in the properties Values 4 and Color 4 list" {
    // Values 4 Appendix C: clip's rect() takes them; a shorthand that only
    // includes a listed longhand does not (inset, border, background, font).
    try testing.expect(try quirksAccepts("clip", "rect(1, 2, auto, 4)"));
    try testing.expect(try quirksAccepts("top", "1"));
    try testing.expect(try quirksAccepts("margin", "1 2"));
    try testing.expect(try quirksAccepts("padding", "1"));
    try testing.expect(try quirksAccepts("border-width", "1 2"));
    try testing.expect(!try quirksAccepts("inset", "1"));
    try testing.expect(!try quirksAccepts("inset", "1px 2"));
    try testing.expect(!try quirksAccepts("border", "red solid 1"));
    try testing.expect(!try quirksAccepts("border-top", "red solid 1"));
    try testing.expect(!try quirksAccepts("font", "normal normal normal 40 sans-serif"));
    // Color 4 Appendix B: border-color is listed, background is not.
    try testing.expect(try quirksAccepts("background-color", "ff0000"));
    try testing.expect(try quirksAccepts("border-color", "ff0000"));
    try testing.expect(!try quirksAccepts("background", "ff0000"));
    try testing.expect(!try quirksAccepts("border", "solid ff0000"));
}

fn mediaText(text: []const u8, expected: []const u8) !void {
    var parsed = try css.media_queries.MediaQueryList.parse(testing.allocator, text);
    defer parsed.deinit();
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try parsed.serialize(&out.writer);
    try testing.expectEqualStrings(expected, out.written());
}

test "a custom media name keeps its case, and outside a boolean context is general-enclosed" {
    // css/mediaqueries/mq-escaped-serialization.html (Chrome, Firefox and
    // Safari 1/1): identifiers serialized escaped, the dashed one as written.
    try mediaText("\\{screen and (--\\(FOO: bar)", "\\{screen and (--\\(FOO: bar)");
    try mediaText("(--Foo)", "(--Foo)");
    try mediaText("(--Foo > 3px)", "(--Foo > 3px)");
    try mediaText("(WIDTH: 10PX)", "(width: 10px)");
}
