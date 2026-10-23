//! CSS Color 4/5: preserve color space, missing channels and deferred currentcolor.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn specified(allocator: std.mem.Allocator, text: []const u8, expected: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("color", &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn computed(allocator: std.mem.Allocator, text: []const u8, expected: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.color, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "computed colors preserve their channels beyond the legacy byte adapter" {
    try computed(testing.allocator, "color:color(display-p3 1.25 -.5 .123456 / .123456)", "color(display-p3 1.25 -0.5 0.123456 / 0.123456)");
    try computed(testing.allocator, "color:lab(50% 20% -20%)", "lab(50 25 -25)");
    try computed(testing.allocator, "color:oklch(50% 50% 450deg)", "oklch(0.5 0.2 90)");
}

test "missing components keep their color space and none state" {
    try computed(testing.allocator, "color:rgb(none 128 255 / none)", "color(srgb none 0.501961 1 / none)");
    try computed(testing.allocator, "color:hsl(none 20% 40%)", "hsl(none 20% 40%)");
    try computed(testing.allocator, "color:hwb(120 none 20%)", "hwb(120 none 20%)");
}

test "mixing converts channels before interpolation and premultiplies alpha" {
    try computed(testing.allocator, "color:color-mix(in srgb,red,blue)", "color(srgb 0.5 0 0.5)");
    try computed(testing.allocator, "color:color-mix(in srgb,red 25%,blue 25%)", "color(srgb 0.5 0 0.5 / 0.5)");
    try computed(testing.allocator, "color:color-mix(in srgb,red 0%,blue 0%)", "color(srgb 0.5 0 0.5 / 0)");
    try computed(testing.allocator, "color:color-mix(in srgb,rgb(255 0 0 / .25),rgb(0 0 255 / .75))", "color(srgb 0.25 0 0.75 / 0.5)");
}

test "color interpolation fills missing channels and preserves doubly missing channels" {
    try computed(testing.allocator, "color:color-mix(in srgb,color(srgb none .2 .3),color(srgb .5 none .7))", "color(srgb 0.5 0.2 0.5)");
    try computed(testing.allocator, "color:color-mix(in srgb,color(srgb none none none / none),color(srgb none none none / none))", "color(srgb none none none / none)");
    try computed(testing.allocator, "color:color-mix(in srgb,color(srgb 1 0 0 / none),color(srgb 0 0 1 / .5))", "color(srgb 0.5 0 0.5 / 0.5)");
}

test "all four hue interpolation directions handle the zero degree boundary" {
    inline for (.{
        .{ "shorter", "color(srgb 1 0 0)" },
        .{ "longer", "color(srgb 0 1 1)" },
        .{ "increasing", "color(srgb 1 0 0)" },
        .{ "decreasing", "color(srgb 0 1 1)" },
    }) |c| try computed(testing.allocator, "color:color-mix(in hsl " ++ c[0] ++ " hue,hsl(350 100% 50%),hsl(10 100% 50%))", c[1]);
}

test "contrast color computes nested modern colors with the used color scheme" {
    try computed(testing.allocator, "color:contrast-color(color-mix(in srgb,black,black))", "rgb(255, 255, 255)");
    try computed(testing.allocator, "color:contrast-color(color(display-p3 1 1 1))", "rgb(0, 0, 0)");
    try computed(testing.allocator, "color-scheme:dark;color:contrast-color(light-dark(white,black))", "rgb(255, 255, 255)");
}

test "relative colors evaluate channel expressions without clipping their origin" {
    try computed(testing.allocator, "color:rgb(from color(srgb 1.5 0 -.5) calc(r / 2) g b)", "color(srgb 0.75 0 -0.5)");
    try computed(testing.allocator, "color:rgb(from red r g b / calc(alpha / 2))", "color(srgb 1 0 0 / 0.5)");
    try computed(testing.allocator, "color:alpha(from red / .5)", "color(srgb 1 0 0 / 0.5)");
    try computed(testing.allocator, "color:rgb(from rgb(none 0 0) r g b)", "color(srgb none 0 0)");
}

// Color 4 §10.8 and CSSWG #12574 use display-referred gamma 2.4.
// Pinned color-computed-relative-color.html:840-841 checks both directions.
test "rec2020 conversion uses the updated display referred transfer function" {
    // Those WPT assertions use epsilon .001, not byte-for-byte equality:
    // Color4 §16.5 specifies minimum precision, not one decimal rounding.
    inline for (.{
        .{ "color:color(from color(rec2020 .25 .5 .75) srgb r g b)", .srgb, .{ -0.328686, 0.491201, 0.76185 } },
        .{ "color:color(from color(srgb .25 .5 .75) rec2020 r g b)", .rec2020, .{ 0.420493, 0.518024, 0.741381 } },
    }) |case| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, case[0]);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        const color = try style.resolvedColor(.color, testing.allocator);
        defer color.release();
        const components = color.expression.data.resolved.value;
        try testing.expectEqual(case[1], components.space);
        inline for (case[2], 0..) |expected, index|
            try testing.expectApproxEqAbs(@as(f64, expected), components.channel(index), 0.00001);
    }
}

test "computed inherited color expressions retain a child's symbolic currentcolor" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:red;background-color:color-mix(in srgb,currentcolor,white)");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:blue;background-color:inherit");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try parent.serializeResolved(.background_color, &out, testing.allocator);
    try testing.expectEqualStrings("color(srgb 1 0.5 0.5)", out.items);
    out.clearRetainingCapacity();
    try child.serializeResolved(.background_color, &out, testing.allocator);
    try testing.expectEqualStrings("color(srgb 0.5 0.5 1)", out.items);
}

test "nested typed color holders retain every child after the declaration goes away" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:color-mix(in srgb,currentcolor,white)");
    const held = retainOnlyColor(&block) catch |err| {
        block.deinit();
        return err;
    };
    block.deinit();
    // The owned holder is all that remains after declaration teardown.
    defer held.release();
    const resolved = try held.resolveComputed(testing.allocator, .{ .current = .black });
    defer resolved.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try resolved.serializeComputed(&out, testing.allocator);
    try testing.expectEqualStrings("color(srgb 0.5 0.5 0.5)", out.items);
}

fn retainOnlyColor(block: *css.declarations.DeclarationBlock) !css.style_values.Color {
    try testing.expectEqual(@as(usize, 1), block.entries.items.len);
    const color = block.entries.items[0].typed.value.value.color;
    color.retain();
    return color;
}

test "invalid typed color grammar cannot replace an earlier valid declaration" {
    for ([_][]const u8{
        "color:red;color:color(display-p3 1 0)",
        "color:red;color:rgb(from red r,g,b)",
        "color:red;color:rgb(from red l g b)",
        "color:red;color:color-mix(in srgb longer hue,red,blue)",
        "color:red;color:color-mix(in srgb,red -1%,blue)",
        "color:red;color:contrast-color(red,blue)",
    }) |input| try specified(testing.allocator, input, "red");
}

test "nested colors and their computed copies release all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) anyerror!void {
    try computed(allocator, "color:color-mix(in srgb,light-dark(red,blue),rgb(from red 0 0 255))", "color(srgb 0.5 0 0.5)");
}

// Q76: main tmp/analysis/integrator-probes-1022j/results/colormix-{chrome,firefox,safari}.json.
// All shipping browsers preserve equal shares unless exactly 100%/N.
test "color mix specified shares follow the three browser serialization probe" {
    const cases = .{
        .{ "color-mix(in srgb,red 70%,blue 70%)", "color-mix(in srgb, red 70%, blue 70%)", "color(srgb 0.5 0 0.5)" },
        .{ "color-mix(in srgb,red 50%,blue 50%)", "color-mix(in srgb, red, blue)", "color(srgb 0.5 0 0.5)" },
        .{ "color-mix(in srgb,red 30%,blue 30%)", "color-mix(in srgb, red 30%, blue 30%)", "color(srgb 0.5 0 0.5 / 0.6)" },
        .{ "color-mix(in srgb,red 40%,blue 40%,green 40%)", "color-mix(in srgb, red 40%, blue 40%, green 40%)", "color(srgb 0.333333 0.16732 0.333333)" },
        .{ "color-mix(in srgb,red 30%,blue 90%)", "color-mix(in srgb, red 30%, blue 90%)", "color(srgb 0.25 0 0.75)" },
        .{ "color-mix(in srgb,red,blue)", "color-mix(in srgb, red, blue)", "color(srgb 0.5 0 0.5)" },
        .{ "color-mix(in srgb,red 50%,blue)", "color-mix(in srgb, red, blue)", "color(srgb 0.5 0 0.5)" },
    };
    inline for (cases) |c| {
        try specified(testing.allocator, "color:" ++ c[0], c[1]);
        try computed(testing.allocator, "color:" ++ c[0], c[2]);
    }
}

// Q77: alpha-color-parsing-valid is unanimous; modern computed output is
// newer CSSWG #13994 behavior shipped by Firefox. #13992 spelling follows up.
test "alpha declared syntax keeps explicit overrides while its computed result is modern" {
    const cases = .{
        .{ "alpha(from red / .5)", "alpha(from red / 0.5)" },
        .{ "alpha(from currentcolor / 1)", "alpha(from currentcolor / 1)" },
        .{ "alpha(from currentcolor / 100%)", "alpha(from currentcolor / 100%)" },
        .{ "alpha(from hsl(120 50% 50%) / .5)", "alpha(from rgb(64, 191, 64) / 0.5)" },
        .{ "alpha(from hwb(120 0% 0%) / .5)", "alpha(from rgb(0, 255, 0) / 0.5)" },
    };
    inline for (cases) |c| try specified(testing.allocator, "color:" ++ c[0], c[1]);
    try computed(testing.allocator, "color:alpha(from red / .5)", "color(srgb 1 0 0 / 0.5)");
}

// Append to tests/css/cv1_typed_color_test.zig after restoring the feature tree.
test "legacy cylindrical colors preserve exact half channel rounding" {
    try computed(testing.allocator, "color:hsl(120 0% 50%)", "rgb(128, 128, 128)");
    try computed(testing.allocator, "color:hsl(30 75% 50%)", "rgb(223, 128, 32)");
    try computed(testing.allocator, "color:hwb(120 30% 50%)", "rgb(77, 128, 77)");
    try computed(testing.allocator, "color:hwb(120 60% 60%)", "rgb(128, 128, 128)");
}

test "HWB normalizes authored white black ratios without premature upper clipping" {
    try computed(testing.allocator, "color:hwb(0 200% 100%)", "rgb(170, 170, 170)");
    try computed(testing.allocator, "color:hwb(0 100% 200%)", "rgb(85, 85, 85)");
    try computed(testing.allocator, "color:hwb(0 150% 50%)", "rgb(191, 191, 191)");
    try computed(testing.allocator, "color:hwb(0 50% 150%)", "rgb(64, 64, 64)");
    try computed(testing.allocator, "color:hwb(0 180% 120%)", "rgb(153, 153, 153)");
}

test "relative alpha syntax requires its slash and amount at every nesting level" {
    inline for (.{
        "alpha(from red)",
        "alpha(from currentcolor)",
        "alpha(from rgba(255, 0, 0, 0.3))",
        "alpha(from alpha(from currentcolor / 0.5))",
        "alpha(from alpha(from currentcolor) / 0.5)",
    }) |value| try specified(testing.allocator, "color:red;color:" ++ value, "red");
}

// Q101: append after the original typed-color tests, before implementation.
// CSS Color4 §§15.2/15.3 applies the resolved color range after Color5§4.1's
// extended intermediate channels. These assertions are pinned WPT cases.
test "relative Lab family resolved ranges clamp lightness and chroma only" {
    const cases = .{
        .{ "lab(from lab(200 300 400 / 500%) l a b / alpha)", "lab(100 300 400)" },
        .{ "lab(from lab(-200 -300 -400 / -500%) l a b / alpha)", "lab(0 -300 -400 / 0)" },
        .{ "lab(from lab(.7 45 30 / 40%) 200 300 400 / 500)", "lab(100 300 400)" },
        .{ "lab(from lab(.7 45 30 / 40%) -200 -300 -400 / -500)", "lab(0 -300 -400 / 0)" },
        .{ "oklab(from oklab(2 3 4 / 500%) l a b / alpha)", "oklab(1 3 4)" },
        .{ "oklab(from oklab(-2 -3 -4 / -500%) l a b / alpha)", "oklab(0 -3 -4 / 0)" },
        .{ "oklab(from oklab(.7 .45 .3 / 40%) 2 3 4 / 500)", "oklab(1 3 4)" },
        .{ "oklab(from oklab(.7 .45 .3 / 40%) -2 -3 -4 / -500)", "oklab(0 -3 -4 / 0)" },
        .{ "lch(from lch(200 300 400 / 500%) l c h / alpha)", "lch(100 300 40)" },
        .{ "lch(from lch(-200 -300 -400 / -500%) l c h / alpha)", "lch(0 0 320 / 0)" },
        .{ "lch(from lch(.7 45 30 / 40%) 200 300 400 / 500)", "lch(100 300 40)" },
        .{ "lch(from lch(.7 45 30 / 40%) -200 -300 -400 / -500)", "lch(0 0 320 / 0)" },
        .{ "oklch(from oklch(2 3 400 / 500%) l c h / alpha)", "oklch(1 3 40)" },
        .{ "oklch(from oklch(-2 -3 -400 / -500%) l c h / alpha)", "oklch(0 0 320 / 0)" },
        .{ "oklch(from oklch(.7 .45 30 / 40%) 2 3 400 / 500)", "oklch(1 3 40)" },
        .{ "oklch(from oklch(.7 .45 30 / 40%) -2 -3 -400 / -500)", "oklch(0 0 320 / 0)" },
    };
    inline for (cases) |case| try computed(testing.allocator, "color:" ++ case[0], case[1]);
}

test "resolved Lab normalization preserves extended RGB and specified relative channels" {
    try computed(testing.allocator, "color:rgb(from red 510 -255 0)", "color(srgb 2 -1 0)");
    try computed(testing.allocator, "color:color(from red display-p3 2 -1 .5)", "color(display-p3 2 -1 0.5)");
    try computed(testing.allocator, "color:lab(from red 50 300 -400)", "lab(50 300 -400)");
    try specified(testing.allocator, "color:lab(from red 200 300 -400)", "lab(from red 200 300 -400)");
    try specified(testing.allocator, "color:oklch(from red -2 -3 -400)", "oklch(from red -2 -3 -400)");
}

test "converted and mixed Lab colors are stored normalized and round trip" {
    inline for (.{ "lch(from oklch(0 .2 0) l c h)", "color-mix(in lch, oklch(0 .2 0))" }) |value| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:" ++ value);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        const color = try style.resolvedColor(.color, testing.allocator);
        defer color.release();
        const components = color.expression.data.resolved.value;
        try testing.expectEqual(@as(f64, 0), components.channel(0));
        try testing.expectApproxEqAbs(@as(f64, 2.6503948), components.channel(1), 0.00001);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try color.serializeComputed(&out, testing.allocator);
        const declaration = try std.fmt.allocPrint(testing.allocator, "color:{s}", .{out.items});
        defer testing.allocator.free(declaration);
        try computed(testing.allocator, declaration, out.items);
    }
}

// Append to the typed-color test file after the isolated index is committed.
test "relative specified colors preserve explicit alpha and distinguish omission" {
    const cases = .{
        .{ "rgb(from red r g b / alpha)", "rgb(from red r g b / alpha)" },
        .{ "rgb(from red r g b)", "rgb(from red r g b)" },
        .{ "hsl(from red h s l / alpha)", "hsl(from red h s l / alpha)" },
        .{ "hwb(from red h w b / alpha)", "hwb(from red h w b / alpha)" },
        .{ "lab(from red l a b / alpha)", "lab(from red l a b / alpha)" },
        .{ "lch(from red l c h / alpha)", "lch(from red l c h / alpha)" },
        .{ "oklab(from red l a b / alpha)", "oklab(from red l a b / alpha)" },
        .{ "oklch(from red l c h / alpha)", "oklch(from red l c h / alpha)" },
        .{ "color(from red display-p3 r g b / alpha)", "color(from red display-p3 r g b / alpha)" },
        .{ "rgb(from rgb(from red r g b / alpha) r g b / alpha)", "rgb(from rgb(from red r g b / alpha) r g b / alpha)" },
    };
    inline for (cases) |case| try specified(testing.allocator, "color:" ++ case[0], case[1]);
}

test "RGB percentage conversion preserves half byte rounding" {
    try computed(testing.allocator, "color:rgb(42% 3% 50%)", "rgb(107, 8, 128)");
    try computed(testing.allocator, "color:rgb(50%, 50%, 50%)", "rgb(128, 128, 128)");
}

test "color conversion handles destination powerless hue before restoring analogous missing sets" {
    const spaces = css.color_spaces;
    const source = spaces.Components{ .space = .hwb, .channels = .{ 180, 0, 0 }, .missing = 6 };
    inline for (.{
        .{ spaces.Space.hsl, @as(usize, 0), @as(u4, 6), @as(f64, 180) },
        .{ spaces.Space.lch, @as(usize, 2), @as(u4, 3), @as(f64, 196.45478916) },
        .{ spaces.Space.oklch, @as(usize, 2), @as(u4, 3), @as(f64, 194.7689599) },
    }) |case| {
        const converted = source.convert(case[0]);
        try testing.expectEqual(case[2], converted.missing);
        try testing.expectApproxEqAbs(case[3], converted.channel(case[1]), 0.0001);
    }
    // A powerless SOURCE hue is absent when its analog reaches HWB too.
    inline for (.{
        spaces.Components{ .space = .hsl, .channels = .{ 180, 0, 0 }, .missing = 6 },
        spaces.Components{ .space = .lch, .channels = .{ 0, 0, 180 }, .missing = 3 },
        spaces.Components{ .space = .oklch, .channels = .{ 0, 0, 180 }, .missing = 3 },
    }) |input| try testing.expectEqual(@as(u4, 7), input.convert(.hwb).missing);
    try computed(testing.allocator, "color:hsl(from hwb(180 none none) h s l)", "hsl(180 none none)");
    try computed(testing.allocator, "color:hwb(from hsl(180 none none) h w b)", "hwb(none none none)");
    try computed(testing.allocator, "color:color-mix(in hsl,hwb(180 none none),hsl(11 33 44))", "color(srgb 0.41338 0.5852 0.2948)");
}

// Q110 supersedes Q109: the raw converted saturation is inside the spec's
// epsilon. CSSWG #14133's newer achromatic rule suppresses the noise hue.
test "OKLCH white HSL mix follows the newer powerless hue rule" {
    try computed(testing.allocator, "color:color-mix(in hsl,oklch(100% 0 0),blue)", "color(srgb 0.625 0.625 0.875)");
}

test "OKLCH white HWB mix follows the newer powerless hue rule" {
    // Q110 / CSSWG #14133: the pinned WPT still retains the noise hue.
    try computed(testing.allocator, "color:color-mix(in hwb,oklch(100% 0 0),blue)", "color(srgb 0.5 0.5 1)");
}

test "plain white controls remain achromatic in cylindrical mixes" {
    try computed(testing.allocator, "color:color-mix(in hsl,white,blue)", "color(srgb 0.625 0.625 0.875)");
    try computed(testing.allocator, "color:color-mix(in hwb,white,blue)", "color(srgb 0.5 0.5 1)");
}

test "LCH white conversion remains pinned while the browser split waits" {
    // Q109 keeps the existing arithmetic until Chrome resolves the split.
    try computed(testing.allocator, "color:color-mix(in hsl,lch(100% 0 0),blue)", "color(srgb 0.375 1.01786 1.125)");
    try computed(testing.allocator, "color:color-mix(in hwb,lch(100% 0 0),blue)", "color(srgb 0.5 0.5 1)");
}
