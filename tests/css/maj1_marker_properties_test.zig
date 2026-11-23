//! CSS Pseudo 4 §3.1.2: "Only a limited set of properties can be used on
//! the ::marker pseudo-element" - the font properties, white-space, color,
//! text-combine-upright, unicode-bidi, direction, content, the animation
//! and transition properties, and the inherited text properties; a
//! declaration of any other property does not apply. Chrome, Firefox and
//! Safari agree (wpt.fyi 2358bd4835, css/css-pseudo/parsing/
//! marker-supported-properties.html: display, position, float and the
//! list-style longhands are not applied; the rest are).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;

fn markerValue(declarations: []const u8, name: []const u8, out: *std.ArrayList(u8)) !void {
    const allocator = testing.allocator;
    var block = try Block.parse(.{ .allocator = allocator }, declarations);
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .pseudo = "marker" }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const property = css.properties.lookup(name) orelse return error.UnsupportedProperty;
    out.clearRetainingCapacity();
    try style.serializeResolved(property.longhand, out, allocator);
}

test "::marker ignores the layout and list properties" {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    const cases = [_][3][]const u8{
        .{ "position: absolute", "position", "static" },
        .{ "float: right", "float", "none" },
        .{ "list-style-position: inside", "list-style-position", "outside" },
        .{ "list-style-type: decimal", "list-style-type", "disc" },
        .{ "list-style-image: url(foo)", "list-style-image", "none" },
    };
    for (cases) |case| {
        try markerValue(case[0], case[1], &text);
        if (!std.mem.eql(u8, case[2], text.items)) std.debug.print("{s}: got {s}\n", .{ case[0], text.items });
        try testing.expectEqualStrings(case[2], text.items);
    }
}

test "::marker takes the font, text, color, content, animation and transition properties" {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    const cases = [_][3][]const u8{
        .{ "font-size: 25px", "font-size", "25px" },
        .{ "line-height: 50px", "line-height", "50px" },
        .{ "color: rgb(0, 100, 200)", "color", "rgb(0, 100, 200)" },
        .{ "content: \"foo\"", "content", "\"foo\"" },
        .{ "direction: rtl", "direction", "rtl" },
        .{ "letter-spacing: 10px", "letter-spacing", "10px" },
        .{ "text-transform: uppercase", "text-transform", "uppercase" },
        .{ "animation-name: anim", "animation-name", "anim" },
        .{ "transition-duration: 2s", "transition-duration", "2s" },
        .{ "cursor: move", "cursor", "move" },
        .{ "white-space-collapse: preserve", "white-space-collapse", "preserve" },
    };
    for (cases) |case| {
        try markerValue(case[0], case[1], &text);
        if (!std.mem.eql(u8, case[2], text.items)) std.debug.print("{s}: got {s}\n", .{ case[0], text.items });
        try testing.expectEqualStrings(case[2], text.items);
    }
}
