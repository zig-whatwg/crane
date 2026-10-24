//! CSS Values4 §10.9 / Images4 §3.3.1: typed conic-position arithmetic.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;
const supported = @hasField(math.Kind, "angle_percentage");

fn expectText(allocator: std.mem.Allocator, expression: *const math.Expression, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try expression.serialize(&out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "angle percentage math preserves its typed percentage hint and unresolved computed percentage" {
    if (comptime !supported) return error.AnglePercentageNotImplemented;
    try roundTrip(testing.allocator);
}

fn roundTrip(allocator: std.mem.Allocator) !void {
    const expression = (try math.parse(allocator, "calc(10deg + 20%)", .{ .kind = .angle_percentage })).?.expression;
    defer expression.unref();
    try testing.expectEqual(math.Base.angle, expression.typ.hint.?);
    try expectText(allocator, expression, "calc(20% + 10deg)");
    const computed = try expression.compute(allocator, .{});
    defer computed.unref();
    try expectText(allocator, computed, "calc(20% + 10deg)");
    try testing.expect(computed.computedNumber() == null);
}

test "angle percentage grammar accepts pure percentages and canonicalizes pure angles" {
    if (comptime !supported) return error.AnglePercentageNotImplemented;
    inline for (.{
        .{ "calc(.25turn + 20deg)", "110deg" },
        .{ "calc(40% - 20%)", "20%" },
    }) |case| {
        const expression = (try math.parse(testing.allocator, case[0], .{ .kind = .angle_percentage })).?.expression;
        defer expression.unref();
        const computed = try expression.compute(testing.allocator, .{});
        defer computed.unref();
        try expectText(testing.allocator, computed, case[1]);
    }
}

test "angle percentage grammar rejects dimensions and incompatible additive types" {
    if (comptime !supported) return error.AnglePercentageNotImplemented;
    inline for (.{ "calc(10deg + 1px)", "calc(2s)", "calc(10% + 2)", "calc(1px)", "calc(10deg * 1deg)" }) |text| {
        const expression = try math.parse(testing.allocator, text, .{ .kind = .angle_percentage });
        defer if (expression) |value| value.expression.unref();
        try testing.expect(expression == null);
    }
}

test "angle percentage parsing and computed copies release every allocation failure" {
    if (comptime !supported) return error.AnglePercentageNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, roundTrip, .{});
}
