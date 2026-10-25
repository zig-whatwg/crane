//! CSS Fonts4: syntax, canonical serialization, reset semantics and ownership.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectValue(name: []const u8, input: []const u8, expected: ?[]const u8, computed: bool) !void {
    const property = css.properties.lookup(name) orelse return error.FontPropertyNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, input, &assignments));
    if (expected) |text| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try block.entries.ensureTotalCapacity(testing.allocator, assignments.items.len);
        for (assignments.items) |item| {
            item.value.retain();
            block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = item.longhand, .value = item.value, .important = false } });
        }
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        if (computed) {
            const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
            defer style.destroy();
            try style.serializeResolved(property.longhand, &out, testing.allocator);
        } else try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "font shorthand canonicalizes each prefix slot and resets every supported subproperty" {
    try expectValue("font", "condensed 700 small-caps italic 20px/1.2 'Helvetica Neue', serif", "italic small-caps 700 condensed 20px / 1.2 Helvetica Neue, serif", false);
    try expectValue("font", "normal normal normal normal 20px / normal serif", "20px serif", false);
    try expectValue("font", "large menu", "large menu", false);
    try expectValue("font", "oblique calc(12px) serif", "oblique calc(12px) serif", false);
    for ([_][]const u8{ "normal normal normal normal normal 12px serif", "italic oblique 12px serif", "small-caps small-caps 12px serif", "12px", "100% 12px serif", "common-ligatures 12px serif", "caption icon" }) |bad| try expectValue("font", bad, null, false);
    const reset_names = [_][]const u8{
        "font-feature-settings", "font-kerning", "font-language-override", "font-optical-sizing", "font-size-adjust", "font-variant-alternates", "font-variant-east-asian", "font-variant-emoji", "font-variant-ligatures", "font-variant-numeric", "font-variant-position", "font-variation-settings",
    };
    _ = css.properties.lookup("font") orelse return error.FontNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-feature-settings:'liga' 0;font-kerning:none;font-language-override:'ENG';font-optical-sizing:none;font-size-adjust:0.5;font-variant-alternates:historical-forms;font-variant-east-asian:ruby;font-variant-emoji:text;font-variant-ligatures:none;font-variant-numeric:ordinal;font-variant-position:super;font-variation-settings:'wght' 700;font:small-caps 12px serif");
    defer block.deinit();
    for (reset_names) |name| {
        const longhand = (css.properties.lookup(name) orelse return error.FontResetNotImplemented).longhand;
        const actual = block.get(longhand) orelse return error.MissingReset;
        var got: std.ArrayList(u8) = .empty;
        defer got.deinit(testing.allocator);
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(testing.allocator);
        try css.properties.serializeAssigned(longhand, actual.value, &got, testing.allocator);
        try css.properties.serializeValue(longhand, longhand.info().initial, &expected, testing.allocator);
        try testing.expectEqualStrings(expected.items, got.items);
    }
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("font-variant-caps", &out);
    try testing.expectEqualStrings("small-caps", out.items);
}

fn aggregateOwnership(allocator: std.mem.Allocator) !void {
    _ = css.properties.lookup("font") orelse return error.FontNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font:oblique calc(10deg + 4deg) small-caps 450 condensed 20px/1.2 'Kept Family',serif;font-feature-settings:'smcp' on,'dlig' 0,'smcp' 2;font-variant-alternates:styleset(one,two) swash(three);font-variation-settings:'wght' calc(450 + 100),'wdth' 70");
    var owned = true;
    defer if (owned) block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    var parent_owned = true;
    defer if (parent_owned) parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    block.deinit();
    owned = false;
    parent.destroy();
    parent_owned = false;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(css.properties.lookup("font-feature-settings").?.longhand, &out, allocator);
    try testing.expectEqualStrings("\"dlig\" 0, \"smcp\" 2", out.items);
}

test "owned font aggregates outlive their source and parent at every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, aggregateOwnership, .{});
}
