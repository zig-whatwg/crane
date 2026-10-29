//! Q30/Q32/Q40: pseudo allowlist, unavailable geometry and shared serializers.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;

fn pseudo(allocator: h.Allocator, name: []const u8, floated: bool) !void {
    var block = try h.Block.parse(.{ .allocator = allocator }, "shape-outside:circle(7px);shape-margin:7px;shape-image-threshold:0.5");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "float", if (floated) "left" else "none", "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .pseudo = name }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const applied = std.mem.eql(u8, name, "first-letter");
    try h.expect(style, "shape-outside", if (applied) "circle(7px)" else "none", allocator);
    try h.expect(style, "shape-margin", if (applied) "7px" else "0px", allocator);
    try h.expect(style, "shape-image-threshold", if (applied) "0.5" else "0", allocator);
}

test "first letter applies all shape longhands independently of floating" {
    try pseudo(testing.allocator, "first-letter", false);
    try pseudo(testing.allocator, "first-letter", true);
}

test "first line continues to filter all shape longhands" {
    try pseudo(testing.allocator, "first-line", false);
    try pseudo(testing.allocator, "first-line", true);
}

const paths = .{
    .{ "M10,10h80v80h-80z", "M 10 10 H 90 V 90 H 10 Z" },
    .{ "m10 20 5 6 h7 v8 z l1 2", "M 10 20 L 15 26 H 22 V 34 Z L 11 22" },
    .{ "m1 2 l3 4 z m5 6 l7 8", "M 1 2 L 4 6 Z M 6 8 L 13 16" },
    .{ "M10 20 c1 2 3 4 5 6 s7 8 9 10 q11 12 13 14 t15 16 a17 18 19 0 1 20 21", "M 10 20 C 11 22 13 24 15 26 S 22 34 24 36 Q 35 48 37 50 T 52 66 A 17 18 19 0 1 72 87" },
    .{ "M1 2L3 4H5V6C7 8 9 10 11 12S13 14 15 16Q17 18 19 20T21 22A23 24 25 1 0 26 27Z", "M 1 2 L 3 4 H 5 V 6 C 7 8 9 10 11 12 S 13 14 15 16 Q 17 18 19 20 T 21 22 A 23 24 25 1 0 26 27 Z" },
};

test "resolved shape paths make every relative command absolute" {
    inline for (paths) |case|
        try h.check(testing.allocator, "shape-outside", "path('" ++ case[0] ++ "')", "path(\"" ++ case[1] ++ "\")", true);
    try h.check(testing.allocator, "shape-outside", "path(evenodd, 'm1 2 h3 z') border-box", "path(evenodd, \"M 1 2 H 4 Z\") border-box", true);
}

test "specified shape paths and computed clip paths retain relative commands" {
    const input = "path('M10,10h80v80h-80z')";
    const expected = "path(\"M 10 10 h 80 v 80 h -80 Z\")";
    try h.check(testing.allocator, "shape-outside", input, expected, false);
    try h.check(testing.allocator, "clip-path", input, expected, false);
    try h.check(testing.allocator, "clip-path", input, expected, true);
}

// Q50 keeps the shared scanner unchanged. Absolute serialization must not
// emit an infinite coordinate when individually finite inputs overflow.
fn largePath(allocator: h.Allocator, input: []const u8, expected_path: []const u8) !void {
    var block = h.Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "shape-outside", input, ""));
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "clip-path", input, ""));
    var expected = h.Block.init(allocator);
    defer expected.deinit();
    try testing.expect(try expected.setProperty(.{ .allocator = allocator }, "shape-outside", expected_path, ""));
    var shape_text: std.ArrayList(u8) = .empty;
    defer shape_text.deinit(allocator);
    try expected.getPropertyValue("shape-outside", &shape_text);
    var clip_text: std.ArrayList(u8) = .empty;
    defer clip_text.deinit(allocator);
    try block.getPropertyValue("clip-path", &clip_text);
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "shape-outside", shape_text.items, allocator);
    try h.expect(style, "clip-path", clip_text.items, allocator);
}

test "large finite path sums convert and overflowing sums preserve relative text" {
    try largePath(testing.allocator, "path('M 8e307 0 l 8e307 0')", "path('M 8e307 0 L 1.6e308 0')");
    try largePath(testing.allocator, "path('M 1e308 0 l 1e308 0')", "path('M 1e308 0 l 1e308 0')");
    // Overflow after converted segments must restore the ENTIRE relative
    // value, not keep an already-converted prefix from the temporary buffer.
    const late = "path('m1 2 l3 4 M1e308 0 l1e308 0')";
    try largePath(testing.allocator, late, late);
    // A control point can overflow while the curve endpoint stays finite.
    const control = "path('M1e308 0 c1e308 0 -1e308 0 0 1')";
    try largePath(testing.allocator, control, control);
}

const gradients = .{
    .{ "linear-gradient(red 0% 20%, blue)", "linear-gradient(red 0%, red 20%, blue)", "linear-gradient(rgb(255, 0, 0) 0%, rgb(255, 0, 0) 20%, rgb(0, 0, 255))" },
    .{ "conic-gradient(red 0deg 90deg, blue)", "conic-gradient(red 0deg, red 90deg, blue)", "conic-gradient(rgb(255, 0, 0) 0deg, rgb(255, 0, 0) 90deg, rgb(0, 0, 255))" },
    .{ "radial-gradient(black 0% 0.5em, 25%, white)", "radial-gradient(black 0%, black 0.5em, 25%, white)", "radial-gradient(rgb(0, 0, 0) 0%, rgb(0, 0, 0) 8px, 25%, rgb(255, 255, 255))" },
    .{ "repeating-linear-gradient(red 0px 1em, blue 2em)", "repeating-linear-gradient(red 0px, red 1em, blue 2em)", "repeating-linear-gradient(rgb(255, 0, 0) 0px, rgb(255, 0, 0) 16px, rgb(0, 0, 255) 32px)" },
    .{ "linear-gradient(currentcolor 0% 20%, blue)", "linear-gradient(currentcolor 0%, currentcolor 20%, blue)", "linear-gradient(rgb(0, 0, 0) 0%, rgb(0, 0, 0) 20%, rgb(0, 0, 255))" },
};

test "every image consumer expands two position stops in specified and computed text" {
    inline for (.{ "shape-outside", "background-image", "list-style-image" }) |name| {
        inline for (gradients) |case| {
            try h.check(testing.allocator, name, case[0], case[1], false);
            try h.check(testing.allocator, name, case[0], case[2], true);
        }
    }
}

test "shape geometry preserves unavailable cap lengths while scalar threshold falls back" {
    try metrics.check(testing.allocator, "shape-outside", "circle(9px)", "circle(1cap)", null);
    try metrics.check(testing.allocator, "shape-outside", "circle(9px)", "inset(calc(1cap + 2px))", null);
    try metrics.check(testing.allocator, "shape-image-threshold", "0.25", "calc(sign(1cap - 1px))", "0.25");
}

test "shape pseudo and shared serializer paths release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    try pseudo(allocator, "first-letter", false);
    try h.check(allocator, "shape-outside", "path(evenodd, 'm1 2 h3 z') border-box", "path(evenodd, \"M 1 2 H 4 Z\") border-box", true);
    try h.check(allocator, "background-image", gradients[0][0], gradients[0][2], true);
    try metrics.check(allocator, "shape-outside", "circle(9px)", "circle(1cap)", null);
    try largePath(allocator, "path('M 8e307 0 l 8e307 0')", "path('M 8e307 0 L 1.6e308 0')");
    try largePath(allocator, "path('M 1e308 0 l 1e308 0')", "path('M 1e308 0 l 1e308 0')");
    const late = "path('m1 2 l3 4 M1e308 0 l1e308 0')";
    try largePath(allocator, late, late);
}
