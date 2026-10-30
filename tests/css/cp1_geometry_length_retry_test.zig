//! Q136: preflight and post-compute retry share geometry-length eligibility.
//! Conditional Rules 5 §7: an eligible container without provider geometry
//! retains a geometry length; only absence of an eligible container falls back.
const std = @import("std");
const css = @import("css");
const math = css.math_values;

const Probe = struct {
    eligible: bool = true,
    calls: usize = 0,

    fn get(raw: *anyopaque, axis: math.Context.ContainerAxis) math.Context.ContainerEligibility {
        const self: *Probe = @ptrCast(@alignCast(raw));
        _ = axis;
        self.calls += 1;
        return if (self.eligible) .eligible_geometry_unavailable else .no_eligible_container;
    }
};

fn checkTransform(allocator: std.mem.Allocator, eligible: bool, scalar: bool, revert_layer: bool) !void {
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "transform: translateX(5px)");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (scalar)
        "transform: scale(sign(2cqw - 10px))"
    else
        "transform: translateX(10cqw)");
    defer high.deinit();
    var rollback = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "transform: revert-layer");
    defer rollback.deinit();
    try std.testing.expect(high.get(.transform) != null);
    var probe: Probe = .{ .eligible = eligible };
    var note: math.UnavailableNote = .{};
    const matched = [_]css.cascade.Matched{
        .{ .block = &low, .source = .{ .origin = .author, .layer = 0, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .layer = 0, .order = 2 } },
        .{ .block = &rollback, .source = .{ .origin = .author, .layer = 1, .order = 3 } },
    };
    const style = try css.cascade.cascade(.{
        .allocator = allocator,
        .parent = null,
        .viewport_width = 800,
        .viewport_height = 600,
        .container = .{ .context = &probe, .get = Probe.get, .note = &note },
    }, matched[0..if (revert_layer) 3 else 2]);
    defer style.destroy();
    try std.testing.expect(probe.calls > 0);
    try std.testing.expect(!note.scalar and !note.retained_length);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.transform, &out, allocator);
    if (eligible and !scalar) {
        // The post-compute retry must keep the same geometry classification
        // as preflight, rather than replacing the winner with the lower 5px.
        try std.testing.expect(std.mem.indexOf(u8, out.items, "10cqw") != null);
    } else {
        try std.testing.expectEqualStrings(if (scalar) "matrix(1, 0, 0, 1, 5, 0)" else "matrix(1, 0, 0, 1, 80, 0)", out.items);
    }
}

test "cp1 transform geometry survives container retry and revert-layer" {
    try checkTransform(std.testing.allocator, true, false, false);
    try checkTransform(std.testing.allocator, true, false, true);
}

test "cp1 transform retry still rejects unavailable scalar input" {
    try checkTransform(std.testing.allocator, true, true, false);
}

test "cp1 transform without an eligible container uses the viewport" {
    try checkTransform(std.testing.allocator, false, false, false);
}

test "cp1 retained transform geometry releases every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkTransform, .{ true, false, true });
}
