//! Conditional5 §7: elementless contexts have no eligible query container.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "container lengths parse and use small viewport axes without an eligible container" {
    inline for (.{
        .{ "cqw", 8.0 }, .{ "cqh", 6.0 },   .{ "cqi", 8.0 },
        .{ "cqb", 6.0 }, .{ "cqmin", 6.0 }, .{ "cqmax", 8.0 },
    }) |case| {
        const text = "calc(1" ++ case[0] ++ ")";
        const parsed = (try css.math_values.parse(testing.allocator, text, .{ .kind = .length })) orelse return error.ContainerUnitMissing;
        defer parsed.expression.unref();
        const result = try parsed.expression.compute(testing.allocator, .{ .viewport_width = 800, .viewport_height = 600 });
        defer result.unref();
        const number = result.computedNumber() orelse return error.ContainerUnitNotComputed;
        try testing.expectEqual(css.math_values.Unit.px, number.unit);
        try testing.expectEqual(@as(f64, case[1]), number.value);
    }
}

test "container logical fallback follows viewport writing mode and minmax uses both axes" {
    inline for (.{ .{ "cqi", 6.0 }, .{ "cqb", 8.0 }, .{ "cqmin", 6.0 }, .{ "cqmax", 8.0 } }) |case| {
        const parsed = (try css.math_values.parse(testing.allocator, "calc(1" ++ case[0] ++ ")", .{ .kind = .length })) orelse return error.ContainerUnitMissing;
        defer parsed.expression.unref();
        const result = try parsed.expression.compute(testing.allocator, .{ .viewport_width = 800, .viewport_height = 600, .viewport_vertical = true });
        defer result.unref();
        try testing.expectEqual(@as(f64, case[1]), result.computedNumber().?.value);
    }
}

test "container eligibility defaults to none on every axis while container type is unsupported" {
    if (comptime !@hasDecl(css.math_values.Context, "containerEligibility")) return error.ContainerEligibilityQueryMissing;
    const context = css.math_values.Context{};
    inline for (.{ .width, .height, .inline_axis, .block_axis }) |axis|
        try testing.expectEqual(.no_eligible_container, context.containerEligibility(axis));
}

test "container units are accepted as ordinary property lengths and elementless numeric values" {
    inline for (.{ "cqw", "cqh", "cqi", "cqb", "cqmin", "cqmax" }) |unit| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer assignments.deinit(testing.allocator);
        defer for (assignments.items) |assignment| assignment.value.release();
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .margin_left }, "2" ++ unit, &assignments));
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        const expression = (try css.math_values.parse(testing.allocator, "calc(1" ++ unit ++ " / 1px)", .{ .kind = .number })) orelse return error.ContainerUnitMissing;
        defer expression.expression.unref();
        const value = try expression.expression.compute(testing.allocator, .{});
        defer value.unref();
        try testing.expect(value.computedNumber() != null);
    }
}
