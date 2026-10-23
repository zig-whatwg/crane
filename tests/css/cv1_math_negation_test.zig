//! Unary composition must preserve the owned numeric tree, not reparse its text.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;
const has_api = @hasDecl(math.Expression, "negated");

test "negating an angle preserves the specified source and owns the resulting tree" {
    if (comptime !has_api) return error.MathNegationNotImplemented;
    const original = (try math.parse(testing.allocator, "calc(10deg)", .{ .kind = .angle })).?.expression;
    const negative = original.negated(testing.allocator) catch |err| {
        original.unref();
        return err;
    };
    defer negative.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    original.serialize(&out, testing.allocator) catch |err| {
        original.unref();
        return err;
    };
    original.unref();
    try testing.expectEqualStrings("calc(10deg)", out.items);
    out.clearRetainingCapacity();
    try negative.serialize(&out, testing.allocator);
    try testing.expectEqualStrings("calc(-10deg)", out.items);
}

test "negated dimensional arithmetic resolves using the supplied computation context" {
    if (comptime !has_api) return error.MathNegationNotImplemented;
    const original = (try math.parse(testing.allocator, "calc(1em / 1px * 10deg)", .{ .kind = .angle })).?.expression;
    defer original.unref();
    const negative = try original.negated(testing.allocator);
    defer negative.unref();
    const computed = try negative.compute(testing.allocator, .{ .font_size = 2 });
    defer computed.unref();
    try testing.expectEqual(math.Unit.deg, computed.computedNumber().?.unit);
    try testing.expectEqual(@as(f64, -20), computed.computedNumber().?.value);
}

test "negation releases every failed owned tree construction" {
    if (comptime !has_api) return error.MathNegationNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    const original = (try math.parse(allocator, "calc(1em / 1px * 10deg)", .{ .kind = .angle })).?.expression;
    defer original.unref();
    const negative = try original.negated(allocator);
    defer negative.unref();
    const computed = try negative.compute(allocator, .{ .font_size = 2 });
    defer computed.unref();
    try testing.expectEqual(@as(f64, -20), computed.computedNumber().?.value);
}
