//! CSS Anchor Position 1 §§3.2 and 5.1: typed anchor functions in numeric values.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(property: []const u8, text: []const u8, expected: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, property, text, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(property, &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "anchor functions normalize names sides percentages and fallbacks" {
    try check("top", "anchor(-- top)", "anchor(-- top)");
    try check("top", "anchor(left --foo)", "anchor(--foo left)");
    try check("left", "anchor(--MiXeD TOP, 0)", "anchor(--MiXeD top, 0px)");
    try check("top", "anchor(--foo calc(25% + 25%), min(1px, 2px))", "anchor(--foo calc(50%), calc(1px))");
    try check("top", "anchor(min(20%, 10%) --foo)", "anchor(--foo calc(10%))");
    try check("inset", "anchor(--foo left, anchor-size(--bar height, 20%))", "anchor(--foo left, anchor-size(--bar height, 20%))");
    try check("top", "anchor(--foo top, calc((anchor(--bar left) + anchor(--baz right)) / 2))", "anchor(--foo top, calc(0.5 * (anchor(--bar left) + anchor(--baz right))))");
    try check("top", "calc(anchor(--foo left, 0))", "anchor(--foo left, 0px)");
    try check("top", "calc(10% + 2 * anchor(--foo top))", "calc(10% + (2 * anchor(--foo top)))");
}

test "anchor size accepts omitted name or axis and normalizes fallback-only syntax" {
    try check("width", "anchor-size()", "anchor-size()");
    try check("width", "anchor-size(--foo)", "anchor-size(--foo)");
    try check("width", "anchor-size(height --foo)", "anchor-size(--foo height)");
    try check("width", "anchor-size(10px)", "anchor-size(10px)");
    try check("width", "anchor-size(--foo, 10px)", "anchor-size(--foo, 10px)");
    try check("margin", "anchor-size(--foo block, 10%)", "anchor-size(--foo block, 10%)");
    try check("height", "calc(anchor-size(--foo width) + 10%)", "calc(10% + anchor-size(--foo width))");
}

test "anchor restrictions and dimensional errors apply throughout nested expressions" {
    for ([_][]const u8{ "font-size", "width", "margin-top", "padding-top" }) |property| try check(property, "anchor(--foo top)", "");
    for ([_][]const u8{ "font-size", "padding-top", "border-top-width" }) |property| try check(property, "anchor-size(--foo width)", "");
    for ([_][]const u8{
        "anchor()",                    "anchor(--foo)",          "anchor(--foo, top)", "anchor(top left)",
        "anchor(foo top)",             "anchor(2 * 20%)",        "anchor((2 * 20%))",  "anchor(calc(1px))",
        "anchor(top, 1)",              "anchor(top, auto)",      "anchor(top,)",       "anchor(top, 1px 2px)",
        "anchor(top, calc(1px + 1s))", "anchor(calc(1% + 1px))",
    }) |invalid| try check("top", invalid, "");
    for ([_][]const u8{
        "anchor-size(--foo, width)",   "anchor-size(--foo width height)",       "anchor-size(--foo 10px)",
        "anchor-size(--foo width,)",   "anchor-size(, 10px)",                   "anchor-size(foo width)",
        "anchor-size(--foo width, 1)", "anchor-size(--foo width, anchor(top))", "calc(anchor-size(--foo width) + anchor(top))",
    }) |invalid| try check("width", invalid, "");
}

test "anchor expression owns decoded names and all nested allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "inset:anchor(--f\\6f o top, calc(10% + anchor-size(--bar block)));width:calc(2 * anchor-size(--baz width, 1em));");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("top", &out);
    try testing.expectEqualStrings("anchor(--foo top, calc(10% + anchor-size(--bar block)))", out.items);
}
