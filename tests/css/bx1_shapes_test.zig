//! Shapes 1 §§3,6: reuse basic shapes/images with shape-outside's margin box.
const std = @import("std");
const testing = std.testing;
const h = @import("bx1_helpers.zig");

test "clip path default box serialization is pinned before shape outside exposure" {
    inline for (.{
        .{ "circle() border-box", "circle()" },
        .{ "border-box circle()", "circle()" },
        .{ "circle() margin-box", "circle() margin-box" },
        .{ "inset(10px 20px) padding-box", "inset(10px 20px) padding-box" },
        .{ "border-box", "border-box" },
        .{ "fill-box", "fill-box" },
    }) |case| {
        try h.check(testing.allocator, "clip-path", case[0], case[1], false);
        try h.check(testing.allocator, "clip-path", case[0], case[1], true);
    }
}

test "shape outside shares basic shape grammar with a distinct default box" {
    inline for (.{
        .{ "circle() margin-box", "circle()" },
        .{ "margin-box circle()", "circle()" },
        .{ "border-box circle()", "circle() border-box" },
        .{ "circle() padding-box", "circle() padding-box" },
        .{ "circle() content-box", "circle() content-box" },
        .{ "margin-box", "margin-box" },
        .{ "content-box", "content-box" },
    }) |case| {
        try h.check(testing.allocator, "shape-outside", case[0], case[1], false);
        try h.check(testing.allocator, "shape-outside", case[0], case[1], true);
    }
    inline for (.{ "fill-box", "stroke-box", "view-box", "circle() fill-box", "circle() circle()", "margin-box border-box", "url(foo.png) margin-box", "margin-box circle(bogus", "margin-box polygon()" }) |input|
        try h.check(testing.allocator, "shape-outside", input, "", false);
}

test "shape outside computation preserves percentages without a layout box" {
    inline for (.{
        .{ "circle(calc(1em + 2px) at 25% 75%) border-box", "circle(18px at 25% 75%) border-box" },
        .{ "ellipse(calc(1px - 1em) 50% at top right)", "ellipse(0px 50% at 100% 0%)" },
        .{ "xywh(1em 2em 3em 4em)", "inset(32px calc(100% - 64px) calc(100% - 96px) 16px)" },
        .{ "polygon(evenodd round 1em, 0px 0%, 2em 3em)", "polygon(evenodd round 16px, 0px 0%, 32px 48px)" },
        .{ "shape(from 1em 2em, line to 3em 4em)", "shape(from 16px 32px, line to 48px 64px)" },
        // Q40: shape-outside resolves relative commands; clip-path stays pinned.
        .{ "path('M10,10h80v80h-80z')", "path(\"M 10 10 H 90 V 90 H 10 Z\")" },
    }) |case| try h.check(testing.allocator, "shape-outside", case[0], case[1], true);
}

test "shape outside images use the existing image parser and computed colors" {
    try h.check(testing.allocator, "shape-outside", "linear-gradient(red, blue)", "linear-gradient(rgb(255, 0, 0), rgb(0, 0, 255))", true);
    try h.check(testing.allocator, "shape-outside", "url(https://example.test/shape.png)", "url(\"https://example.test/shape.png\")", true);
    try h.check(testing.allocator, "shape-outside", "linear-gradient(red, blue), url(foo.png)", "", false);
}

test "shape margin is nonnegative and threshold clamps only at computation" {
    try h.check(testing.allocator, "shape-margin", "calc(1px - 2em)", "0px", true);
    try h.check(testing.allocator, "shape-margin", "25%", "25%", true);
    inline for (.{ "-1px", "-20%", "auto" }) |input|
        try h.check(testing.allocator, "shape-margin", input, "", false);
    inline for (.{
        .{ "-7", "-7", "0" },
        .{ "300%", "3", "1" },
        .{ "50%", "0.5", "0.5" },
        .{ "-100%", "-1", "0" },
    }) |case| {
        try h.check(testing.allocator, "shape-image-threshold", case[0], case[1], false);
        try h.check(testing.allocator, "shape-image-threshold", case[0], case[2], true);
    }
}

test "shape properties do not inherit unless requested" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "shape-outside: circle(2em) border-box; shape-margin: 1em; shape-image-threshold: 0.5");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    try h.expect(child, "shape-outside", "none", testing.allocator);
    try h.expect(child, "shape-margin", "0px", testing.allocator);
    try h.expect(child, "shape-image-threshold", "0", testing.allocator);
    _ = try empty.setProperty(.{ .allocator = testing.allocator }, "shape-outside", "inherit", "");
    const inherited = try h.compute(testing.allocator, &empty, parent);
    defer inherited.destroy();
    try h.expect(inherited, "shape-outside", "circle(32px) border-box", testing.allocator);
}

test "shape facade and computation release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "shape-outside", "circle(calc(1em + 2px) at 25% 75%) border-box", "circle(18px at 25% 75%) border-box", true);
    try h.check(allocator, "shape-outside", "polygon(round 1em, 0px 0px, 1em 1em)", "polygon(round 16px, 0px 0px, 16px 16px)", true);
    try h.check(allocator, "shape-outside", "linear-gradient(red, blue)", "linear-gradient(rgb(255, 0, 0), rgb(0, 0, 255))", true);
    try h.check(allocator, "shape-outside", "circle(1em) border-box invalid", "", false);
}
