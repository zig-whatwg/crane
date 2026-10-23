//! CSS Flexbox 1 §7: parsed/computed flexibility, without flex layout.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, expected: []const u8, resolved: bool) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (resolved) {
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        const property = css.properties.lookup(name) orelse return error.MissingFlexProperty;
        try style.serializeResolved(property.longhand, &out, allocator);
    } else try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "flex shorthand handles explicit bases and the none and auto forms" {
    inline for (.{
        .{ "none", "0 0 auto" },   .{ "auto", "1 1 auto" },
        .{ "6px 4 5", "4 5 6px" }, .{ "content", "1 1 content" },
        .{ "1 2 0", "1 2 0px" },   .{ "0 fit-content", "0 1 fit-content" },
    }) |c| try check(testing.allocator, "flex", c[0], c[1], false);
}

test "flex omitted basis follows unanimous browsers and stays distinct from explicit zero" {
    // Q79/D95: Flexbox 1 §7.1 says zero length after the 2015 reversal;
    // pinned WPTs and all three shipping browsers use 0% for an omitted basis.
    try check(testing.allocator, "flex", "1", "1 1 0%", false);
    try check(testing.allocator, "flex", "2 3", "2 3 0%", false);
    try check(testing.allocator, "flex", "1 2 0", "1 2 0px", false);
    try check(testing.allocator, "flex", "1 2 calc(0)", "", false);
}

test "flex basis computes relative units while retaining percentages and intrinsic keywords" {
    try check(testing.allocator, "flex-basis", "2em", "32px", true);
    try check(testing.allocator, "flex-basis", "20%", "20%", true);
    try check(testing.allocator, "flex-basis", "content", "content", true);
    try check(testing.allocator, "flex-basis", "fit-content(2em)", "fit-content(32px)", true);
}

test "flex component calculations clamp only at the computed boundary" {
    try check(testing.allocator, "flex-grow", "calc(-1)", "calc(-1)", false);
    try check(testing.allocator, "flex-grow", "calc(-1)", "0", true);
    try check(testing.allocator, "flex-shrink", "calc(2 + 1)", "3", true);
    try check(testing.allocator, "flex-basis", "calc(-2em)", "0px", true);
}

test "flex grammar rejects literal negative factors and number calculations as a basis" {
    inline for (.{
        .{ "flex-grow", "-1" },    .{ "flex-shrink", "-1" },
        .{ "flex-basis", "-1px" }, .{ "flex", "1 2 calc(0)" },
        .{ "flex", "2 3 4" },      .{ "flex", "none 1" },
    }) |c| try check(testing.allocator, c[0], c[1], "", false);
}

test "flex values release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    try check(allocator, "flex", "calc(1) calc(2 + 1) calc(3px)", "calc(1) calc(3) calc(3px)", false);
    try check(allocator, "flex-basis", "fit-content(calc(10% + 2em))", "fit-content(calc(10% + 32px))", true);
}

// Append to tests/css/cv1_flex_values_test.zig after restoring the feature tree.
test "flex basis rejects anchor functions even though width accepts anchor size" {
    inline for (.{
        "anchor-size(--a width)",
        "anchor-size(--a width, 10px)",
        "calc(anchor-size(--a width) + 1px)",
        "fit-content(anchor-size(--a width))",
    }) |input| {
        try check(testing.allocator, "flex-basis", input, "", false);
        try check(testing.allocator, "flex", "1 1 " ++ input, "", false);
    }
    try check(testing.allocator, "width", "anchor-size(--a width, 10px)", "anchor-size(--a width, 10px)", false);
}
