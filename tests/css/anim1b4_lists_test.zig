//! Lane anim1 batch 4 (C4, cause 3 and 4): pairs, repeatable lists, quads,
//! shadow lists, font-size-adjust and text-indent combine "by computed
//! value" (CSS Values 4 section 3; Web Animations 1 5.2 "by computed value"
//! and "repeatable list"), and a length-percentage mix keeps its mixed type
//! at p = 0 (CSS Values 4 5.6.1; the WPT interpolation files expect
//! `calc(0% + 40px)` at 0 and the plain end value at 1).
//!
//! Each case computes both endpoints through the cascade, combines them with
//! css.interpolation, feeds the result back as a typed declaration (as the
//! animation origin does) and reads the resolved value: the combination AND
//! that the combined computed value computes to itself.
//!
//! Expected values are the WPT expectations, which Chrome, Firefox and Safari
//! pass: web-animations/responsive/{backgroundPosition, backgroundSize,
//! borderImageWidth, borderRadius, font-size-adjust, textIndent}.html,
//! css/css-tables/animations/border-spacing-interpolation.html,
//! css/css-transitions/animations/{text-shadow-interpolation,
//! vertical-align-interpolation}.html,
//! css/motion/animation/offset-distance-interpolation.html.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const interpolation = css.interpolation;

const Op = enum { interpolate, add, accumulate };

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
        .accumulate => try interpolation.accumulate(allocator, l, a.get(l), b.get(l)),
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
    // Backgrounds 3 border-*-radius: a pair, each axis a length-percentage.
    .{ Op.interpolate, "border-top-left-radius", "10px 20px", "30px 40px", 0.5, "20px 30px" },
    .{ Op.interpolate, "border-top-left-radius", "8% 16%", "12% 24%", 0.5, "10% 20%" },
    .{ Op.interpolate, "border-top-left-radius", "0px", "20px 40px", 0.25, "5px 10px" },
    // Tables 3 border-spacing: the same pair.
    .{ Op.interpolate, "border-spacing", "10px", "20px 30px", 0.5, "15px 20px" },
    .{ Op.interpolate, "border-spacing", "0px", "20px", 0.3, "6px" },
    .{ Op.add, "border-spacing", "10px", "5px 1px", 0, "15px 11px" },
    // Web Animations 5.2 repeatable list: background-position-x/-y and
    // background-size repeat to the least common multiple, item by item.
    .{ Op.interpolate, "background-position-x", "10%", "20%", 0.5, "15%" },
    .{ Op.interpolate, "background-position-x", "0px, 10px", "20px", 0.5, "10px, 15px" },
    .{ Op.interpolate, "background-position-y", "10px", "30%", 0.5, "calc(15% + 5px)" },
    .{ Op.interpolate, "background-size", "10px 20px", "30px 40px", 0.5, "20px 30px" },
    .{ Op.interpolate, "background-size", "auto 20px", "auto 40px", 0.5, "auto 30px" },
    // `auto` combines only with `auto`: discrete.
    .{ Op.interpolate, "background-size", "auto", "10px", 0.4, "auto" },
    .{ Op.interpolate, "background-size", "auto", "10px", 0.6, "10px" },
    // Backgrounds 3 border-image-width: side by side, numbers with numbers.
    .{ Op.interpolate, "border-image-width", "300px 30px", "100px 10px", 0.5, "200px 20px" },
    .{ Op.interpolate, "border-image-width", "1", "3", 0.5, "2" },
    .{ Op.interpolate, "border-image-width", "1", "10px", 0.4, "1" },
    // Text Decoration 3 text-shadow: a shadow list, padded with transparent
    // zero shadows.
    .{ Op.interpolate, "text-shadow", "rgb(0, 0, 0) 10px 10px 10px", "rgb(200, 100, 0) 30px 30px 30px", 0.5, "rgb(100, 50, 0) 20px 20px 20px" },
    .{ Op.interpolate, "text-shadow", "none", "rgb(200, 100, 0) 20px 20px 20px", 0.5, "rgba(200, 100, 0, 0.5) 10px 10px 10px" },
    .{ Op.add, "text-shadow", "rgb(0, 0, 0) 1px 1px 1px", "rgb(255, 0, 0) 2px 2px 2px", 0, "rgb(0, 0, 0) 1px 1px 1px, rgb(255, 0, 0) 2px 2px 2px" },
    .{ Op.accumulate, "text-shadow", "rgb(10, 10, 10) 1px 1px 1px", "rgb(20, 20, 20) 2px 2px 2px", 0, "rgb(30, 30, 30) 3px 3px 3px" },
    // Fonts 5 font-size-adjust: by computed value when the metrics match.
    .{ Op.interpolate, "font-size-adjust", "2", "6", 0.25, "3" },
    .{ Op.interpolate, "font-size-adjust", "none", "6", 0.25, "none" },
    // Text 3 text-indent: by computed value when the keywords match.
    .{ Op.interpolate, "text-indent", "100px hanging each-line", "200px hanging each-line", 0.5, "150px hanging each-line" },
    .{ Op.interpolate, "text-indent", "100px", "200px hanging", 0.4, "100px" },
    // Values 4 5.6.1: a mix keeps the percentage at p = 0; p = 1 is V_B.
    .{ Op.interpolate, "vertical-align", "40px", "40%", 0, "calc(0% + 40px)" },
    .{ Op.interpolate, "vertical-align", "40px", "40%", 1, "40%" },
    .{ Op.interpolate, "vertical-align", "40px", "40%", 0.3, "calc(12% + 28px)" },
    .{ Op.interpolate, "offset-distance", "10px", "100%", 0, "calc(0% + 10px)" },
    // One unit on both sides stays a plain length at p = 0.
    .{ Op.interpolate, "vertical-align", "40px", "10px", 0, "40px" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "anim1b4: pairs, repeatable lists, quads and shadow lists combine by computed value" {
    try allCases(testing.allocator);
}

test "anim1b4: combining pairs and lists under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
