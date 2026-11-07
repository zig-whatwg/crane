//! Lane anim1 batch 4 (C4, cause 8): font-palette interpolates as a
//! palette-mix() inside (0, 1) and keeps each endpoint outside it, equal
//! palettes simplifying to the palette (CSS Fonts 4 9.1-9.2); font-variation-
//! settings with the same axis tags interpolates each value as a number.
//!
//! Expected values are the WPT expectations: css/css-fonts/animations/
//! font-palette-interpolation.html (Chrome and Safari pass it), web-animations/
//! animation-model/animation-types/interpolation-per-property-001.html.
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
    .{ Op.interpolate, "font-palette", "light", "dark", 0.3, "palette-mix(light 70%, dark 30%)" },
    .{ Op.interpolate, "font-palette", "light", "dark", -0.25, "light" },
    .{ Op.interpolate, "font-palette", "light", "dark", 1.5, "dark" },
    .{ Op.interpolate, "font-palette", "normal", "normal", 0.3, "normal" },
    .{ Op.interpolate, "font-variation-settings", "\"wght\" 1.1", "\"wght\" 1.5", 0.25, "\"wght\" 1.2" },
    .{ Op.interpolate, "font-variation-settings", "\"wght\" 1", "\"wdth\" 5", 0.4, "\"wght\" 1" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "anim1b4: font-palette and font-variation-settings combine" {
    try allCases(testing.allocator);
}

test "anim1b4: combining font values under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
