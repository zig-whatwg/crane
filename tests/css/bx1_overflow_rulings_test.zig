//! Q31 specified overlay, Q32 geometry and Q36 CSSOM prefix ordering.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;

test "overlay retains its specified spelling and computes to auto on every axis" {
    inline for (.{ "overflow-x", "overflow-y", "overflow-block", "overflow-inline", "overflow" }) |name| {
        inline for (.{ "overlay", "OVERLAY", "ov\\65 rlay" }) |input| {
            try h.check(testing.allocator, name, input, "overlay", false);
            try h.check(testing.allocator, name, input, "auto", true);
        }
        try h.check(testing.allocator, name, "overlay nonsense", "", false);
    }
}

test "overlay pairs are shorthand only and retain both specified axes" {
    inline for (.{ "overlay clip", "overlay hidden" }) |input| {
        try h.check(testing.allocator, "overflow", input, input, false);
        inline for (.{ "overflow-x", "overflow-y", "overflow-block", "overflow-inline" }) |name|
            try h.check(testing.allocator, name, input, "", false);
    }
    // Q13's newer clip rule remains independent of the overlay ruling.
    try h.check(testing.allocator, "overflow", "overlay clip", "auto clip", true);
    try h.check(testing.allocator, "overflow", "overlay hidden", "auto hidden", true);
}

test "overlay from a real pending value converts at computed value time" {
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "--axis:OVERLAY;overflow-x:var(--axis)");
    defer block.deinit();
    try h.specified(&block, "overflow-x", "var(--axis)", testing.allocator);
    const style = try h.compute(testing.allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "overflow-x", "auto", testing.allocator);
}

test "CSSOM starts with accent color and puts every prefixed longhand after z index" {
    const names = css.properties.lexicographic;
    try testing.expectEqualStrings("accent-color", names[0].name());
    const last_standard = std.mem.indexOfScalar(css.properties.Longhand, &names, .z_index).?;
    try testing.expect(last_standard + 1 < names.len);
    var saw_prefix = false;
    for (names, 0..) |property, i| {
        const prefixed = std.mem.startsWith(u8, property.name(), "-");
        if (prefixed) saw_prefix = true;
        try testing.expectEqual(i > last_standard, prefixed);
        if (i == 0 or i == last_standard + 1) continue;
        try testing.expect(std.mem.lessThan(u8, names[i - 1].name(), property.name()));
    }
    try testing.expect(saw_prefix);
}

test "overflow clip geometry is retained but max lines still needs scalar metrics" {
    try metrics.check(testing.allocator, "overflow-clip-margin", "9px", "1cap", null);
    try metrics.check(testing.allocator, "overflow-clip-margin", "9px", "content-box calc(1cap + 2px)", null);
    try metrics.check(testing.allocator, "max-lines", "2", "calc(1cap / 1px)", "2");
}

test "overflow overlay and cap geometry release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "overflow", "overlay hidden", "overlay hidden", false);
    try h.check(allocator, "overflow", "overlay hidden", "auto hidden", true);
    try metrics.check(allocator, "overflow-clip-margin", "9px", "calc(1cap + 2px)", null);
}
