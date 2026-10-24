//! Filter Effects §5–6: grammar, computed components, and resource order.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectText(input: []const u8, expected: ?[]const u8, computed: bool) !void {
    const p = css.properties.lookup("filter") orelse return error.FilterNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:lime;font-size:20px");
    defer block.deinit();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    const valid = try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments);
    try testing.expectEqual(expected != null, valid);
    if (expected) |text| {
        const value = assignments.items[0].value.value;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        if (computed) {
            try block.entries.ensureUnusedCapacity(testing.allocator, 1);
            value.retain();
            block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = p.longhand, .value = .{ .value = value }, .important = false } });
            const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
            defer style.destroy();
            try style.serializeResolved(p.longhand, &out, testing.allocator);
        } else try css.properties.serializeValue(p.longhand, value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "filter functions validate component types ranges and omitted arguments" {
    try expectText("none", "none", false);
    try expectText("BlUr(0) GrAyScAlE(300%)", "blur(0px) grayscale(100%)", false);
    try expectText("drop-shadow(1px 2px red)", "drop-shadow(red 1px 2px)", false);
    try expectText("url(a) blur(2em) url(#f)", "url(\"a\") blur(2em) url(\"#f\")", false);
    for ([_][]const u8{ "none blur(0)", "blur(-1px)", "blur(1%)", "blur(2)", "hue-rotate(2)", "brightness(-1)", "opacity(2px)", "drop-shadow()", "drop-shadow(1px)", "drop-shadow(1px 2px -1px)", "drop-shadow(1px 2px 3px 4px)", "drop-shadow(1px 2px inset)", "drop-shadow(1px 2px red blue)", "blur(1px), blur(2px)" }) |bad| try expectText(bad, null, false);
}

test "filter computes percentages lengths default arguments and current color" {
    try expectText("blur() brightness() contrast() hue-rotate()", "blur(0px) brightness(1) contrast(1) hue-rotate(0deg)", true);
    try expectText("grayscale() invert() opacity() saturate() sepia()", "grayscale(1) invert(1) opacity(1) saturate(1) sepia(1)", true);
    try expectText("blur(2em) brightness(300%) hue-rotate(0.5turn)", "blur(40px) brightness(3) hue-rotate(180deg)", true);
    try expectText("drop-shadow(1em 2px)", "drop-shadow(rgb(0, 255, 0) 20px 2px 0px)", true);
    try expectText("drop-shadow(1px 2px 3px #ff0000)", "drop-shadow(rgb(255, 0, 0) 1px 2px 3px)", true);
}
