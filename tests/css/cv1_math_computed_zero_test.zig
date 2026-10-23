//! Q100 / CSSWG #3482: computed length zero and percentage zero are asymmetric.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;

fn expression(allocator: std.mem.Allocator, input: []const u8) !*math.Expression {
    const parsed = try math.parse(allocator, input, .{ .kind = .length_percentage }) orelse return error.InvalidMath;
    errdefer parsed.expression.unref();
    try testing.expectEqual(input.len, parsed.consumed);
    return parsed.expression;
}

fn serialize(value: *const math.Expression, expected: []const u8, allocator: std.mem.Allocator) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try value.serialize(&text, allocator);
    try testing.expectEqualStrings(expected, text.items);
}

test "computed zero lengths beside a percentage canonicalize without changing the specified value or hint" {
    inline for (.{ "calc(10% + 0px)", "calc(10% - 0px)", "calc(10% + 0em)", "calc(10% + 0vw)" }) |input| {
        const authored = try expression(testing.allocator, input);
        defer authored.unref();
        var before: std.ArrayList(u8) = .empty;
        defer before.deinit(testing.allocator);
        try authored.serialize(&before, testing.allocator);
        try testing.expect(std.mem.indexOf(u8, before.items, "10%") != null);
        try testing.expect(std.mem.indexOf(u8, before.items, if (std.mem.indexOf(u8, input, "em") != null) "0em" else if (std.mem.indexOf(u8, input, "vw") != null) "0vw" else "0px") != null);
        const computed = try authored.compute(testing.allocator, .{});
        defer computed.unref();
        try serialize(computed, "10%", testing.allocator);
        try testing.expectEqualDeep(authored.typ, computed.typ);
        try testing.expectEqual(math.Base.length, computed.typ.hint.?);
        try serialize(authored, before.items, testing.allocator);
        const percentage = try expression(testing.allocator, "calc(10%)");
        defer percentage.unref();
        const canonical = try percentage.compute(testing.allocator, .{});
        defer canonical.unref();
        try testing.expect(computed.eql(canonical));
    }
}

test "zero percentages nonzero lengths and unresolved functions remain in computed sums" {
    const cases = .{
        .{ "calc(0% + 10px)", "calc(0% + 10px)" },
        .{ "calc(10% + 1px)", "calc(10% + 1px)" },
        .{ "calc(10% + 1cap)", "calc(10% + 1cap)" },
        .{ "calc(10% + 0cap)", "calc(10% + 0cap)" },
        .{ "calc(10% + 0px + sign(10%) * 1px)", "calc(10% + 0px + (1px * sign(10%)))" },
        .{ "min(10% + 0px, 20%)", "min(10% + 0px, 20%)" },
        .{ "clamp(0px, 10% + 0px, 20px)", "clamp(0px, 10% + 0px, 20px)" },
    };
    inline for (cases) |case| {
        const authored = try expression(testing.allocator, case[0]);
        defer authored.unref();
        const computed = try authored.compute(testing.allocator, .{});
        defer computed.unref();
        try serialize(computed, case[1], testing.allocator);
    }
}

test "computed percentage canonicalization releases allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    const authored = try expression(allocator, "calc(10% + 0em)");
    defer authored.unref();
    const computed = try authored.compute(allocator, .{});
    defer computed.unref();
    try serialize(computed, "10%", allocator);
}
