//! Lane anim1 batch 5 (per-property leftovers): the individual transform
//! properties' combinations that web-animations interpolation-,
//! addition- and accumulation-per-property-002 check.
//! - rotate: a zero rotation about another axis turns about the other
//!   rotation's NORMALIZED axis ("rotate with different rotation axes":
//!   0 1 1 reads 0 0.707107 0.707107; Chrome 157, Firefox 159 and Safari 27.2
//!   pass all three files' cases);
//! - scale: accumulation adds each component with one subtracted, a + b - 1
//!   ("scale ...": 2 accumulated with -3 is -2; Firefox and Safari pass,
//!   Chrome multiplies - the majority).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const interpolation = css.interpolation;
const Value = css.style_values.Value;

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

fn cases(allocator: Allocator) !void {
    try combined(allocator, .interpolate, "rotate", "0 1 0 0deg", "0 1 1 90deg", 0.5, "0 0.707107 0.707107 45deg");
    try combined(allocator, .add, "rotate", "0 1 0 0deg", "1 1 1 270deg", 0, "0.57735 0.57735 0.57735 270deg");
    try combined(allocator, .accumulate, "rotate", "0 1 0 0deg", "1 1 1 270deg", 0, "0.57735 0.57735 0.57735 270deg");
    // The same axis keeps the authored one.
    try combined(allocator, .interpolate, "rotate", "0 1 0 100deg", "0 1 0 -100deg", 0.25, "y 50deg");
    try combined(allocator, .accumulate, "scale", "2", "-3", 0, "-2");
    try combined(allocator, .accumulate, "scale", "2 2 2", "-1 -2 -3", 0, "0 -1 -2");
    // Addition still multiplies.
    try combined(allocator, .add, "scale", "2", "-3", 0, "-6");
    // translate accumulates as it adds.
    try combined(allocator, .accumulate, "translate", "10px 20px", "5px 5px", 0, "15px 25px");
}

test "anim1b5: individual transforms combine as the per-property files expect" {
    try cases(testing.allocator);
}

test "anim1b5: individual transforms under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, cases, .{});
}
