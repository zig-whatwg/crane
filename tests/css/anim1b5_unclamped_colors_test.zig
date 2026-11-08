//! Lane anim1 batch 5 (item 1): colors are not clamped mid-computation.
//! CSS Values 4 3.1: "clamping is only applied to the *final* result of
//! applying all interpolation-related operations", so a color that addition,
//! accumulation or interpolation carries out of range stays out of range
//! until the final value (css.interpolation.clampFinal), and a non-integral
//! channel is not rounded until then.
//!
//! Expected values follow the WPT expectations Chrome 157, Firefox 159 and
//! Safari 27.2 all pass (wpt.fyi aligned stable run 8c04fb8d43):
//! web-animations/animation-model/animation-types/addition-per-property-001
//! "... as color of rgb() with overflowed from and to values" (rgb(128, 128,
//! 128) + rgb(255, 0, 0) and + rgb(0, 0, 255), interpolated at 0.5, is
//! rgb(255, 128, 255), not rgb(192, 128, 192)) and
//! keyframe-effects/effect-value-iteration-composite-operation (color,
//! box-shadow and drop-shadow() accumulated past 255 in the third iteration).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const interpolation = css.interpolation;
const Value = css.style_values.Value;

fn computeOne(allocator: Allocator, name: []const u8, text: []const u8) !*Style {
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, name, text, "")) return error.Rejected;
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

/// The computed value of `name: text`, OWNED.
fn computed(allocator: Allocator, l: css.properties.Longhand, name: []const u8, text: []const u8) !Value {
    const style = try computeOne(allocator, name, text);
    defer style.destroy();
    const v = style.get(l);
    v.retain();
    return v;
}

/// `raw` (OWNED, consumed) as the final value of `l`, serialized as
/// getComputedStyle returns it.
fn expectFinal(allocator: Allocator, l: css.properties.Longhand, raw: Value, expected: []const u8) !void {
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
    try testing.expectEqualStrings(expected, out.items);
}

const Op = enum { add, accumulate };

/// interpolate(op(u1, v1), op(u2, v2), p): two composited keyframes, then
/// their interpolation, as an additive effect computes them.
fn compositeThenInterpolate(allocator: Allocator, name: []const u8, op: Op, under1: []const u8, value1: []const u8, under2: []const u8, value2: []const u8, p: f64, expected: []const u8) !void {
    const l = (css.properties.lookup(name) orelse return error.Unknown).longhand;
    const values = [_][]const u8{ under1, value1, under2, value2 };
    var parsed: [4]Value = undefined;
    var made: usize = 0;
    defer for (parsed[0..made]) |v| v.release();
    for (values) |text| {
        parsed[made] = try computed(allocator, l, name, text);
        made += 1;
    }
    const a = switch (op) {
        .add => try interpolation.add(allocator, l, parsed[0], parsed[1]),
        .accumulate => try interpolation.accumulate(allocator, l, parsed[0], parsed[1]),
    };
    defer a.release();
    const b = switch (op) {
        .add => try interpolation.add(allocator, l, parsed[2], parsed[3]),
        .accumulate => try interpolation.accumulate(allocator, l, parsed[2], parsed[3]),
    };
    defer b.release();
    try expectFinal(allocator, l, try interpolation.interpolate(allocator, l, a, b, p), expected);
}

fn longhandCases(allocator: Allocator) !void {
    // addition-per-property-001 "overflowed": 383 and 383 stay; 255.5 clamps
    // to 255 only at the end.
    try compositeThenInterpolate(allocator, "background-color", .add, "rgb(128, 128, 128)", "rgb(255, 0, 0)", "rgb(128, 128, 128)", "rgb(0, 0, 255)", 0.5, "rgb(255, 128, 255)");
    try compositeThenInterpolate(allocator, "color", .accumulate, "rgb(128, 128, 128)", "rgb(255, 0, 0)", "rgb(128, 128, 128)", "rgb(0, 0, 255)", 0.5, "rgb(255, 128, 255)");
    // An overflowed keyframe interpolated back into range: 400 -> 0 at 0.5
    // is 200 (a clamped 255 would give 128).
    try compositeThenInterpolate(allocator, "color", .add, "rgb(200, 200, 200)", "rgb(200, 200, 200)", "rgb(0, 0, 0)", "rgb(0, 0, 0)", 0.5, "rgb(200, 200, 200)");
    // The third iteration of effect-value-iteration-composite's <color>
    // case: 240 -> 360 at 0.5 is 300, clamped at the end.
    try compositeThenInterpolate(allocator, "color", .accumulate, "rgb(120, 120, 120)", "rgb(120, 120, 120)", "rgb(240, 240, 240)", "rgb(120, 120, 120)", 0.5, "rgb(255, 255, 255)");
    // Shadows and drop-shadow() colors the same way (Backgrounds 3 6.1;
    // Filter Effects 1 11).
    try compositeThenInterpolate(allocator, "box-shadow", .accumulate, "rgb(200, 200, 200) 10px 10px 10px 0px", "rgb(200, 200, 200) 10px 10px 10px 0px", "rgb(0, 0, 0) 0px 0px 0px 0px", "rgb(0, 0, 0) 0px 0px 0px 0px", 0.5, "rgb(200, 200, 200) 10px 10px 10px 0px");
    try compositeThenInterpolate(allocator, "text-shadow", .accumulate, "rgb(200, 200, 200) 10px 10px 10px", "rgb(200, 200, 200) 10px 10px 10px", "rgb(0, 0, 0) 0px 0px 0px", "rgb(0, 0, 0) 0px 0px 0px", 0.5, "rgb(200, 200, 200) 10px 10px 10px");
    try compositeThenInterpolate(allocator, "filter", .accumulate, "drop-shadow(rgb(200, 200, 200) 10px 10px 10px)", "drop-shadow(rgb(200, 200, 200) 10px 10px 10px)", "drop-shadow(rgb(0, 0, 0) 0px 0px 0px)", "drop-shadow(rgb(0, 0, 0) 0px 0px 0px)", 0.5, "drop-shadow(rgb(200, 200, 200) 10px 10px 10px)");
    // A channel is not rounded mid-computation: 0.5 + 0.5 is 1, where
    // rounding each half up first would give 2.
    {
        const l: css.properties.Longhand = .color;
        const black = try computed(allocator, l, "color", "rgb(0, 0, 0)");
        defer black.release();
        const one = try computed(allocator, l, "color", "rgb(1, 1, 1)");
        defer one.release();
        const half = try interpolation.interpolate(allocator, l, black, one, 0.5);
        defer half.release();
        try expectFinal(allocator, l, try interpolation.add(allocator, l, half, half), "rgb(1, 1, 1)");
    }
    // Alpha stays in [0, 1] (premultiplied channels over it): rgb(128, 128,
    // 128) + rgba(255, 0, 0, 0.4) is rgb(230, 128, 128) (property-types.js
    // "#RGBa"), and extrapolation still clamps at the end.
    try compositeThenInterpolate(allocator, "color", .add, "rgb(128, 128, 128)", "rgba(255, 0, 0, 0.4)", "rgb(128, 128, 128)", "rgba(255, 0, 0, 0.4)", 0.5, "rgb(230, 128, 128)");
    {
        const l: css.properties.Longhand = .color;
        const black = try computed(allocator, l, "color", "rgb(0, 0, 0)");
        defer black.release();
        const white = try computed(allocator, l, "color", "rgb(255, 255, 255)");
        defer white.release();
        try expectFinal(allocator, l, try interpolation.interpolate(allocator, l, black, white, 1.5), "rgb(255, 255, 255)");
        try expectFinal(allocator, l, try interpolation.interpolate(allocator, l, black, white, 0.3), "rgb(77, 77, 77)");
    }
}

test "anim1b5: colors stay unclamped until the final value" {
    try longhandCases(testing.allocator);
}

test "anim1b5: unclamped colors under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, longhandCases, .{});
}

test "anim1b5: the final value of an unclamped color is the legacy color it serializes as" {
    const allocator = testing.allocator;
    const l: css.properties.Longhand = .color;
    const grey = try computed(allocator, l, "color", "rgb(200, 200, 200)");
    defer grey.release();
    const sum = try interpolation.add(allocator, l, grey, grey);
    const final = interpolation.clampFinal(l, sum);
    defer final.release();
    // The final value is an ordinary legacy color again (CSS Color 4 12.1),
    // so a later transition compares it with rgb(255, 255, 255) as equal.
    try testing.expect(final == .color and final.color == .rgba);
    try testing.expectEqual(@as(u8, 255), final.color.rgba.r);
}

// ----------------------------------------------------------------------------
// Registered custom properties (CSS Properties and Values API 1 2.5): a <color>
// syntax combines as the color properties, unclamped between steps.
// ----------------------------------------------------------------------------

fn syntaxValue(allocator: Allocator, definition: *const css.syntax_definitions.Definition, text: []const u8) !css.syntax_values.Value {
    var specified = (try definition.parseValue(.{ .allocator = allocator }, text)) orelse return error.Rejected;
    defer specified.deinit();
    return specified.compute(allocator, .{});
}

fn syntaxCases(allocator: Allocator) !void {
    var definition = try css.syntax_definitions.parse(allocator, "<color>+");
    defer definition.deinit();
    // custom-property-animation-color-space-list's iterationComposite case:
    // keyframes [0, 0] -> [50, 100] in the third iteration are [100, 200] ->
    // [150, 300]; at 0.5 the second item, 200 -> 300, is 250.
    var zero = try syntaxValue(allocator, &definition, "rgb(0, 0, 0) rgb(0, 0, 0)");
    defer zero.deinit();
    var last = try syntaxValue(allocator, &definition, "rgb(50, 50, 50) rgb(100, 100, 100)");
    defer last.deinit();
    var twice = (try interpolation.combineSyntax(allocator, &last, &last, 1, .accumulate)).?;
    defer twice.deinit();
    var from = (try interpolation.combineSyntax(allocator, &twice, &zero, 1, .accumulate)).?;
    defer from.deinit();
    var to = (try interpolation.combineSyntax(allocator, &twice, &last, 1, .accumulate)).?;
    defer to.deinit();
    var mid = (try interpolation.combineSyntax(allocator, &from, &to, 0.5, .interpolate)).?;
    defer mid.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try mid.serialize(&out, allocator);
    try testing.expectEqualStrings("rgb(125, 125, 125) rgb(250, 250, 250)", out.items);
}

test "anim1b5: a registered <color> list accumulates past 255 and comes back" {
    try syntaxCases(testing.allocator);
}

test "anim1b5: registered colors under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, syntaxCases, .{});
}
