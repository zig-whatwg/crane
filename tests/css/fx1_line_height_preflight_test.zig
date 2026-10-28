//! HTML sizes has no line-height input; CSS styling still computes it normally.
const std = @import("std");
const css = @import("css");

test "math line height preflight finds nested lh and rlh only" {
    const cases = [_]struct { text: []const u8, needs: bool }{
        .{ .text = "calc(1lh)", .needs = true },
        .{ .text = "min(1rlh, 10px)", .needs = true },
        .{ .text = "calc(1px + max(2lh, 3em))", .needs = true },
        .{ .text = "calc(1px + max(2rlh, 3em))", .needs = true },
        .{ .text = "calc(1px + 2em + 3vw)", .needs = false },
        .{ .text = "max(2rem, 3vh)", .needs = false },
    };
    for (cases) |case| {
        const parsed = (try css.math_values.parse(std.testing.allocator, case.text, .{ .kind = .length })).?;
        defer parsed.expression.unref();
        try std.testing.expectEqual(case.needs, parsed.expression.needsLineHeight());
    }
}

test "styling still computes line height math through the cascade" {
    const cases = [_]struct { text: []const u8, expected: f64 }{
        .{ .text = "line-height: 40px; width: calc(1lh)", .expected = 40 },
        .{ .text = "line-height: 40px; width: min(1rlh, 10px)", .expected = 10 },
    };
    for (cases) |case| {
        var declarations = try css.declarations.DeclarationBlock.parse(.{ .allocator = std.testing.allocator }, case.text);
        defer declarations.deinit();
        const style = try css.cascade.cascade(.{ .allocator = std.testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &declarations, .source = .{ .origin = .author } }});
        defer style.destroy();
        try std.testing.expectApproxEqAbs(case.expected, style.get(.width).length.value, 0.00001);
    }
}
