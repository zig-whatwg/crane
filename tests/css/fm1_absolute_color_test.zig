//! Color 5 §2's absolute-color definition, used by Fonts 4 §9.2.3.
const std = @import("std");
const css = @import("css");
const Color = css.style_values.Color;
const testing = std.testing;

fn check(allocator: std.mem.Allocator, input: []const u8, expected: bool) !void {
    var stream = css.properties.Stream.init(input);
    const value = try css.properties.parseLonghand(.{ .allocator = allocator }, .color, &stream) orelse return error.ExpectedColor;
    defer value.release();
    try testing.expect(stream.atEnd());
    try testing.expect(value == .color);
    try testing.expectEqual(expected, value.color.isAbsolute());
}

test "absolute-color defaults classify every scalar representation" {
    const named: Color = .{ .named = .{ .rgba = css.style_values.RgbaColor.black, .name = try css.style_values.SharedText.create(testing.allocator, "black") } };
    defer named.release();
    try testing.expect(Color.black.isAbsolute());
    try testing.expect(Color.transparent.isAbsolute());
    try testing.expect(named.isAbsolute());
    try testing.expect(!(@as(Color, .current)).isAbsolute());
    try testing.expect(!(@as(Color, .{ .system = .canvastext })).isAbsolute());
}

test "absolute-color follows nested origins and rejects mode-dependent functions" {
    inline for (.{
        "red",                                                             "#123",                "transparent",          "lab(40 20 30)",
        "color(display-p3 1 0 0)",                                         "rgb(from red r g b)", "alpha(from red / .5)", "color-mix(in lch, red, blue)",
        "color-mix(in oklab, rgb(from red r g b), alpha(from blue / .5))",
    }) |input| try check(testing.allocator, input, true);
    inline for (.{
        "currentcolor",                                    "canvas",                               "light-dark(red, red)",
        "contrast-color(red)",                             "rgb(from currentcolor r g b)",         "rgb(from light-dark(red, blue) r g b)",
        "alpha(from canvas / .5)",                         "alpha(from contrast-color(red) / .5)", "color-mix(in lch, red, color-mix(in lch, canvas, blue))",
        "color-mix(in oklab, blue 100%, currentcolor 0%)",
    }) |input| try check(testing.allocator, input, false);
}

test "absolute-color classification retains no parsed references under OOM" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn exercise(allocator: std.mem.Allocator) anyerror!void {
            try check(allocator, "color-mix(in oklab, rgb(from red r g b), alpha(from blue / .5))", true);
            try check(allocator, "color-mix(in lch, red, color-mix(in lch, canvas, blue))", false);
        }
    }.exercise, .{});
}
