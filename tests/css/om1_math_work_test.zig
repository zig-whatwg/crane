//! Q233: isolate parsed-tree allocation work from math correctness controls.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;
const a = testing.allocator;

fn inputFor(storage: []u8, index: usize) ![]const u8 {
    return std.fmt.bufPrint(storage, "calc({d}px + 1em)", .{index});
}

fn expectedFor(storage: []u8, index: usize) ![]const u8 {
    return std.fmt.bufPrint(storage, "calc(1em + {d}px)", .{index});
}

fn computedFor(storage: []u8, index: usize) ![]const u8 {
    return std.fmt.bufPrint(storage, "{d}px", .{index + 16});
}

test "Q233 parse work for 1000 two-child calc expressions stays within the 3000-call budget" {
    var counted = testing.FailingAllocator.init(a, .{});
    const allocator = counted.allocator();
    for (0..1000) |index| {
        var input_storage: [48]u8 = undefined;
        const input = try inputFor(&input_storage, index);
        const parsed = (try math.parse(allocator, input, .{ .kind = .length })) orelse return error.Parse;
        parsed.expression.unref();
    }
    try testing.expectEqual(counted.allocated_bytes, counted.freed_bytes);
    // On the pre-fix tree this failure reports expected 3000, found 4000.
    // Keep serialization and compute allocations out of this measurement.
    if (counted.allocations > 3000) try testing.expectEqual(@as(usize, 3000), counted.allocations);
}

test "Q233 1000 calc controls preserve type, specified bytes, and computed values" {
    for (0..1000) |index| {
        var input_storage: [48]u8 = undefined;
        var specified_storage: [48]u8 = undefined;
        var computed_storage: [48]u8 = undefined;
        const input = try inputFor(&input_storage, index);
        const specified = try expectedFor(&specified_storage, index);
        const computed_expected = try computedFor(&computed_storage, index);
        const parsed = (try math.parse(a, input, .{ .kind = .length })) orelse return error.Parse;
        defer parsed.expression.unref();
        try testing.expectEqual(input.len, parsed.consumed);
        try testing.expect(parsed.expression.typ.eql(math.Type.one(.length)));

        var specified_actual: std.ArrayList(u8) = .empty;
        defer specified_actual.deinit(a);
        try parsed.expression.serialize(&specified_actual, a);
        try testing.expectEqualStrings(specified, specified_actual.items);

        const result = try parsed.expression.compute(a, .{ .font_size = 16 });
        defer result.unref();
        const number = result.computedNumber() orelse return error.NotComputedScalar;
        try testing.expectEqual(math.Unit.px, number.unit);
        try testing.expectEqual(@as(f64, @floatFromInt(index + 16)), number.value);
        var computed_actual: std.ArrayList(u8) = .empty;
        defer computed_actual.deinit(a);
        try result.serialize(&computed_actual, a);
        try testing.expectEqualStrings(computed_expected, computed_actual.items);
    }
}

fn checkCase(allocator: std.mem.Allocator, input: []const u8, specified: []const u8, computed: []const u8, value: f64, hint: ?math.Base) !void {
    const parsed = (try math.parse(allocator, input, .{ .kind = .length_percentage })) orelse return error.Parse;
    defer parsed.expression.unref();
    var expected_type = math.Type.one(.length);
    expected_type.hint = hint;
    try testing.expect(parsed.expression.typ.eql(expected_type));
    var specified_actual: std.ArrayList(u8) = .empty;
    defer specified_actual.deinit(allocator);
    try parsed.expression.serialize(&specified_actual, allocator);
    try testing.expectEqualStrings(specified, specified_actual.items);

    const result = try parsed.expression.compute(allocator, .{ .font_size = 16, .percentage_basis = 100 });
    defer result.unref();
    const number = result.computedNumber() orelse return error.NotComputedScalar;
    try testing.expectEqual(math.Unit.px, number.unit);
    try testing.expectEqual(value, number.value);
    var computed_actual: std.ArrayList(u8) = .empty;
    defer computed_actual.deinit(allocator);
    try result.serialize(&computed_actual, allocator);
    try testing.expectEqualStrings(computed, computed_actual.items);
}

test "Q233 exact flatten expansion covers nested sums products and negate-sum" {
    try checkCase(a, "calc(1px + (2px + 3em) + 4%)", "calc(4% + 3em + 3px)", "55px", 55, .length);
    // §10.10.1 step 9.1: the mixed-unit child product survives until flattening.
    try checkCase(a, "calc(2 * (3px * 4em) / 1em)", "calc(24px)", "24px", 24, null);
    // Steps 6.3/8.1: negate the inner sum before flattening the outer sum.
    try checkCase(a, "calc(0px - (1px + 2em))", "calc(-2em - 1px)", "-33px", -33, null);
}

test "Q233 allocation failures release a nested math parse and computation" {
    try testing.checkAllAllocationFailures(a, allocationFailures, .{});
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    try checkCase(allocator, "calc(1px + (2px + 3em) + 4%)", "calc(4% + 3em + 3px)", "55px", 55, .length);
}
