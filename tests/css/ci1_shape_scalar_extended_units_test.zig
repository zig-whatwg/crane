//! UNRUN: Q176 helper-only RED on the actual post-f parent.
//! No radius family property or future Value tag is used by this file.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn lookup(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.BorderRadiusNotImplemented;
}

fn extendedLiteral(allocator: Allocator, name: []const u8, text: []const u8, valid: bool) !void {
    const p = try lookup(name);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(allocator);
    }
    try testing.expectEqual(valid, try css.properties.parseDeclaration(.{ .allocator = allocator }, p, text, &assignments));
    if (valid) {
        try testing.expect(assignments.items.len != 0);
        for (assignments.items) |a| {
            // Acceptance has no dependency on an installed font metric.
            // Q97: the aggregate must forward both flags unchanged.
            try testing.expect(a.value.value.needsUnavailableMetrics(false));
            try testing.expect(!a.value.value.needsUnavailableMetrics(true));
        }
    } else try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "ci1_border_radius shared scalar literal seam on existing padding and clip path" {
    // Existing padding is the public nonnegative-scalar control. These
    // public clip-path paths reach f's shape_components.length before the
    // new radius family exists; no private import or future tag is needed.
    const cases = .{
        .{ "padding-left", "1cap", true },
        .{ "clip-path", "inset(0 round calc(1cap))", true },
        .{ "clip-path", "inset(0 round 1cap)", true },
        .{ "clip-path", "inset(0 round 1rcap / 2ic)", true },
        .{ "clip-path", "inset(0 round -1cap)", false },
    };
    inline for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, extendedLiteral, .{ case[0], case[1], case[2] });
}
