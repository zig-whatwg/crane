//! Q56/Q92: both stages of every integrator probe1023j/k/l case.
//! This is intentionally a per-case browser majority: Chromium's selected
//! light-dark branch, Firefox/Safari's currentcolor and relative colors,
//! and Chromium/Firefox's computed mix classification.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Color = css.style_values.Color;
fn check(text: []const u8, scheme: css.color_scheme.Scheme, specified: bool, computed: bool) !void {
    if (comptime !@hasDecl(Color, "usesLegacyGradientInterpolation")) return error.GradientColorMetadataNotImplemented;
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "color", text, "");
    try testing.expectEqual(@as(usize, 1), block.entries.items.len);
    const color = block.entries.items[0].typed.value.value.color;
    try testing.expectEqual(specified, color.usesLegacyGradientInterpolation(.specified));
    try testing.expectEqual(computed, color.usesLegacyGradientInterpolation(.{ .computed = scheme }));
}

test "gradient metadata currentcolor@modern" {
    try check("currentcolor", .light, true, true);
}

test "gradient metadata currentcolor@legacy" {
    try check("currentcolor", .light, true, true);
}

test "gradient metadata light-dark(red, blue)" {
    try check("light-dark(red, blue)", .light, true, true);
}

test "gradient metadata light-dark(color(srgb 1 0 0), blue)" {
    try check("light-dark(color(srgb 1 0 0), blue)", .light, true, false);
}

test "gradient metadata color-mix(in srgb, red, blue)" {
    try check("color-mix(in srgb, red, blue)", .light, true, false);
}

test "gradient metadata color-mix(in oklab, red, blue)" {
    try check("color-mix(in oklab, red, blue)", .light, true, false);
}

test "gradient metadata rgb(from red r g b)" {
    try check("rgb(from red r g b)", .light, true, true);
}

test "gradient metadata rgb(from color(srgb 1 0 0) r g b)" {
    try check("rgb(from color(srgb 1 0 0) r g b)", .light, true, true);
}

test "gradient metadata hsl(from red h s l)" {
    try check("hsl(from red h s l)", .light, true, true);
}

test "gradient metadata oklch(from red l c h)" {
    try check("oklch(from red l c h)", .light, true, true);
}

test "gradient metadata color(from red srgb r g b)" {
    try check("color(from red srgb r g b)", .light, true, true);
}

test "gradient metadata Canvas" {
    try check("Canvas", .light, true, true);
}

test "gradient metadata transparent" {
    try check("transparent", .light, true, true);
}

test "gradient metadata red" {
    try check("red", .light, true, true);
}

test "gradient metadata rgb(255 0 0)" {
    try check("rgb(255 0 0)", .light, true, true);
}

test "gradient metadata hsl(0 100% 50%)" {
    try check("hsl(0 100% 50%)", .light, true, true);
}

test "gradient metadata #f00" {
    try check("#f00", .light, true, true);
}

test "gradient metadata color(srgb 1 0 0)" {
    try check("color(srgb 1 0 0)", .light, false, false);
}

test "gradient metadata lab(50 20 30)" {
    try check("lab(50 20 30)", .light, false, false);
}

test "gradient metadata light-dark(red, color(srgb 0 0 1))@light" {
    try check("light-dark(red, color(srgb 0 0 1))", .light, true, true);
}

test "gradient metadata light-dark(red, color(srgb 0 0 1))@dark" {
    try check("light-dark(red, color(srgb 0 0 1))", .dark, true, false);
}

test "gradient metadata light-dark(color(srgb 1 0 0), blue)@dark" {
    try check("light-dark(color(srgb 1 0 0), blue)", .dark, true, true);
}

test "gradient metadata light-dark(color(srgb 1 0 0), blue)@light" {
    try check("light-dark(color(srgb 1 0 0), blue)", .light, true, false);
}

test "gradient metadata light-dark(currentcolor, red)@light" {
    try check("light-dark(currentcolor, red)", .light, true, true);
}

test "gradient metadata light-dark(oklch(from red l c h), red)@light" {
    try check("light-dark(oklch(from red l c h), red)", .light, true, true);
}

test "gradient metadata color-mix(in srgb, currentcolor, red)@light" {
    try check("color-mix(in srgb, currentcolor, red)", .light, true, false);
}

test "gradient metadata color-mix(in srgb, red 100%, blue 0%)@light" {
    try check("color-mix(in srgb, red 100%, blue 0%)", .light, true, false);
}

test "gradient metadata light-dark(color-mix(in srgb, red, blue), red)@light" {
    try check("light-dark(color-mix(in srgb, red, blue), red)", .light, true, false);
}

test "gradient metadata light-dark(color-mix(in srgb, red, blue), red)@dark" {
    try check("light-dark(color-mix(in srgb, red, blue), red)", .dark, true, true);
}

test "gradient metadata rgb(from currentcolor r g b)@light" {
    try check("rgb(from currentcolor r g b)", .light, true, true);
}

test "gradient metadata contrast-color(red)" {
    try check("contrast-color(red)", .light, true, true);
}

test "gradient metadata contrast-color(oklch(0.5 0.1 30))" {
    try check("contrast-color(oklch(0.5 0.1 30))", .light, true, true);
}

test "gradient metadata contrast-color(currentcolor)" {
    try check("contrast-color(currentcolor)", .light, true, true);
}

test "gradient metadata contrast-color(color-mix(in srgb, red, blue))" {
    try check("contrast-color(color-mix(in srgb, red, blue))", .light, true, true);
}

test "gradient metadata contrast-color(color(srgb 1 0 0))" {
    try check("contrast-color(color(srgb 1 0 0))", .light, true, true);
}

test "gradient metadata contrast-color(lab(50 20 30))" {
    try check("contrast-color(lab(50 20 30))", .light, true, true);
}

test "gradient metadata contrast-color(light-dark(red, blue))" {
    try check("contrast-color(light-dark(red, blue))", .light, true, true);
}

test "gradient metadata alpha(from red / 0.5)" {
    try check("alpha(from red / 0.5)", .light, true, true);
}

test "gradient metadata alpha(from color(srgb 1 0 0) / 0.5)" {
    try check("alpha(from color(srgb 1 0 0) / 0.5)", .light, true, true);
}

test "gradient metadata uses the element scheme when parent and root differ" {
    if (comptime !@hasDecl(Color, "usesLegacyGradientInterpolation")) return error.GradientColorMetadataNotImplemented;
    var root_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color-scheme: light");
    defer root_block.deinit();
    const root_style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &root_block, .source = .{ .origin = .author } }});
    defer root_style.destroy();
    const parent_style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = root_style }, &.{});
    defer parent_style.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color-scheme: dark; color: light-dark(red, color(srgb 0 0 1))");
    defer child_block.deinit();
    const child_style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent_style }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child_style.destroy();
    try testing.expectEqual(css.color_scheme.Scheme.light, root_style.used_color_scheme);
    try testing.expectEqual(css.color_scheme.Scheme.light, parent_style.used_color_scheme);
    try testing.expectEqual(css.color_scheme.Scheme.dark, child_style.used_color_scheme);
    const original = child_block.entries.items[1].typed.value.value.color;
    try testing.expect(original.usesLegacyGradientInterpolation(.specified));
    try testing.expect(!original.usesLegacyGradientInterpolation(.{ .computed = child_style.used_color_scheme }));
    try testing.expect(original.usesLegacyGradientInterpolation(.{ .computed = parent_style.used_color_scheme }));
}
