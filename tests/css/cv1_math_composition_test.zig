//! Pure expression composition for positions and shape value consumers.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;
const has_api = @hasDecl(math, "compose") and @hasDecl(math, "ComposeOperation");

fn expectText(allocator: std.mem.Allocator, expression: *const math.Expression, expected: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try expression.serialize(&text, allocator);
    try testing.expectEqualStrings(expected, text.items);
}

test "numeric composition owns its operands and preserves position percentage hints" {
    if (comptime !has_api) return error.MathCompositionNotImplemented;
    try complementRoundTrip(testing.allocator);
}

fn complementRoundTrip(allocator: std.mem.Allocator) !void {
    const composed = blk: {
        const left = (try math.parse(allocator, "calc(100%)", .{ .kind = .length_percentage })).?.expression;
        defer left.unref();
        const right = (try math.parse(allocator, "calc(10% + 1em)", .{ .kind = .length_percentage })).?.expression;
        defer right.unref();
        const result = (try math.compose(allocator, .{ .kind = .length_percentage }, .sub, left, right)) orelse return error.InvalidComposition;
        errdefer result.unref();
        // Construction and simplification must not negate or merge the source.
        try expectText(allocator, left, "calc(100%)");
        try expectText(allocator, right, "calc(10% + 1em)");
        break :blk result;
    };
    defer composed.unref();
    try testing.expectEqual(math.Base.length, composed.typ.hint.?);
    const computed = try composed.compute(allocator, .{ .font_size = 20 });
    defer computed.unref();
    try expectText(allocator, computed, "calc(90% - 20px)");
}

test "numeric composition adds values through the existing simplifier and outer range" {
    if (comptime !has_api) return error.MathCompositionNotImplemented;
    const left = (try math.parse(testing.allocator, "calc(-4)", .{ .kind = .number })).?.expression;
    defer left.unref();
    const right = (try math.parse(testing.allocator, "calc(1)", .{ .kind = .number })).?.expression;
    defer right.unref();
    const sum = (try math.compose(testing.allocator, .{ .kind = .number, .minimum = 0 }, .add, left, right)).?;
    defer sum.unref();
    try expectText(testing.allocator, sum, "calc(-3)");
    const computed = try sum.compute(testing.allocator, .{});
    defer computed.unref();
    try testing.expectEqual(@as(f64, 0), computed.computedNumber().?.value);
}

test "numeric composition rejects incompatible units destination types and percentage hints" {
    if (comptime !has_api) return error.MathCompositionNotImplemented;
    const length = (try math.parse(testing.allocator, "calc(10px)", .{ .kind = .length })).?.expression;
    defer length.unref();
    const time = (try math.parse(testing.allocator, "calc(2s)", .{ .kind = .time })).?.expression;
    defer time.unref();
    const percent = (try math.parse(testing.allocator, "calc(10%)", .{ .kind = .percentage })).?.expression;
    defer percent.unref();
    const invalid_units = try math.compose(testing.allocator, .{ .kind = .length }, .add, length, time);
    defer if (invalid_units) |value| value.unref();
    try testing.expect(invalid_units == null);
    const invalid_destination = try math.compose(testing.allocator, .{ .kind = .number }, .sub, length, length);
    defer if (invalid_destination) |value| value.unref();
    try testing.expect(invalid_destination == null);
    const invalid_hint = try math.compose(testing.allocator, .{ .kind = .length_percentage }, .add, percent, percent);
    defer if (invalid_hint) |value| value.unref();
    try testing.expect(invalid_hint == null);
}

test "numeric composition releases every allocation failure after cloning operands" {
    if (comptime !has_api) return error.MathCompositionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, complementRoundTrip, .{});
}
