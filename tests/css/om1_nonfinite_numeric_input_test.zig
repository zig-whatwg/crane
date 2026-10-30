//! Typed OM §5.3 and CSS Values4 §10.12; liaison Q81,2026-10-27.
//! Chrome156/Safari27 arithmetic keeps non-finite results. Split property
//! writes follow the spec; no second parser and no geometry limit.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Case = struct { property: []const u8, value: f64, unit: css.math_values.Unit, text: []const u8, computed: f64 };

fn check(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_numeric") or !@hasDecl(css.properties, "parseTypedNumeric")) return std.testing.expect(false);
    const Reader = struct {
        number: css.math_values.Numeric,
        pub fn view(self: @This(), _: usize) !css.typed_om.numeric_ops.View {
            return .{ .kind = .unit, .number = self.number };
        }
        pub fn child(_: @This(), _: usize, _: usize) !usize {
            return error.Invalid;
        }
    };
    const source = try css.typed_om.native_numeric.snapshot(allocator, 0, Reader{ .number = .{ .value = case.value, .unit = case.unit } });
    defer source.deinit();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseTypedNumeric(.{ .allocator = allocator }, (css.properties.lookup(case.property) orelse return error.MissingProperty), .{ .expression = source, .is_unit = true }, &assignments));
    try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
    const expression = assignments.items[0].value.value.calculation;
    try std.testing.expect(expression.wrapper);
    if (std.math.isNan(case.value)) try std.testing.expect(std.math.isNan(expression.root.numeric.value)) else try std.testing.expectEqual(case.value, expression.root.numeric.value);
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(allocator);
    try css.properties.serializeAssigned(assignments.items[0].longhand, assignments.items[0].value, &serialized, allocator);
    try std.testing.expectEqualStrings(case.text, serialized.items);
    const computed = try expression.compute(allocator, .{});
    defer computed.unref();
    const number = computed.computedNumber() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(case.computed, number.value);
    try std.testing.expectEqual(case.unit, number.unit);
    // Assignment is a copy: neither its range processing nor deinit can
    // mutate the borrowed live CSSUnitValue snapshot.
    if (std.math.isNan(case.value)) try std.testing.expect(std.math.isNan(source.root.numeric.value)) else try std.testing.expectEqual(case.value, source.root.numeric.value);
}

test "Q81 positive infinite width keeps a math wrapper and existing finite representation limit" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "width", .value = std.math.inf(f64), .unit = .px, .text = "calc(infinity * 1px)", .computed = std.math.floatMax(f64) }});
}
test "Q81 negative infinite width wraps before its existing minimum is applied" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "width", .value = -std.math.inf(f64), .unit = .px, .text = "calc(-infinity * 1px)", .computed = 0 }});
}
test "Q81 NaN width preserves specified NaN and computes zero" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "width", .value = std.math.nan(f64), .unit = .px, .text = "calc(NaN * 1px)", .computed = 0 }});
}
test "Q81 positive infinite z-index wraps and computes the existing integer maximum" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "z-index", .value = std.math.inf(f64), .unit = .number, .text = "calc(infinity)", .computed = 2147483647 }});
}
test "Q81 negative infinite z-index wraps and computes the existing integer minimum" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "z-index", .value = -std.math.inf(f64), .unit = .number, .text = "calc(-infinity)", .computed = -2147483648 }});
}
test "Q81 NaN z-index preserves its specified math value and computes zero" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "z-index", .value = std.math.nan(f64), .unit = .number, .text = "calc(NaN)", .computed = 0 }});
}
test "Q81 positive infinite opacity wraps and computes one" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "opacity", .value = std.math.inf(f64), .unit = .number, .text = "calc(infinity)", .computed = 1 }});
}
test "Q81 negative infinite opacity wraps and computes zero" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "opacity", .value = -std.math.inf(f64), .unit = .number, .text = "calc(-infinity)", .computed = 0 }});
}
test "Q81 NaN opacity preserves its specified math value and computes zero" {
    try std.testing.checkAllAllocationFailures(a, check, .{Case{ .property = "opacity", .value = std.math.nan(f64), .unit = .number, .text = "calc(NaN)", .computed = 0 }});
}
