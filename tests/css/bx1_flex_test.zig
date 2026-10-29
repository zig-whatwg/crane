//! CSS Flexbox 1/2 §§5–6.1 and CSS Display 4 §3.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn read(style: *const css.computed_style.ComputedStyle, name: []const u8, out: *std.ArrayList(u8), allocator: Allocator) !void {
    const property = css.properties.lookup(name) orelse return error.MissingFlexProperty;
    if (property == .longhand) return style.serializeResolved(property.longhand, out, allocator);
    var assignments: [css.properties.max_assignments]css.properties.Assigned = undefined;
    const longhands = property.shorthand.longhands();
    for (longhands, 0..) |longhand, i| assignments[i] = .{ .value = style.get(longhand) };
    try testing.expect(try css.properties.serializeShorthand(property.shorthand, assignments[0..longhands.len], .computed, out, allocator));
}

fn check(allocator: Allocator, name: []const u8, input: []const u8, expected: []const u8, resolved: bool) !void {
    _ = css.properties.lookup(name) orelse return error.MissingFlexProperty;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const accepted = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    if (expected.len > 0) try testing.expect(accepted);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (resolved) {
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try read(style, name, &out, allocator);
    } else try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "flex direction and wrapping are recognized with their own complete grammars" {
    inline for (.{ "row", "row-reverse", "column", "column-reverse" }) |input|
        try check(testing.allocator, "flex-direction", input, input, true);
    inline for (.{
        .{ "nowrap", "nowrap" },                             .{ "wrap", "wrap" },                                 .{ "wrap-reverse", "wrap-reverse" },
        .{ "balance", "balance" },                           .{ "wrap balance", "balance" },                      .{ "balance wrap", "balance" },
        .{ "wrap-reverse balance", "wrap-reverse balance" }, .{ "balance wrap-reverse", "wrap-reverse balance" },
    }) |case| {
        try check(testing.allocator, "flex-wrap", case[0], case[1], false);
        try check(testing.allocator, "flex-wrap", case[0], case[1], true);
    }
}

test "flex wrapping rejects duplicate and incompatible choices" {
    inline for (.{ "auto", "nowrap wrap", "wrap wrap", "balance balance", "balance nowrap", "nowrap balance", "wrap balance wrap", "balance wrap balance", "wrap 2 balance", "2 balance wrap", "balance 0", "balance 1.5", "balance -1" }) |input|
        try check(testing.allocator, "flex-wrap", input, "", false);
    inline for (.{ "row column", "horizontal", "column wrap" }) |input|
        try check(testing.allocator, "flex-direction", input, "", false);
}

test "flex flow expands both longhands and reconstructs the canonical shorthand" {
    inline for (.{
        .{ "column nowrap", "column" },                      .{ "nowrap column", "column" },
        .{ "wrap row-reverse", "row-reverse wrap" },         .{ "nowrap", "row" },
        .{ "row nowrap", "row" },                            .{ "wrap", "wrap" },
        .{ "row wrap", "wrap" },                             .{ "balance wrap-reverse column", "column wrap-reverse balance" },
        .{ "column balance wrap", "column balance" },        .{ "row balance", "balance" },
        .{ "wrap-reverse balance", "wrap-reverse balance" },
    }) |case| {
        try check(testing.allocator, "flex-flow", case[0], case[1], false);
        // 1026n: Firefox + Safari omit initial components in computed
        // shorthand readback too; the same shortest rule covers balance.
        try check(testing.allocator, "flex-flow", case[0], case[1], true);
    }
    inline for (.{ "nowrap row nowrap", "column wrap column", "row column", "wrap nowrap", "balance nowrap", "wrap column balance", "balance column wrap", "wrap-reverse column balance" }) |input|
        try check(testing.allocator, "flex-flow", input, "", false);
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "flex-flow", "wrap column", "important"));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("flex-direction", &out);
    try testing.expectEqualStrings("column", out.items);
    out.clearRetainingCapacity();
    try block.getPropertyValue("flex-wrap", &out);
    try testing.expectEqualStrings("wrap", out.items);
    try testing.expectEqual(@as(usize, 2), block.entries.items.len);
}

test "flex line count computes integer functions and clamps after calculation" {
    inline for (.{
        .{ "1", "1" },         .{ "2", "2" },         .{ "round(up, calc(7/2))", "4" },
        .{ "calc(NaN)", "1" }, .{ "calc(-10)", "1" }, .{ "calc(2.5)", "3" },
    }) |case| try check(testing.allocator, "flex-line-count", case[0], case[1], true);
    inline for (.{ "0", "-1", "1.5", "none", "auto", "1 2", "2px", "20%" }) |input|
        try check(testing.allocator, "flex-line-count", input, "", false);
}

test "order accepts signed integers and typed calculations" {
    inline for (.{ .{ "-3", "-3" }, .{ "+2", "2" }, .{ "calc(7 / 2)", "4" }, .{ "calc(-1.5)", "-1" }, .{ "calc(NaN)", "0" } }) |case|
        try check(testing.allocator, "order", case[0], case[1], true);
    inline for (.{ "auto", "1.5", "2px", "2%", "1 2" }) |input|
        try check(testing.allocator, "order", input, "", false);
}

test "flex integer literals clamp to representation limits without becoming invalid" {
    try check(testing.allocator, "order", "999999999999999999999999", "2147483647", false);
    try check(testing.allocator, "order", "-999999999999999999999999", "-2147483648", true);
    try check(testing.allocator, "flex-line-count", "999999999999999999999999", "2147483647", false);
    try check(testing.allocator, "flex-line-count", "calc(999999999999999999999999)", "2147483647", true);
}

test "flex properties initialize independently and inherit only when requested" {
    var parent_block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer parent_block.deinit();
    const cases = .{
        .{ "flex-direction", "column-reverse", "row" },
        .{ "flex-wrap", "wrap-reverse balance", "nowrap" },
        .{ "flex-line-count", "3", "1" },
        .{ "order", "-4", "0" },
    };
    inline for (cases) |case| try testing.expect(try parent_block.setProperty(.{ .allocator = testing.allocator }, case[0], case[1], ""));
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    var child_block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer child_block.deinit();
    inline for (cases) |case| try testing.expect(try child_block.setProperty(.{ .allocator = testing.allocator }, case[0], "inherit", ""));
    const inherited = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer inherited.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    inline for (cases) |case| {
        out.clearRetainingCapacity();
        try read(child, case[0], &out, testing.allocator);
        try testing.expectEqualStrings(case[2], out.items);
        out.clearRetainingCapacity();
        try read(inherited, case[0], &out, testing.allocator);
        try testing.expectEqualStrings(case[1], out.items);
    }
}

test "flex aliases identify the same declaration and computed property" {
    inline for (.{ "flex", "flex-basis", "flex-direction", "flex-flow", "flex-grow", "flex-shrink", "flex-wrap", "order", "align-content", "align-items", "align-self", "justify-content" }) |name| {
        const standard = css.properties.lookup(name) orelse return error.MissingFlexProperty;
        try testing.expectEqual(standard, css.properties.lookup("-webkit-" ++ name) orelse return error.MissingFlexAlias);
    }
    try check(testing.allocator, "-webkit-flex-flow", "wrap column", "column wrap", false);
    try check(testing.allocator, "-webkit-order", "calc(2 + 3)", "5", true);
}

test "flex flow and integer computations release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: Allocator) !void {
    try check(allocator, "flex-flow", "balance wrap-reverse column", "column wrap-reverse balance", false);
    try check(allocator, "flex-line-count", "round(up, calc(7 / 2))", "4", true);
    try check(allocator, "order", "calc(-1.5)", "-1", true);
}
