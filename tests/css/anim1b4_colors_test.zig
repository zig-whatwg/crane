//! Lane anim1 batch 4 (C4, cause 5): colors that are not both legacy sRGB
//! colors combine too (CSS Color 4 section 12): a resolved pair in Oklab, and
//! a pair with currentcolor as the color-mix() of the two, which resolves
//! against the element's `color` when used (CSS Color 5 color-mix(); Blink
//! StyleColor::UnresolvedColorMix).
//!
//! Expected values are the WPT expectations, which Chrome, Firefox and
//! Safari pass: web-animations/responsive/to-color-change.html (the default
//! `color` here is canvastext, black).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const interpolation = css.interpolation;

const Op = enum { interpolate, add };

fn computeOne(allocator: Allocator, name: []const u8, text: []const u8) !*Style {
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, name, text, "")) return error.Rejected;
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn combined(allocator: Allocator, op: Op, name: []const u8, from: []const u8, to: []const u8, p: f64, expected: []const u8) !void {
    const l = (css.properties.lookup(name) orelse return error.Unknown).longhand;
    const a = try computeOne(allocator, name, from);
    defer a.destroy();
    const b = try computeOne(allocator, name, to);
    defer b.destroy();
    const raw = switch (op) {
        .interpolate => try interpolation.interpolate(allocator, l, a.get(l), b.get(l), p),
        .add => try interpolation.add(allocator, l, a.get(l), b.get(l)),
    };
    const result = interpolation.clampFinal(l, raw);
    var block = Block.init(allocator);
    defer block.deinit();
    block.entries.append(allocator, .{ .typed = .{ .longhand = l, .value = .{ .value = result }, .important = false } }) catch |err| {
        result.release();
        return err;
    };
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("case: {s} {s} {s} -> {s} at {d}\n", .{ @tagName(op), name, from, to, p });
        return err;
    };
}

const cases = .{
    .{ Op.interpolate, "background-color", "currentcolor", "rgb(0, 68, 0)", 0.5, "rgb(0, 34, 0)" },
    .{ Op.interpolate, "background-color", "rgb(0, 68, 0)", "currentcolor", 0.25, "rgb(0, 51, 0)" },
    // A shadow's currentcolor mixes the same way (Backgrounds 3 6.1).
    .{ Op.interpolate, "box-shadow", "currentcolor 10px 10px", "rgb(0, 0, 255) 20px 20px", 0.5, "rgb(0, 0, 128) 15px 15px 0px 0px" },
    .{ Op.interpolate, "text-shadow", "currentcolor 10px 10px", "rgb(0, 0, 255) 20px 20px", 0.5, "rgb(0, 0, 128) 15px 15px 0px" },
    // Legacy pairs keep premultiplied sRGB.
    .{ Op.interpolate, "background-color", "rgb(0, 0, 204)", "rgb(0, 68, 0)", 0.5, "rgb(0, 34, 102)" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "anim1b4: colors with currentcolor combine as a color-mix()" {
    try allCases(testing.allocator);
}

test "anim1b4: combining colors under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
