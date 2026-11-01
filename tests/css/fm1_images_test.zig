//! Images 3 §§5.1–5.2 and Images 4 §5.1: values independent of image decoding.
const std = @import("std");
const h = @import("bx1_helpers.zig");

test "object fit supports the newer contain cover and scale down grammar" {
    inline for (.{
        .{ "fill", "fill" },
        .{ "none", "none" },
        .{ "contain", "contain" },
        .{ "cover", "cover" },
        .{ "scale-down", "scale-down" },
        .{ "contain scale-down", "scale-down" },
        .{ "scale-down contain", "scale-down" },
        .{ "cover scale-down", "cover scale-down" },
        .{ "scale-down cover", "cover scale-down" },
    }) |case| {
        try h.check(std.testing.allocator, "object-fit", case[0], case[1], false);
        try h.check(std.testing.allocator, "object-fit", case[0], case[1], true);
    }
    inline for (.{ "auto", "fill scale-down", "none scale-down", "cover contain", "scale-down scale-down", "contain cover scale-down" }) |input|
        try h.check(std.testing.allocator, "object-fit", input, "", false);
}

test "image rendering keywords retain their specified computed value" {
    inline for (.{ "auto", "smooth", "high-quality", "crisp-edges", "pixelated" }) |value| {
        try h.check(std.testing.allocator, "image-rendering", value, value, false);
        try h.check(std.testing.allocator, "image-rendering", value, value, true);
    }
    inline for (.{ "none", "crisp-edges smooth", "2" }) |input|
        try h.check(std.testing.allocator, "image-rendering", input, "", false);
}

test "image orientation accepts metadata selection without deprecated angles" {
    inline for (.{ "none", "from-image" }) |value| {
        try h.check(std.testing.allocator, "image-orientation", value, value, false);
        try h.check(std.testing.allocator, "image-orientation", value, value, true);
    }
    // Images 3 §5.1: the optional angle/flip values are deprecated; all
    // three browsers reject them (codex-cssfam ANSWER Q10).
    inline for (.{ "auto", "0deg", "30deg", "flip", "0deg flip", "-1.25turn flip", "from-image flip", "none from-image" }) |input|
        try h.check(std.testing.allocator, "image-orientation", input, "", false);
}

test "image properties use their specified inheritance and initial values" {
    var parent_block = try h.Block.parse(.{ .allocator = std.testing.allocator }, "object-fit:cover scale-down;image-rendering:pixelated;image-orientation:none");
    defer parent_block.deinit();
    const parent = try h.compute(std.testing.allocator, &parent_block, null);
    defer parent.destroy();
    var child_block = h.Block.init(std.testing.allocator);
    defer child_block.deinit();
    const child = try h.compute(std.testing.allocator, &child_block, parent);
    defer child.destroy();
    try h.expect(child, "object-fit", "fill", std.testing.allocator);
    try h.expect(child, "image-rendering", "pixelated", std.testing.allocator);
    try h.expect(child, "image-orientation", "none", std.testing.allocator);
}

test "image property declarations release every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "object-fit", "scale-down cover", "cover scale-down", true);
    try h.check(allocator, "image-rendering", "HIGH-QUALITY", "high-quality", true);
    try h.check(allocator, "image-orientation", "from-image", "from-image", true);
}
