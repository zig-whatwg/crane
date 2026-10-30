//! Q59: native canonical text stays a cold Typed OM concern.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Case = struct { property: []const u8, input: []const u8, keywords: ?[]const []const u8 };
const cases = [_]Case{
    .{ .property = "color-scheme", .input = "LIGHT", .keywords = &.{"light"} },
    .{ .property = "color-scheme", .input = "dark", .keywords = &.{"dark"} },
    .{ .property = "color-scheme", .input = "My\\ Scheme", .keywords = &.{"My Scheme"} },
    .{ .property = "color-scheme", .input = "light dark", .keywords = null },
    .{ .property = "color-scheme", .input = "only light", .keywords = null },
    .{ .property = "anchor-name", .input = "--AbC", .keywords = &.{"--AbC"} },
    .{ .property = "anchor-name", .input = "--AbC, --a\\ b", .keywords = null },
    .{ .property = "anchor-scope", .input = "--AbC", .keywords = &.{"--AbC"} },
    .{ .property = "anchor-scope", .input = "--a\\ b", .keywords = &.{"--a b"} },
    .{ .property = "anchor-scope", .input = "--AbC, --b", .keywords = null },
    .{ .property = "position-anchor", .input = "--AbC", .keywords = &.{"--AbC"} },
    .{ .property = "font-variant-ligatures", .input = "NO-COMMON-LIGATURES", .keywords = &.{"no-common-ligatures"} },
    .{ .property = "font-variant-ligatures", .input = "no-common-ligatures discretionary-ligatures", .keywords = null },
    .{ .property = "font-variant-caps", .input = "SMALL-CAPS", .keywords = &.{"small-caps"} },
    .{ .property = "font-variant-alternates", .input = "HISTORICAL-FORMS", .keywords = &.{"historical-forms"} },
    .{ .property = "font-variant-alternates", .input = "historical-forms styleset(foo)", .keywords = null },
    .{ .property = "font-variant-numeric", .input = "TABULAR-NUMS", .keywords = &.{"tabular-nums"} },
    .{ .property = "font-variant-numeric", .input = "tabular-nums oldstyle-nums", .keywords = null },
    .{ .property = "font-variant-east-asian", .input = "JIS04", .keywords = &.{"jis04"} },
    .{ .property = "font-variant-east-asian", .input = "jis04 full-width", .keywords = null },
    .{ .property = "font-variant-position", .input = "SUPER", .keywords = &.{"super"} },
    .{ .property = "font-variant-emoji", .input = "UNICODE", .keywords = &.{"unicode"} },
    .{ .property = "font-language-override", .input = "'ENG '", .keywords = null },
    .{ .property = "text-emphasis-style", .input = "'filled'", .keywords = null },
};

fn check(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "text_keywords")) return std.testing.expect(false);
    const property = (css.properties.lookup(case.property) orelse return error.MissingProperty);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.input, &assignments));
    const value = assignments.items[0].value.value;
    try std.testing.expect(value == .text or value == .color_scheme);
    const canonical = if (value == .text) value.text.bytes else value.color_scheme.text.bytes;
    var result = try css.typed_om.text_keywords.classify(allocator, property.longhand, canonical);
    defer if (result) |*keywords| keywords.deinit();
    if (case.keywords) |expected| {
        const keywords = result orelse return error.TestExpectedValue;
        try std.testing.expectEqual(expected.len, keywords.items.len);
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        for (expected, keywords.items, 0..) |name, actual, index| {
            try std.testing.expectEqualStrings(name, actual);
            if (index != 0) try text.appendSlice(allocator, ", ");
            const escaped = try css.serialize.serializeIdentifier(allocator, actual);
            defer allocator.free(escaped);
            try text.appendSlice(allocator, escaped);
        }
        // Keyword serialization preserves the canonical declaration value.
        try std.testing.expectEqualStrings(canonical, text.items);
    } else try std.testing.expect(result == null);
}

test "only the Q59 canonical text properties produce singleton identifiers; anchor-name and scope lists stay whole" {
    for (cases) |case| try check(a, case);
    if (comptime !@hasDecl(css.typed_om, "text_keywords")) return std.testing.expect(false);
    try std.testing.expect(try css.typed_om.text_keywords.classify(a, .width, "auto") == null);
    try std.testing.expect(try css.typed_om.text_keywords.classify(a, .position_anchor, "--a, --b") == null);
    try std.testing.expect(try css.typed_om.text_keywords.classify(a, .font_variant_caps, "small-caps normal") == null);
    try std.testing.expect(try css.typed_om.text_keywords.classify(a, .font_variant_position, "super sub") == null);
    try std.testing.expect(try css.typed_om.text_keywords.classify(a, .font_variant_emoji, "emoji text") == null);
}

test "canonical text classifier unwinds every allocation failure" {
    for (cases) |case| try std.testing.checkAllAllocationFailures(a, check, .{case});
}
