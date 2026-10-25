//! Fonts4 §2.7 and Q28: specified system fonts stay pending until computation.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectProperty(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8, allocator: std.mem.Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn check(allocator: std.mem.Allocator, keyword: []const u8, override: ?[]const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = allocator };
    try testing.expect(try block.setProperty(options, "font", keyword, ""));
    try expectProperty(&block, "font", keyword, allocator);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.serialize(&text);
    const expected = try std.fmt.allocPrint(allocator, "font: {s};", .{keyword});
    defer allocator.free(expected);
    try testing.expectEqualStrings(expected, text.items);
    for ([_][]const u8{
        "font-style",            "font-variant-caps",      "font-weight",            "font-width",            "font-size",               "line-height",             "font-family",
        "font-feature-settings", "font-kerning",           "font-language-override", "font-optical-sizing",   "font-size-adjust",        "font-variant-alternates", "font-variant-east-asian",
        "font-variant-emoji",    "font-variant-ligatures", "font-variant-numeric",   "font-variant-position", "font-variation-settings",
    }) |name| try expectProperty(&block, name, "", allocator);
    // Q200: tmp/analysis/integrator-probes-1024d; the coupled CSSOM
    // getPropertyValue rule follows Safari for pending variant longhands.
    try expectProperty(&block, "font-variant", "", allocator);
    if (override) |name| {
        const value = if (std.mem.eql(u8, name, "font-weight")) "700" else "none";
        try testing.expect(try block.setProperty(options, name, value, ""));
        try expectProperty(&block, "font", "", allocator);
        try expectProperty(&block, name, value, allocator);
        try expectProperty(&block, "font-family", "", allocator);
        try expectProperty(&block, "font-size", "", allocator);
        text.clearRetainingCapacity();
        try block.serialize(&text);
        try testing.expect(std.mem.indexOf(u8, text.items, "font: ") == null);
        try testing.expect(std.mem.indexOf(u8, text.items, "font-style: ;") != null);
        try testing.expect(std.mem.indexOf(u8, text.items, "font-variant: normal;") != null);
    }
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const cases = .{
        .{ "font-family", "sans-serif" }, .{ "font-size", "16px" }, .{ "font-style", "normal" }, .{ "font-width", "100%" },
    };
    inline for (cases) |case| {
        text.clearRetainingCapacity();
        try style.serializeResolved(css.properties.lookup(case[0]).?.longhand, &text, allocator);
        try testing.expectEqualStrings(case[1], text.items);
    }
    text.clearRetainingCapacity();
    try style.serializeResolved(.font_weight, &text, allocator);
    try testing.expectEqualStrings(if (override != null and std.mem.eql(u8, override.?, "font-weight")) "700" else "400", text.items);
}

test "system font keywords keep pending longhands and compute the permitted UA fallback" {
    for ([_][]const u8{ "caption", "icon", "menu", "message-box", "small-caption", "status-bar" }) |keyword|
        try testing.checkAllAllocationFailures(testing.allocator, check, .{ keyword, @as(?[]const u8, null) });
}

test "overriding explicit or reset only system font members prevents shorthand serialization" {
    for ([_][]const u8{ "font-weight", "font-kerning" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, check, .{ "caption", @as(?[]const u8, name) });
}
