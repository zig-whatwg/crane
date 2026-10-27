//! CSS Typed OM 1 §§4.3.2–3, 6.4: numeric leaf units and serialization.
const std = @import("std");
const css = @import("css");

test "Typed OM units normalize ASCII case without parsing CSS escapes" {
    if (comptime !@hasDecl(css, "typed_om")) return std.testing.expect(false);
    const numeric = css.typed_om.numeric;
    for ([_][]const u8{ "px", "PX", "pX" }) |unit| {
        try std.testing.expectEqual(css.math_values.Unit.px, numeric.parseUnit(unit).?);
    }
    try std.testing.expectEqual(css.math_values.Unit.hz, numeric.parseUnit("Hz").?);
    try std.testing.expectEqual(css.math_values.Unit.x, numeric.parseUnit("x").?);
    try std.testing.expectEqual(css.math_values.Unit.x, numeric.parseUnit("X").?);
    try std.testing.expectEqual(css.math_values.Unit.number, numeric.parseUnit("number").?);
    try std.testing.expectEqual(css.math_values.Unit.percent, numeric.parseUnit("percent").?);
    for ([_][]const u8{ "", " px", "px ", "%", "NUMBER", "PERCENT", "\\70 x", "unknown", "1px" }) |unit| {
        try std.testing.expect(numeric.parseUnit(unit) == null);
    }
}

fn serializeLeaves(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "typed_om")) return std.testing.expect(false);
    const cases = .{
        .{ 12.5, css.math_values.Unit.px, "12.5px" },
        .{ -7.0, css.math_values.Unit.em, "-7em" },
        .{ 25.0, css.math_values.Unit.percent, "25%" },
        .{ 3.0, css.math_values.Unit.number, "3" },
        .{ -0.0, css.math_values.Unit.px, "0px" },
        .{ 2.25, css.math_values.Unit.s, "2.25s" },
        .{ 2.0, css.math_values.Unit.x, "2x" },
        .{ 2.0, css.math_values.Unit.hz, "2hz" },
    };
    inline for (cases) |case| {
        const value = try css.typed_om.numeric.serialize(allocator, .{ .value = case[0], .unit = case[1] });
        defer allocator.free(value);
        try std.testing.expectEqualStrings(case[2], value);
    }
}

test "Typed OM numeric leaves use CSSOM numbers and release every allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, serializeLeaves, .{});
}
