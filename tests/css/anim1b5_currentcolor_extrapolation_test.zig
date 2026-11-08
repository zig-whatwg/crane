//! Lane anim1 batch 5 (item 4): an interpolation with currentcolor
//! extrapolates. CSS Values 4 3: "The range of p is (−∞, ∞) ... this
//! procedure must also define extrapolation behavior for p outside [0, 1]";
//! the pair's computed value is a mix of the two that resolves against the
//! element's `color` when used (color_values.interpolateColors), and its
//! weights are the interpolation's (1 - p, p) - not a color-mix() whose
//! percentages stop at 0% and 100%.
//!
//! Expected values are WPT's, which Chrome 157, Firefox 159 and Safari 27.2
//! pass (wpt.fyi aligned stable run 8c04fb8d43):
//! css/css-backgrounds/animations/background-color-interpolation.html
//! (currentcolor rgba(0, 0, 255, 0.5) -> rgba(0, 255, 0, 0.75) at -0.5 and
//! 1.5), css/css-transitions/animations/text-shadow-interpolation.html and
//! css/css-backgrounds/animations/box-shadow-interpolation.html (black ->
//! currentColor green at 1.5 is rgb(0, 192, 0)). The harness rounds alpha to
//! two places (0.38, 0.88); the values here are exact.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const interpolation = css.interpolation;
const Value = css.style_values.Value;

fn computeWith(allocator: Allocator, color: []const u8, name: []const u8, text: []const u8) !*Style {
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, "color", color, "")) return error.Rejected;
    if (!try block.setProperty(.{ .allocator = allocator }, name, text, "")) return error.Rejected;
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

/// interpolate(from, to, p) of `name` on an element whose `color` is
/// `color`, as getComputedStyle reads it there.
fn check(allocator: Allocator, color: []const u8, name: []const u8, from: []const u8, to: []const u8, p: f64, expected: []const u8) !void {
    const l = (css.properties.lookup(name) orelse return error.Unknown).longhand;
    const a = try computeWith(allocator, color, name, from);
    defer a.destroy();
    const b = try computeWith(allocator, color, name, to);
    defer b.destroy();
    const result = interpolation.clampFinal(l, try interpolation.interpolate(allocator, l, a.get(l), b.get(l), p));
    var block = Block.init(allocator);
    defer block.deinit();
    block.entries.append(allocator, .{ .typed = .{ .longhand = l, .value = .{ .value = result }, .important = false } }) catch |err| {
        result.release();
        return err;
    };
    if (!try block.setProperty(.{ .allocator = allocator }, "color", color, "")) return error.Rejected;
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("case: {s} {s} -> {s} at {d}\n", .{ name, from, to, p });
        return err;
    };
}

fn cases(allocator: Allocator) !void {
    const blue = "rgba(0, 0, 255, 0.5)";
    try check(allocator, blue, "background-color", "currentcolor", "rgba(0, 255, 0, 0.75)", -0.5, "rgba(0, 0, 255, 0.375)");
    try check(allocator, blue, "background-color", "currentcolor", "rgba(0, 255, 0, 0.75)", 1.5, "rgba(0, 255, 0, 0.875)");
    // Inside [0, 1] nothing changes.
    try check(allocator, blue, "background-color", "currentcolor", "rgba(0, 255, 0, 0.75)", 0.5, "rgba(0, 153, 102, 0.625)");
    const green = "rgb(0, 128, 0)";
    try check(allocator, green, "box-shadow", "10px 10px 10px 10px black", "10px 10px 10px 10px currentcolor", 1.5, "rgb(0, 192, 0) 10px 10px 10px 10px");
    try check(allocator, green, "text-shadow", "black 10px 10px 10px", "currentcolor 10px 10px 10px", 1.5, "rgb(0, 192, 0) 10px 10px 10px");
}

test "anim1b5: an interpolation with currentcolor extrapolates outside [0, 1]" {
    try cases(testing.allocator);
}

test "anim1b5: currentcolor extrapolation under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, cases, .{});
}
