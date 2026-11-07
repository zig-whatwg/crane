//! Lane anim1 batch 4 (C4, cause 2): basic shapes and path() data combine
//! for offset-path, clip-path, shape-outside and object-view-box (CSS Shapes
//! 1 3.4 "Interpolation of Basic Shapes"; SVG 2 9.3 the d property; CSS
//! Shapes 1 3.1.1.2): the same reference box and shape type, then each value;
//! path() data of the same structure compared in absolute form, numbers as
//! reals, arc flags as fractions (non-zero is one) inside (0, 1) and the
//! nearer endpoint's outside it; everything else is discrete.
//!
//! Expected values are the WPT expectations, which Chrome, Firefox and
//! Safari pass: css/motion/animation/offset-path-interpolation-001..006.html,
//! css/css-masking/animations/clip-path-interpolation-*.html.
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
    // path(): absolute, parameter by parameter.
    .{ Op.interpolate, "offset-path", "path('M 20 70')", "path('M 100 30')", 0.125, "path(\"M 30 65\")" },
    .{ Op.interpolate, "offset-path", "path('m 20 70')", "path('m 100 30')", -1, "path(\"M -60 110\")" },
    .{ Op.interpolate, "offset-path", "path('m 100 200 l 20 70')", "path('m 100 200 l 100 30')", -1, "path(\"M 100 200 L 40 310\")" },
    // Interpolated path data is absolute at p = 1 too.
    .{ Op.interpolate, "offset-path", "path('m 20 70')", "path('m 100 30')", 1, "path(\"M 100 30\")" },
    .{ Op.interpolate, "offset-path", "path('M 50 60 H 70')", "path('M 10 140 H 270')", -1, "path(\"M 90 -20 H -130\")" },
    .{ Op.interpolate, "offset-path", "path('M 100 400 A 10 20 30 1 0 140 450')", "path('M 300 200 A 50 60 70 0 1 380 290')", 0.125, "path(\"M 125 375 A 15 25 35 1 1 170 430\")" },
    .{ Op.interpolate, "offset-path", "path('M 100 400 A 10 20 30 1 0 140 450')", "path('M 300 200 A 50 60 70 0 1 380 290')", 2, "path(\"M 500 0 A 90 100 110 0 1 620 130\")" },
    // A different structure is discrete.
    .{ Op.interpolate, "offset-path", "path('M 0 0 H 1 H 2')", "path('M 0 0 H 3')", 0.4, "path(\"M 0 0 H 1 H 2\")" },
    .{ Op.interpolate, "offset-path", "path('M 10 0 H 11')", "path('M 20 0 V 2')", 0.6, "path(\"M 20 0 V 2\")" },
    // circle()/ellipse(): radii and position.
    .{ Op.interpolate, "offset-path", "circle(10px)", "circle(30px)", 0.25, "circle(15px)" },
    .{ Op.interpolate, "offset-path", "ellipse(10% 10% at 50% 50%)", "ellipse(40% 50% at 25% 25%)", 0.3, "ellipse(19% 22% at 42.5% 42.5%)" },
    .{ Op.interpolate, "offset-path", "circle(closest-side at 0% 0%)", "circle(10px at 0% 0%)", 0.4, "circle(at 0% 0%)" },
    // inset() (rect() and xywh() compute to it) and its radii.
    .{ Op.interpolate, "offset-path", "inset(10px)", "inset(20px round 50%)", 0.125, "inset(11.25px round 6.25%)" },
    .{ Op.interpolate, "offset-path", "xywh(5px 5px 150% 150%)", "xywh(10px 10px 100% 100%)", -1, "inset(0px -100% -100% 0px)" },
    .{ Op.interpolate, "offset-path", "rect(auto auto auto auto)", "rect(80% 20% 20% 80%)", -1, "inset(-80%)" },
    // polygon(): the same vertex count and fill-rule.
    .{ Op.interpolate, "clip-path", "polygon(0px 0px, 10px 10px)", "polygon(10px 10px, 20px 20px)", 0.5, "polygon(5px 5px, 15px 15px)" },
    .{ Op.interpolate, "clip-path", "polygon(0px 0px, 10px 10px)", "polygon(10px 10px, 20px 20px, 30px 30px)", 0.4, "polygon(0px 0px, 10px 10px)" },
    // The same reference box only.
    .{ Op.interpolate, "clip-path", "circle(10px) content-box", "circle(30px) content-box", 0.5, "circle(20px) content-box" },
    .{ Op.interpolate, "clip-path", "circle(10px) content-box", "circle(30px)", 0.4, "circle(10px) content-box" },
    .{ Op.interpolate, "offset-path", "circle(10px) view-box", "circle(30px) view-box", -0.1, "circle(8px) view-box" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "anim1b4: basic shapes and path() data combine by computed value" {
    try allCases(testing.allocator);
}

test "anim1b4: combining shapes under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
