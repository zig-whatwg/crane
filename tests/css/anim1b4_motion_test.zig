//! Lane anim1 batch 4 (C4, cause 2): Motion Path values combine "by computed
//! value" (CSS Motion Path 1 2.1-2.5; CSS Values 4 section 3):
//! - offset-rotate: the angle interpolates and adds when both sides have the
//!   same `auto` flag (`reverse` computes to `auto` + 180deg), else discrete;
//! - offset-path ray(): the same <ray-size>, `contain` and presence of `at
//!   <position>` - the angle and the position combine; else discrete;
//! - offset-position / offset-anchor: a <position> as two length-percentages
//!   from the left/top edge, a `right`/`bottom` offset as 100% minus it.
//!
//! Expected values are the WPT expectations, which Chrome, Firefox and
//! Safari pass: css/motion/animation/offset-rotate-interpolation.html,
//! offset-rotate-composition.html, offset-path-interpolation-005.html,
//! offset-path-composition.html, offset-anchor-interpolation.html,
//! offset-position-interpolation.html.
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
    // Motion Path 1 2.5 offset-rotate.
    .{ Op.interpolate, "offset-rotate", "100deg", "180deg", -1, "20deg" },
    .{ Op.interpolate, "offset-rotate", "auto 10deg", "auto 50deg", 0.5, "auto 30deg" },
    .{ Op.interpolate, "offset-rotate", "reverse -170deg", "reverse -130deg", 0.5, "auto 30deg" },
    .{ Op.interpolate, "offset-rotate", "auto 100deg", "reverse", -1, "auto 20deg" },
    .{ Op.interpolate, "offset-rotate", "auto 170deg", "100grad auto", 0.5, "auto 130deg" },
    .{ Op.interpolate, "offset-rotate", "10deg", "auto 50deg", 0.4, "10deg" },
    .{ Op.interpolate, "offset-rotate", "10deg", "auto 50deg", 0.6, "auto 50deg" },
    .{ Op.add, "offset-rotate", "20deg", "10deg", 0, "30deg" },
    .{ Op.add, "offset-rotate", "auto 20deg", "reverse 10deg", 0, "auto 210deg" },
    .{ Op.add, "offset-rotate", "auto 20deg", "10deg", 0, "10deg" },
    // Motion Path 1 2.1.1 ray().
    .{ Op.interpolate, "offset-path", "ray(10deg sides contain)", "ray(50deg sides contain)", -1, "ray(-30deg sides contain)" },
    .{ Op.interpolate, "offset-path", "ray(-10deg farthest-corner at 0% 0px)", "ray(-50deg farthest-corner at 100% 100px)", 0.125, "ray(-15deg farthest-corner at 12.5% 12.5px)" },
    .{ Op.interpolate, "offset-path", "ray(10deg)", "ray(50deg contain)", 0.4, "ray(10deg)" },
    .{ Op.interpolate, "offset-path", "ray(10deg closest-side)", "ray(50deg farthest-side)", 0.6, "ray(50deg farthest-side)" },
    .{ Op.add, "offset-path", "ray(20deg sides)", "ray(10deg sides)", 0, "ray(30deg sides)" },
    .{ Op.add, "offset-path", "ray(20deg closest-corner contain)", "ray(10deg closest-corner)", 0, "ray(10deg closest-corner)" },
    // Motion Path 1 2.3/2.4 with Values 4 9.1: offsets from the left/top edge.
    .{ Op.interpolate, "offset-position", "left 480px top 400px", "right -140% bottom -60%", 0.125, "calc(30% + 420px) calc(20% + 350px)" },
    .{ Op.interpolate, "offset-anchor", "left top", "left 8px bottom 20%", -1, "calc(0% - 8px) -80%" },
    .{ Op.interpolate, "offset-anchor", "left top", "left 8px bottom 20%", 0.125, "calc(0% + 1px) 10%" },
    .{ Op.add, "offset-anchor", "top 20% left 40%", "left 60% top 80%", 0, "100% 100%" },
    .{ Op.interpolate, "offset-anchor", "auto", "10px 20px", 0.4, "auto" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "anim1b4: offset-rotate, ray() and offset positions combine by computed value" {
    try allCases(testing.allocator);
}

test "anim1b4: combining motion path values under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
