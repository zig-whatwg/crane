//! CSS Will Change 1 section 2: values and computed serialization.
const std = @import("std");
const css = @import("css");

fn check(a: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup("will-change") orelse return error.MissingWillChange;
    var block = css.declarations.DeclarationBlock.init(a);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = a }, "will-change", input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try block.getPropertyValue("will-change", &out);
    try std.testing.expectEqualStrings(expected, out.items);
    if (expected.len == 0) return;
    const style = try css.cascade.cascade(.{ .allocator = a, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    out.clearRetainingCapacity();
    try style.serializeResolved(property.longhand, &out, a);
    try std.testing.expectEqualStrings(expected, out.items);
    const child = try css.cascade.cascade(.{ .allocator = a, .parent = style }, &.{});
    defer child.destroy();
    out.clearRetainingCapacity();
    try child.serializeResolved(property.longhand, &out, a);
    try std.testing.expectEqualStrings("auto", out.items);
}

fn valid(a: std.mem.Allocator) !void {
    try check(a, "AUTO", "auto");
    try check(a, "SCROLL-POSITION, CONTENTS", "scroll-position, contents");
    try check(a, "TRANSFORM,transform,Not-A-Property,--var,TRANSFORM", "TRANSFORM, transform, Not-A-Property, --var, TRANSFORM");
    try check(a, "\\74 ransform,foo\\ bar", "transform, foo\\ bar");
}

test "will-change preserves custom-ident case and duplicates and does not inherit" {
    try valid(std.testing.allocator);
}

test "will-change rejects reserved words and malformed lists" {
    for ([_][]const u8{ "", "auto, transform", "contents auto", "transform,", ",transform", "transform contents", "42", "will-change", "none", "all", "transform, initial", "transform, inherit", "transform, unset", "transform, revert", "transform, revert-layer", "transform, revert-rule", "transform, default", "WILL-CHANGE", "transform, \\61 ll" }) |input| {
        try check(std.testing.allocator, input, "");
    }
}

test "will-change parsing computation and serialization unwind all allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, valid, .{});
}
