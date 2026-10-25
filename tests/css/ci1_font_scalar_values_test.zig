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

test "font style validates literal angles and computes clamped typed calculations" {
    try expectValue("font-style", "oblique", "oblique", false);
    try expectValue("font-style", "oblique 0deg", "normal", false);
    try expectValue("font-style", "oblique 14deg", "oblique 14deg", false);
    try expectValue("font-style", "oblique 10grad", "oblique 10grad", false);
    try expectValue("font-style", "oblique 10grad", "oblique 9deg", true);
    try expectValue("font-style", "oblique calc(10deg - 10deg)", "oblique calc(0deg)", false);
    try expectValue("font-style", "oblique calc(10deg - 10deg)", "normal", true);
    try expectValue("font-style", "oblique calc(100deg)", "oblique 90deg", true);
    try expectValue("font-style", "oblique calc(-100deg)", "oblique -90deg", true);
    for ([_][]const u8{ "left", "right", "oblique 0", "oblique 91deg", "oblique -91deg", "italic 14deg", "oblique 10%" }) |bad| try expectValue("font-style", bad, null, false);
}

test "font width and its stretch alias share one property and compute percentages" {
    const width = css.properties.lookup("font-width") orelse return error.FontWidthNotImplemented;
    try testing.expectEqual(width, css.properties.lookup("font-stretch").?);
    const words = [_][]const u8{ "ultra-condensed", "extra-condensed", "condensed", "semi-condensed", "normal", "semi-expanded", "expanded", "extra-expanded", "ultra-expanded" };
    const percentages = [_][]const u8{ "50%", "62.5%", "75%", "87.5%", "100%", "112.5%", "125%", "150%", "200%" };
    for (words, percentages) |word, percentage| {
        try expectValue("font-width", word, word, false);
        try expectValue("font-stretch", word, percentage, true);
    }
    try expectValue("font-width", "calc(-100%)", "0%", true);
    try expectValue("font-width", "234.5%", "234.5%", true);
    for ([_][]const u8{ "-1%", "100", "1px", "normal condensed" }) |bad| try expectValue("font-width", bad, null, false);
}

test "font setting tags preserve specified order and compute a last-wins sorted map" {
    try expectValue("font-feature-settings", "'smcp' on, 'dlig' 0, 'smcp' off", "\"smcp\", \"dlig\" 0, \"smcp\" 0", false);
    try expectValue("font-feature-settings", "'smcp' on, 'dlig' 0, 'smcp' off", "\"dlig\" 0, \"smcp\" 0", true);
    try expectValue("font-feature-settings", "'liga' calc(2 + 3)", "\"liga\" 5", true);
    try expectValue("font-variation-settings", "'wght' 100, 'wdth' 200, 'wght' 300", "\"wght\" 100, \"wdth\" 200, \"wght\" 300", false);
    try expectValue("font-variation-settings", "'wght' 100, 'wdth' 200, 'wght' 300", "\"wdth\" 200, \"wght\" 300", true);
    try expectValue("font-variation-settings", "'slnt' -4.5, 'XHGT' calc(0.4 + 0.3)", "\"XHGT\" 0.7, \"slnt\" -4.5", true);
    for ([_][]const u8{ "''", "'abc'", "'abcde'", "'aøcd'", "'liga' -1", "'liga' 1.5", "'liga' on off", "'liga'," }) |bad| try expectValue("font-feature-settings", bad, null, false);
    for ([_][]const u8{ "'wght'", "'wght' 1%", "'wght' on", "'abc' 1", "'wght' 1,", "normal, 'wght' 1" }) |bad| try expectValue("font-variation-settings", bad, null, false);
}

test "font language override follows the Chrome Firefox tag grammar and serialization" {
    for ([_][]const u8{ "'APPH'", "'ksw'", "'tr'", "'1 %'" }, [_][]const u8{ "\"APPH\"", "\"ksw\"", "\"tr\"", "\"1 %\"" }) |input, expected| try expectValue("font-language-override", input, expected, false);
    try expectValue("font-language-override", "'ENG '", "\"ENG\"", false);
    try expectValue("font-language-override", "' en '", "\" en\"", true);
    for ([_][]const u8{ "''", "'turkish'", "'xøx'", "'ENG  '", "normal 'ENG'", "auto" }) |bad| try expectValue("font-language-override", bad, null, false);
}

// Fonts4 §1.2 / Values4 §6.1.1: font-affecting properties use the
// parent's font-relative metrics. The default case is the child's.
test "font calculations use parent metrics and ordinary width uses child metrics" {
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:20px");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:40px;font-width:calc(1em / 1px * 1%);font-style:oblique calc(1em / 1px * 1deg);font-feature-settings:'liga' calc(1em / 1px);font-variation-settings:'wght' calc(1em / 1px);width:calc(1em)");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    const cases = .{
        .{ "font-width", "20%" },
        .{ "font-style", "oblique 20deg" },
        .{ "font-feature-settings", "\"liga\" 20" },
        .{ "font-variation-settings", "\"wght\" 20" },
        .{ "width", "40px" },
    };
    inline for (cases) |case| {
        const l = (css.properties.lookup(case[0]) orelse return error.FontPropertyNotImplemented).longhand;
        try testing.expect(child_block.get(l) != null);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try child.serializeResolved(l, &out, testing.allocator);
        try testing.expectEqualStrings(case[1], out.items);
    }
}
