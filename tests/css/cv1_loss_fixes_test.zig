//! Row118 Q126/Q128: preserve existing CSSOM and HTML quirks passes.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, quirks: bool, specified: []const u8, computed: ?[]const u8) !void {
    const declaration = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ name, input });
    defer allocator.free(declaration);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, declaration);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |expected| {
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        out.clearRetainingCapacity();
        const property = css.properties.lookup(name) orelse return error.MissingProperty;
        try style.serializeResolved(property.longhand, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}

test "quirky letter spacing accepts a signed number token only in quirks mode" {
    // CSS Values 4 Appendix C: letter-spacing is in the unitless-length list.
    inline for (.{ .{ "1", "1px" }, .{ "+1", "1px" }, .{ "-1", "-1px" }, .{ "1.5", "1.5px" }, .{ "+1.5", "1.5px" }, .{ "-1.5", "-1.5px" } }) |pair| {
        try check(testing.allocator, "letter-spacing", pair[0], true, pair[1], pair[1]);
        try check(testing.allocator, "letter-spacing", pair[0], false, "", "normal");
    }
    // A delim followed by a number does not become a quirky length, and
    // the quirk never changes the grammar inside a math function.
    for ([_][]const u8{ "+/**/1", "-/**/1", "+ 1", "calc(1)", "calc(1 + 2)" }) |bad|
        try check(testing.allocator, "letter-spacing", bad, true, "", "normal");
    try check(testing.allocator, "letter-spacing", "0", true, "0px", "normal");
    try check(testing.allocator, "letter-spacing", "0", false, "0px", "normal");
}

test "a removed comment cannot turn a min or max size into a quirky signed number" {
    inline for (.{ "max-width", "max-height", "min-width", "min-height" }) |name| {
        const initial = if (name[1] == 'a') "none" else "auto";
        for ([_][]const u8{ "+/**/1", "+/**/1px", ". /**/1", "+ 1" }) |bad|
            try check(testing.allocator, name, bad, true, "", initial);
        try check(testing.allocator, name, "+1", true, "1px", "1px");
        try check(testing.allocator, name, "+1", false, "", initial);
    }
}

test "declaration serialization preserves separated CSS token meanings" {
    // CSS Syntax 3 section 9: exercise merging into identifiers, functions,
    // hashes, numbers, dimensions, comments, and percentages.
    inline for (.{
        .{ "foo/**/bar", "foo/**/bar" },
        .{ "foo/**/f()", "foo/**/f()" },
        .{ "foo/**/url(x)", "foo/**/url(\"x\")" },
        .{ "foo/**/-", "foo/**/-" },
        .{ "foo/**/1", "foo/**/1" },
        .{ "foo/**/1%", "foo/**/1%" },
        .{ "foo/**/1px", "foo/**/1px" },
        .{ "foo/**/-->", "foo/**/-->" },
        .{ "foo/**/()", "foo/**/()" },
        .{ "@foo/**/bar", "@foo/**/bar" },
        .{ "#foo/**/bar", "#foo/**/bar" },
        .{ "1px/**/bar", "1px/**/bar" },
        .{ "#/**/bar", "#/**/bar" },
        .{ "-/**/bar", "-/**/bar" },
        .{ "1/**/bar", "1/**/bar" },
        .{ "1/**/1", "1/**/1" },
        .{ "1/**/%", "1/**/%" },
        .{ "@/**/bar", "@/**/bar" },
        .{ "@/**/-", "@/**/-" },
        .{ ". /**/1", ". 1" },
        .{ "./**/1", "./**/1" },
        .{ "+/**/1", "+/**/1" },
        .{ "+/**/1%", "+/**/1%" },
        .{ "+/**/1px", "+/**/1px" },
        .{ "//**/*", "//**/*" },
        .{ "a  /**/ b", "a b" },
        .{ "f(1px)", "f(1px)" },
        .{ "1px,2px", "1px,2px" },
        .{ "[a](b)", "[a](b)" },
    }) |pair| {
        // An unsupported non-custom property: since lane vars1 a custom
        // property keeps its original text (CSS Syntax 3, css-variables-1
        // §4.1), so the rule parser's token serializer is exercised here.
        const input = try std.fmt.allocPrint(testing.allocator, "x-unknown:{s}", .{pair[0]});
        defer testing.allocator.free(input);
        const declarations = try css.rules.parseDeclarationList(testing.allocator, input);
        defer css.rules.freeDeclarationList(testing.allocator, declarations);
        try testing.expectEqual(@as(usize, 1), declarations.len);
        try testing.expectEqualStrings(pair[1], declarations[0].value);
        const again = try std.fmt.allocPrint(testing.allocator, "x-unknown:{s}", .{declarations[0].value});
        defer testing.allocator.free(again);
        const reparsed = try css.rules.parseDeclarationList(testing.allocator, again);
        defer css.rules.freeDeclarationList(testing.allocator, reparsed);
        try testing.expectEqual(@as(usize, 1), reparsed.len);
        try testing.expectEqualStrings(declarations[0].value, reparsed[0].value);
    }
}

test "prefixed orientation expresses the standard mixed initial value" {
    const allocator = testing.allocator;
    for ([_][]const u8{ "-webkit-text-orientation:vertical-right", "text-orientation:mixed" }) |declaration| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, declaration);
        defer block.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try block.getPropertyValue("text-orientation", &out);
        try testing.expectEqualStrings("mixed", out.items);
        out.clearRetainingCapacity();
        try block.getPropertyValue("-webkit-text-orientation", &out);
        try testing.expectEqualStrings("vertical-right", out.items);
    }
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const property = css.properties.lookup("-webkit-text-orientation") orelse return error.MissingAlias;
    const assigned = [_]css.properties.Assigned{.{ .value = style.get(.text_orientation) }};
    try testing.expect(try css.properties.serializeShorthand(property.shorthand, &assigned, .computed, &out, allocator));
    try testing.expectEqualStrings("vertical-right", out.items);
    var rejected = css.declarations.DeclarationBlock.init(allocator);
    defer rejected.deinit();
    try testing.expect(!try rejected.setProperty(.{ .allocator = allocator }, "-webkit-text-orientation", "mixed", ""));
    for ([_][]const u8{ "VERTICAL-RIGHT", "\\76 ertical-right" }) |keyword| {
        _ = try rejected.setProperty(.{ .allocator = allocator }, "-webkit-text-orientation", keyword, "");
        out.clearRetainingCapacity();
        try rejected.getPropertyValue("-webkit-text-orientation", &out);
        try testing.expectEqualStrings("vertical-right", out.items);
    }
    for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer" }) |keyword| {
        _ = try rejected.setProperty(.{ .allocator = allocator }, "-webkit-text-orientation", keyword, "");
        out.clearRetainingCapacity();
        try rejected.getPropertyValue("-webkit-text-orientation", &out);
        try testing.expectEqualStrings(keyword, out.items);
    }
}

test "outline invert stays rejected under the contradictory legacy test ruling" {
    try check(testing.allocator, "outline-color", "invert", false, "", null);
    try check(testing.allocator, "outline-color", "INVERT", false, "", null);
    for ([_][]const u8{ "color", "background-color", "border-top-color", "accent-color", "caret-color" }) |name|
        try check(testing.allocator, name, "invert", false, "", null);
    try check(testing.allocator, "outline-color", "invert red", false, "", null);
}

test "loss fix parsing and serialization releases allocations on every failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    try check(allocator, "min-width", "+/**/1", true, "", "auto");
    try check(allocator, "letter-spacing", "+1.5", true, "1.5px", "1.5px");
}
