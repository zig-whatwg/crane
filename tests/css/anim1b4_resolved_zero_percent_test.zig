//! Lane anim1 batch 4: CSSOM 9 "resolved value" - for width, height and the
//! other used-value properties of a rendered element it is the used value,
//! and a computed calc() whose percentage coefficient is 0 has the used
//! value of its length part against ANY containing block (CSS Values 4
//! 10.10). So `calc(0% + 10px)` - the computed value an interpolation from
//! 10px to 100% has at p = 0 - resolves to 10px without layout (WPT
//! css/css-sizing/animation/width-interpolation.html). The computed value is
//! unchanged, and display: none keeps it.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;

fn resolved(allocator: Allocator, name: []const u8, text: []const u8, display_none: bool, expected: []const u8) !void {
    var block = Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, text, ""));
    if (display_none) try testing.expect(try block.setProperty(.{ .allocator = allocator }, "display", "none", ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const l = css.properties.lookup(name).?.longhand;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

fn cases(allocator: Allocator) !void {
    try resolved(allocator, "width", "calc(0% + 10px)", false, "10px");
    try resolved(allocator, "height", "calc(0% - 5px + 20px)", false, "15px");
    try resolved(allocator, "margin-left", "calc(0% + 10px)", false, "10px");
    try resolved(allocator, "padding-top", "calc(0% + 4px)", false, "4px");
    // The used value needs a box: display: none keeps the computed value.
    try resolved(allocator, "width", "calc(0% + 10px)", true, "calc(0% + 10px)");
    // A non-zero percentage needs the containing block: computed.
    try resolved(allocator, "width", "calc(10% + 10px)", false, "calc(10% + 10px)");
    // Not a used-value property: the computed value.
    try resolved(allocator, "min-width", "calc(0% + 10px)", false, "calc(0% + 10px)");
}

test "anim1b4: a zero-percentage calc() resolves to its length for used-value properties" {
    try cases(testing.allocator);
}

test "anim1b4: resolving zero percentages under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, cases, .{});
}
