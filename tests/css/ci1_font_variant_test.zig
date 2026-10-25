//! Fonts4 §§6.4–6.11: independent variant categories and shorthand resets.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectValue(name: []const u8, text: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.FontVariantNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, text, &assignments));
    if (expected) |want| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try block.entries.ensureTotalCapacity(testing.allocator, assignments.items.len);
        for (assignments.items) |a| {
            a.value.retain();
            block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = a.longhand, .value = a.value, .important = false } });
        }
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(want, out.items);
    }
}

test "font variants canonicalize complete categories and reject duplicates" {
    try expectValue("font-variant-ligatures", "no-contextual common-ligatures historical-ligatures", "common-ligatures historical-ligatures no-contextual");
    try expectValue("font-variant-numeric", "slashed-zero ordinal stacked-fractions proportional-nums lining-nums", "lining-nums proportional-nums stacked-fractions ordinal slashed-zero");
    try expectValue("font-variant-east-asian", "ruby full-width simplified", "simplified full-width ruby");
    try expectValue("font-variant-caps", "all-petite-caps", "all-petite-caps");
    try expectValue("font-variant-position", "super", "super");
    try expectValue("font-variant-emoji", "unicode", "unicode");
    const invalid = .{
        .{ "font-variant-ligatures", "common-ligatures no-common-ligatures" },
        .{ "font-variant-numeric", "ordinal slashed-zero ordinal" },
        .{ "font-variant-numeric", "diagonal-fractions stacked-fractions" },
        .{ "font-variant-east-asian", "jis78 jis83" },
        .{ "font-variant-east-asian", "full-width proportional-width" },
        .{ "font-variant-caps", "small-caps titling-caps" },
        .{ "font-variant-position", "sub super" },
        .{ "font-variant-emoji", "text emoji" },
    };
    inline for (invalid) |item| try expectValue(item[0], item[1], null);
}

test "font alternate functions keep case-sensitive names and canonical function order" {
    try expectValue("font-variant-alternates", "annotation(Last) styleset(First,Second) historical-forms stylistic(Flowing)", "stylistic(Flowing) historical-forms styleset(First, Second) annotation(Last)");
    try expectValue("font-variant-alternates", "styleset(\\46 irst, none) character-variant(inherit, default)", "styleset(First, none) character-variant(inherit, default)");
    for ([_][]const u8{ "annotation()", "stylistic(one,two)", "styleset(one,)", "styleset(one two)", "swash(one) swash(two)", "historical-forms(argument)", "normal swash(one)", "swash('quoted')" }) |bad| try expectValue("font-variant-alternates", bad, null);
}

test "font variant shorthand resets all seven components but leaves unrelated settings" {
    try expectValue("font-variant", "super ruby tabular-nums small-caps no-contextual emoji", "no-contextual small-caps tabular-nums ruby super emoji");
    try expectValue("font-variant", "normal", "normal");
    try expectValue("font-variant", "none", "none");
    for ([_][]const u8{ "normal small-caps", "none small-caps", "small-caps normal", "sub super", "emoji text", "ruby sub ruby" }) |bad| try expectValue("font-variant", bad, null);
    _ = css.properties.lookup("font-variant") orelse return error.FontVariantNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-feature-settings:'liga' 0;font-language-override:'ENG';font-variation-settings:'wght' 700;font-variant:small-caps ruby;font-variant:none");
    defer block.deinit();
    const names = .{ "font-variant-ligatures", "font-variant-caps", "font-variant-alternates", "font-variant-numeric", "font-variant-east-asian", "font-variant-position", "font-variant-emoji", "font-feature-settings", "font-language-override", "font-variation-settings" };
    const texts = .{ "none", "normal", "normal", "normal", "normal", "normal", "normal", "\"liga\" 0", "\"ENG\"", "\"wght\" 700" };
    inline for (names, texts) |name, wanted| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(wanted, out.items);
    }
}
