//! Q91: per-case Chrome/Firefox/Safari majorities from integrator probes1023h/i.
//! Every modeled majority uses Blink's f32 conversion and 8-bit luminance path.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
fn check(text: []const u8, expected: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "color", text, "");
    try testing.expectEqual(@as(usize, 1), block.entries.items.len);
    const color = block.entries.items[0].typed.value.value.color;
    const computed = try color.resolveComputed(testing.allocator, .{});
    defer computed.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try computed.serializeComputed(&out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "contrast majority contrast-color(oklch(0.5 calc(infinity) 0))" {
    try check("contrast-color(oklch(0.5 calc(infinity) 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(lch(50 calc(infinity) 0))" {
    try check("contrast-color(lch(50 calc(infinity) 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(color(srgb calc(infinity) 0 0))" {
    try check("contrast-color(color(srgb calc(infinity) 0 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklch(0.5 1e30 0))" {
    try check("contrast-color(oklch(0.5 1e30 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(lch(50 1e30 0))" {
    try check("contrast-color(lch(50 1e30 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(color(srgb 1e30 0 0))" {
    try check("contrast-color(color(srgb 1e30 0 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(red)" {
    try check("contrast-color(red)", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(white)" {
    try check("contrast-color(white)", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(50 calc(infinity) 30))" {
    try check("contrast-color(lch(50 calc(infinity) 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(50 calc(infinity) 90))" {
    try check("contrast-color(lch(50 calc(infinity) 90))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(lch(50 calc(infinity) 200))" {
    try check("contrast-color(lch(50 calc(infinity) 200))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(10 calc(infinity) 30))" {
    try check("contrast-color(lch(10 calc(infinity) 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(90 calc(infinity) 30))" {
    try check("contrast-color(lch(90 calc(infinity) 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(0 calc(infinity) 30))" {
    try check("contrast-color(lch(0 calc(infinity) 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(100 calc(infinity) 30))" {
    try check("contrast-color(lch(100 calc(infinity) 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklch(0.5 calc(infinity) 30))" {
    try check("contrast-color(oklch(0.5 calc(infinity) 30))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklch(0.1 calc(infinity) 30))" {
    try check("contrast-color(oklch(0.1 calc(infinity) 30))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklch(0.9 calc(infinity) 30))" {
    try check("contrast-color(oklch(0.9 calc(infinity) 30))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklch(0.62 calc(infinity) 30))" {
    try check("contrast-color(oklch(0.62 calc(infinity) 30))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklch(0.7 calc(infinity) 0))" {
    try check("contrast-color(oklch(0.7 calc(infinity) 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(lab(50 calc(infinity) 0))" {
    try check("contrast-color(lab(50 calc(infinity) 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lab(50 0 calc(infinity)))" {
    try check("contrast-color(lab(50 0 calc(infinity)))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lab(50 calc(-infinity) 0))" {
    try check("contrast-color(lab(50 calc(-infinity) 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklab(0.5 calc(infinity) 0))" {
    try check("contrast-color(oklab(0.5 calc(infinity) 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklab(0.62 calc(infinity) 0))" {
    try check("contrast-color(oklab(0.62 calc(infinity) 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(color(srgb calc(-infinity) 0 0))" {
    try check("contrast-color(color(srgb calc(-infinity) 0 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(color(srgb 0 0 calc(infinity)))" {
    try check("contrast-color(color(srgb 0 0 calc(infinity)))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(color(srgb calc(infinity) calc(infinity) calc(infinity)))" {
    try check("contrast-color(color(srgb calc(infinity) calc(infinity) calc(infinity)))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(color(srgb calc(-infinity) calc(-infinity) calc(-infinity)))" {
    try check("contrast-color(color(srgb calc(-infinity) calc(-infinity) calc(-infinity)))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(color(display-p3 calc(infinity) 0 0))" {
    try check("contrast-color(color(display-p3 calc(infinity) 0 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(rgb(calc(infinity) 0 0))" {
    try check("contrast-color(rgb(calc(infinity) 0 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(50 1e30 30))" {
    try check("contrast-color(lch(50 1e30 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(50 1e30 200))" {
    try check("contrast-color(lch(50 1e30 200))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(10 1e30 30))" {
    try check("contrast-color(lch(10 1e30 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklch(0.5 1e30 30))" {
    try check("contrast-color(oklch(0.5 1e30 30))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklch(0.62 1e30 0))" {
    try check("contrast-color(oklch(0.62 1e30 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(oklch(0.7 1e30 0))" {
    try check("contrast-color(oklch(0.7 1e30 0))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(lab(50 1e30 0))" {
    try check("contrast-color(lab(50 1e30 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(color(srgb 0 0 1e30))" {
    try check("contrast-color(color(srgb 0 0 1e30))", "rgb(255, 255, 255)");
}

test "contrast majority contrast-color(lch(50 0 0))" {
    try check("contrast-color(lch(50 0 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklch(0.62 0 0))" {
    try check("contrast-color(oklch(0.62 0 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklch(0.7 0 0))" {
    try check("contrast-color(oklch(0.7 0 0))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(lch(50 300 30))" {
    try check("contrast-color(lch(50 300 30))", "rgb(0, 0, 0)");
}

test "contrast majority contrast-color(oklch(0.5 5 30))" {
    try check("contrast-color(oklch(0.5 5 30))", "rgb(0, 0, 0)");
}
