//! Motion 1 §§2.1–2.1.1 / ANSWER Q35: a ray computes its angle with
//! offset-path's math context and its position with ComponentContext.
const std = @import("std");
const h = @import("bx1_helpers.zig");

test "computed motion ray releases both numeric and position owners on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, computedRay, .{});
}

fn computedRay(allocator: h.Allocator) !void {
    // The computed spelling proves both conversions ran. Failure at the
    // position or final Path allocation must release the computed angle;
    // failure at the final Path allocation must also release the position.
    try h.check(
        allocator,
        "offset-path",
        "ray(calc(1turn / 4) at 1em 2em)",
        "ray(90deg at 16px 32px)",
        true,
    );
}
