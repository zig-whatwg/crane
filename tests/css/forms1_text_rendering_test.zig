//! Lane forms1 (C1): the text-rendering property. SVG 2 §13.10.2
//! (specs/w3c/svg2/painting.md:2479): auto | optimizeSpeed |
//! optimizeLegibility | geometricPrecision, initial auto, inherited, computed
//! as specified, animation type discrete. Chrome, Firefox and Safari all
//! ship it as a CSS property and serialize its keywords lowercase
//! (html/semantics/forms/the-select-element/customizable-select/
//! select-base-appearance-computed-style.html expects "optimizelegibility").
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;
const ComputedStyle = css.computed_style.ComputedStyle;

fn styleOf(allocator: Allocator, text: []const u8, parent: ?*const ComputedStyle) !*ComputedStyle {
    var block = try Block.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null }, &.{
        .{ .block = &block, .source = .{ .origin = .author, .order = 1 } },
    });
}

fn expectComputed(style: *const ComputedStyle, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(.text_rendering, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "text-rendering is a longhand named text-rendering" {
    const property = css.properties.lookup("text-rendering") orelse return error.TestUnexpectedResult;
    try testing.expectEqual(css.properties.Longhand.text_rendering, property.longhand);
    try testing.expect(css.properties.Longhand.text_rendering.info().inherited);
}

test "every text-rendering keyword parses ASCII case-insensitively and computes lowercase" {
    const cases = [_][2][]const u8{
        .{ "auto", "auto" },
        .{ "optimizeSpeed", "optimizespeed" },
        .{ "optimizeLegibility", "optimizelegibility" },
        .{ "GEOMETRICPRECISION", "geometricprecision" },
    };
    for (cases) |case| {
        const text = try std.fmt.allocPrint(testing.allocator, "text-rendering: {s}", .{case[0]});
        defer testing.allocator.free(text);
        const style = try styleOf(testing.allocator, text, null);
        defer style.destroy();
        try expectComputed(style, case[1]);
    }
}

test "text-rendering rejects what its grammar does not name" {
    // optimizeQuality is image-rendering's SVG keyword, not text-rendering's.
    for ([_][]const u8{ "optimizeQuality", "none", "crisp-edges", "auto auto", "1" }) |value| {
        var block = Block.init(testing.allocator);
        defer block.deinit();
        try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "text-rendering", value, ""));
    }
}

test "text-rendering's specified value serializes lowercase" {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "text-rendering", "optimizeLegibility", ""));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("text-rendering", &out);
    try testing.expectEqualStrings("optimizelegibility", out.items);
}

test "text-rendering is initially auto and inherits" {
    const root = try styleOf(testing.allocator, "color: red", null);
    defer root.destroy();
    try expectComputed(root, "auto");
    const parent = try styleOf(testing.allocator, "text-rendering: geometricPrecision", root);
    defer parent.destroy();
    const child = try styleOf(testing.allocator, "color: blue", parent);
    defer child.destroy();
    try expectComputed(child, "geometricprecision");
}

test "text-rendering animates discretely" {
    const a = try styleOf(testing.allocator, "text-rendering: optimizeSpeed", null);
    defer a.destroy();
    const b = try styleOf(testing.allocator, "text-rendering: optimizeLegibility", null);
    defer b.destroy();
    const from = a.get(.text_rendering);
    const to = b.get(.text_rendering);
    try testing.expect(!try css.interpolation.transitionable(testing.allocator, .text_rendering, from, to));
    // Web Animations 1 "discrete": the from value below p = 0.5, the to value from 0.5.
    const early = try css.interpolation.interpolate(testing.allocator, .text_rendering, from, to, 0.4);
    defer early.release();
    try testing.expectEqual(css.style_values.Keyword.optimizespeed, early.keyword);
    const late = try css.interpolation.interpolate(testing.allocator, .text_rendering, from, to, 0.5);
    defer late.release();
    try testing.expectEqual(css.style_values.Keyword.optimizelegibility, late.keyword);
}
