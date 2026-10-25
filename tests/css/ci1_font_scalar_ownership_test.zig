//! Fonts4: computed style owns oblique and setting values through inheritance.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(allocator: std.mem.Allocator) !void {
    const settings = css.properties.lookup("font-feature-settings") orelse return error.FontSettingsNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-style:oblique calc(9deg + 5deg);font-width:75%;font-feature-settings:'smcp' on,'dlig' 0,'smcp' 2;font-variation-settings:'wght' calc(450 + 100),'wdth' 70;font-variant-alternates:styleset(one,two) swash(three)");
    var owns_block = true;
    defer if (owns_block) block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    var owns_parent = true;
    defer if (owns_parent) parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    block.deinit();
    owns_block = false;
    parent.destroy();
    owns_parent = false;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(settings.longhand, &out, allocator);
    try testing.expectEqualStrings("\"dlig\" 0, \"smcp\" 2", out.items);
    const cases = .{
        .{ "font-style", "oblique 14deg" },
        .{ "font-width", "75%" },
        .{ "font-variation-settings", "\"wdth\" 70, \"wght\" 550" },
        .{ "font-variant-alternates", "styleset(one, two) swash(three)" },
    };
    inline for (cases) |case| {
        out.clearRetainingCapacity();
        try child.serializeResolved(css.properties.lookup(case[0]).?.longhand, &out, allocator);
        try testing.expectEqualStrings(case[1], out.items);
    }
}

test "font scalar aggregates survive both declaration and parent under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{});
}

test "font affecting predicate leaves ordinary properties and line height at their default" {
    if (comptime !@hasDecl(css, "font_values")) return error.FontAffectingPredicateNotImplemented;
    try testing.expect(!css.font_values.isFontAffecting(.width));
    try testing.expect(!css.font_values.isFontAffecting(.line_height));
    try testing.expect(!css.font_values.isFontAffecting(.font_variant_emoji));
    try testing.expect(css.font_values.isFontAffecting(.font_style));
    try testing.expect(css.font_values.isFontAffecting(.font_width));
    try testing.expect(css.font_values.isFontAffecting(.font_feature_settings));
    try testing.expect(css.font_values.isFontAffecting(.font_variation_settings));
}
