//! Lane anim1 batch 4 (C4, cause 1): transform lists combine as CSS
//! Transforms 1 section 9 and CSS Transforms 2 sections 13-15 say - pad with
//! identity functions, combine pairs sharing a name or primitive (converted
//! to the 2D primitive, or the 3D one when either is 3D), interpolate the
//! rest as decomposed matrices; addition appends; accumulation adds each
//! parameter (scale factors one-based). The individual translate/scale/
//! rotate properties combine by computed value ("as SLERP" for rotate), a
//! `none` side as the identity.
//!
//! Expected values are the WPT expectations, which Chrome, Firefox and
//! Safari pass: css/css-transforms/animation/transform-interpolation-*.html,
//! list-interpolation.html, translate-/scale-/rotate-interpolation.html,
//! transform-composition.html; web-animations/responsive/transform.html.
//! getComputedStyle resolves a transform list to matrix() (six decimals).
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
    // Same functions: argument by argument (16px em: translateX(10em) is
    // 160px).
    .{ Op.interpolate, "transform", "translateX(10em)", "translateX(20em)", 0.2, "matrix(1, 0, 0, 1, 192, 0)" },
    .{ Op.interpolate, "transform", "rotate(0deg)", "rotate(90deg)", 0.5, "matrix(0.707107, 0.707107, -0.707107, 0.707107, 0, 0)" },
    .{ Op.interpolate, "transform", "scale(1)", "scale(3)", 0.5, "matrix(2, 0, 0, 2, 0, 0)" },
    // Derivatives of one primitive: translateX and translateY -> translate.
    .{ Op.interpolate, "transform", "translateX(50px)", "translateY(50px)", 0.5, "matrix(1, 0, 0, 1, 25, 25)" },
    .{ Op.interpolate, "transform", "scaleX(2)", "scaleY(3)", 0.5, "matrix(1.5, 0, 0, 2, 0, 0)" },
    // none and shorter lists pad with identity functions.
    .{ Op.interpolate, "transform", "none", "translate(200px) rotate(720deg)", 0.25, "matrix(-1, 0, 0, -1, 50, 0)" },
    .{ Op.interpolate, "transform", "scale(2)", "none", 0.5, "matrix(1.5, 0, 0, 1.5, 0, 0)" },
    // No common primitive: the rest interpolates as decomposed matrices.
    .{ Op.interpolate, "transform", "translateX(100px)", "scale(2)", 0.5, "matrix(1.5, 0, 0, 1.5, 50, 0)" },
    .{ Op.interpolate, "transform", "translateX(100px) scale(2)", "rotate(180deg)", 0.5, "matrix(0, -1.5, 1.5, 0, 50, 0)" },
    .{ Op.interpolate, "transform", "matrix(1, 0, 0, 1, 0, 0)", "matrix(3, 0, 0, 3, 10, 20)", 0.5, "matrix(2, 0, 0, 2, 5, 10)" },
    // perspective() interpolates as a matrix: -1/400 and -1/500.
    .{ Op.interpolate, "transform", "perspective(400px)", "perspective(500px)", 0.5, "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -0.00225, 0, 0, 0, 1)" },
    // A singular matrix cannot be decomposed: discrete.
    .{ Op.interpolate, "transform", "scale(0)", "rotate(90deg) scaleX(2)", 0.4, "matrix(0, 0, 0, 0, 0, 0)" },
    // Addition appends; accumulation adds parameters, scales one-based.
    .{ Op.add, "transform", "translateX(10px)", "rotate(90deg)", 0, "matrix(0, 1, -1, 0, 10, 0)" },
    .{ Op.accumulate, "transform", "translateX(10px) scale(2)", "translateX(5px) scale(3)", 0, "matrix(4, 0, 0, 4, 15, 0)" },
    // p = 0 is V_A when a list needs the reference box (no padding shows).
    .{ Op.interpolate, "transform", "translateY(70%)", "translateY(90%) scaleZ(2)", 0, "translateY(70%)" },
    // The individual properties; none is the identity, never the result.
    .{ Op.interpolate, "translate", "480px 400px 320px", "240% 160%", 0, "calc(0% + 480px) calc(0% + 400px) 320px" },
    .{ Op.interpolate, "translate", "480px 400px 320px", "240% 160%", 0.125, "calc(30% + 420px) calc(20% + 350px) 280px" },
    .{ Op.interpolate, "scale", "none", "4 3 2", 0, "1" },
    .{ Op.interpolate, "rotate", "none", "z 90deg", 0, "0deg" },
    .{ Op.interpolate, "rotate", "x 0deg", "y 90deg", 0.5, "y 45deg" },
    .{ Op.interpolate, "rotate", "1 0 0 90deg", "0 1 0 90deg", 0.5, "0.707107 0.707107 0 70.5288deg" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "anim1b4: transform lists and the individual transform properties combine" {
    try allCases(testing.allocator);
}

test "anim1b4: combining transforms under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
