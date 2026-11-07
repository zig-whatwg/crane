//! Lane anim1 (C1): CSS Transitions 1 section 3 "transitionable" - a pair of
//! computed values whose animation type is neither not animatable nor
//! discrete (css.interpolation.transitionable). The style change event starts
//! a transition only for a transitionable pair (without transition-behavior:
//! allow-discrete).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;

/// Whether `from` and `to`, each the only declaration of `name` on an
/// element with no parent, compute to a transitionable pair.
fn transitionable(allocator: Allocator, name: []const u8, from: []const u8, to: []const u8) !bool {
    var a = Block.init(allocator);
    defer a.deinit();
    var b = Block.init(allocator);
    defer b.deinit();
    try testing.expect(try a.setProperty(.{ .allocator = allocator }, name, from, ""));
    try testing.expect(try b.setProperty(.{ .allocator = allocator }, name, to, ""));
    const style_a = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &a, .source = .{ .origin = .author, .order = 1 } },
    });
    defer style_a.destroy();
    const style_b = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &b, .source = .{ .origin = .author, .order = 1 } },
    });
    defer style_b.destroy();
    const longhand = switch (css.properties.lookup(name).?) {
        .longhand => |l| l,
        .shorthand => return error.NotALonghand,
    };
    return css.interpolation.transitionable(allocator, longhand, style_a.get(longhand), style_b.get(longhand));
}

test "numbers and lengths are transitionable" {
    try testing.expect(try transitionable(testing.allocator, "opacity", "1", "0"));
    try testing.expect(try transitionable(testing.allocator, "margin-left", "0px", "100px"));
    try testing.expect(try transitionable(testing.allocator, "margin-left", "10%", "100px"));
}

test "a discrete or not-animatable property is not transitionable" {
    // float: discrete. transition-duration: not animatable.
    try testing.expect(!try transitionable(testing.allocator, "float", "left", "right"));
    try testing.expect(!try transitionable(testing.allocator, "transition-duration", "1s", "2s"));
}

test "a pair with no smooth combination is not transitionable" {
    // The spec's own example: "[0px 0px black] and [inset 10px 10px black]
    // are not transitionable".
    try testing.expect(!try transitionable(testing.allocator, "box-shadow", "0px 0px black", "inset 10px 10px black"));
    try testing.expect(try transitionable(testing.allocator, "box-shadow", "0px 0px black", "10px 10px black"));
    // auto against a length.
    try testing.expect(!try transitionable(testing.allocator, "margin-left", "auto", "100px"));
}

test "visibility is transitionable only with visible on one side" {
    try testing.expect(try transitionable(testing.allocator, "visibility", "visible", "hidden"));
    try testing.expect(!try transitionable(testing.allocator, "visibility", "hidden", "collapse"));
}
