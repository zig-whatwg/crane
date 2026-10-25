//! Q56/Q57 per-case browser majority: specified and computed interpolation
//! defaults differ. Computed classification uses the original stop graph and
//! the receiving element's scheme BEFORE Color resolution loses its provenance.
//! Receipts: integrator-probes-1023j, -1023k, -1023l (three browsers).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Case = struct { stop: []const u8, specified_legacy: bool, computed_legacy: bool, scheme: []const u8, parent_color: []const u8 };
const cases = [_]Case{
    .{ .stop = "red", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "#f00", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "rgb(255 0 0)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "hsl(0 100% 50%)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "hwb(0 0% 0%)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "Canvas", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "transparent", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "color(srgb 1 0 0)", .specified_legacy = false, .computed_legacy = false, .scheme = "light", .parent_color = "red" },
    .{ .stop = "lab(50 20 30)", .specified_legacy = false, .computed_legacy = false, .scheme = "light", .parent_color = "red" },
    .{ .stop = "lch(50 20 30)", .specified_legacy = false, .computed_legacy = false, .scheme = "light", .parent_color = "red" },
    .{ .stop = "oklab(0.5 0.1 0.1)", .specified_legacy = false, .computed_legacy = false, .scheme = "light", .parent_color = "red" },
    .{ .stop = "oklch(0.5 0.1 120)", .specified_legacy = false, .computed_legacy = false, .scheme = "light", .parent_color = "red" },
    .{ .stop = "currentcolor", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "currentcolor", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "rgb(from red r g b)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "rgb(from color(srgb 1 0 0) r g b)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "hsl(from red h s l)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "oklch(from red l c h)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "color(from red srgb r g b)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "rgb(from currentcolor r g b)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "color-mix(in srgb, red, blue)", .specified_legacy = true, .computed_legacy = false, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "color-mix(in oklab, red, blue)", .specified_legacy = true, .computed_legacy = false, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "color-mix(in srgb, currentcolor, red)", .specified_legacy = true, .computed_legacy = false, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "color-mix(in srgb, red 100%, blue 0%)", .specified_legacy = true, .computed_legacy = false, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(red, blue)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(red, blue)", .specified_legacy = true, .computed_legacy = true, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(red, color(srgb 0 0 1))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(red, color(srgb 0 0 1))", .specified_legacy = true, .computed_legacy = false, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(color(srgb 1 0 0), blue)", .specified_legacy = true, .computed_legacy = false, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(color(srgb 1 0 0), blue)", .specified_legacy = true, .computed_legacy = true, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(currentcolor, red)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(currentcolor, red)", .specified_legacy = true, .computed_legacy = true, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(oklch(from red l c h), red)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(oklch(from red l c h), red)", .specified_legacy = true, .computed_legacy = true, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(color-mix(in srgb, red, blue), red)", .specified_legacy = true, .computed_legacy = false, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(color-mix(in srgb, red, blue), red)", .specified_legacy = true, .computed_legacy = true, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(light-dark(currentcolor, color(srgb 0 0 1)), color-mix(in srgb, red, blue))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "light-dark(light-dark(currentcolor, color(srgb 0 0 1)), color-mix(in srgb, red, blue))", .specified_legacy = true, .computed_legacy = false, .scheme = "dark", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(red)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(oklch(0.5 0.1 30))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(currentcolor)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(color-mix(in srgb, red, blue))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(color(srgb 1 0 0))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(lab(50 20 30))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "contrast-color(light-dark(red, blue))", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "oklch(0.5 0.1 120)" },
    .{ .stop = "alpha(from red / 0.5)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
    .{ .stop = "alpha(from color(srgb 1 0 0) / 0.5)", .specified_legacy = true, .computed_legacy = true, .scheme = "light", .parent_color = "red" },
};

fn hasMethod(text: []const u8, method: []const u8) !bool {
    try testing.expect(std.mem.startsWith(u8, text, "linear-gradient("));
    const after_open = text["linear-gradient(".len..];
    if (!std.mem.startsWith(u8, after_open, "in ")) return false;
    try testing.expect(std.mem.startsWith(u8, after_open[3..], method));
    return true;
}

fn checkCase(case: Case) !void {
    const allocator = testing.allocator;
    // Both the parent AND page/root scheme oppose the tested element. This
    // catches a context copied from the page rather than Builder.used_scheme.
    const opposite = if (std.mem.eql(u8, case.scheme, "light")) "dark" else "light";
    var root_block = css.declarations.DeclarationBlock.init(allocator);
    defer root_block.deinit();
    try testing.expect(try root_block.setProperty(.{ .allocator = allocator }, "color-scheme", opposite, ""));
    const root = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = &root_block, .source = .{ .origin = .author } }});
    defer root.destroy();
    var parent_block = css.declarations.DeclarationBlock.init(allocator);
    defer parent_block.deinit();
    try testing.expect(try parent_block.setProperty(.{ .allocator = allocator }, "color", case.parent_color, ""));
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = root, .page_color_scheme = root.used_color_scheme }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    for ([_][]const u8{ "srgb", "oklab" }) |method| {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "color-scheme", case.scheme, ""));
        const input = try std.fmt.allocPrint(allocator, "linear-gradient(in {s}, {s}, blue)", .{ method, case.stop });
        defer allocator.free(input);
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", input, ""));
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try block.getPropertyValue("background-image", &out);
        try testing.expectEqual(case.specified_legacy != std.mem.eql(u8, method, "srgb"), try hasMethod(out.items, method));
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .page_color_scheme = root.used_color_scheme }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try testing.expectEqualStrings(case.scheme, @tagName(style.used_color_scheme));
        block.clear();
        out.clearRetainingCapacity();
        try style.serializeResolved(.background_image, &out, allocator);
        try testing.expectEqual(case.computed_legacy != std.mem.eql(u8, method, "srgb"), try hasMethod(out.items, method));
    }
}

test "gradient default interpolation follows both stages and the element scheme" {
    for (cases) |case| checkCase(case) catch |err| {
        std.debug.print("gradient default: {s}, element {s}, parent color {s}\n", .{ case.stop, case.scheme, case.parent_color });
        return err;
    };
}
