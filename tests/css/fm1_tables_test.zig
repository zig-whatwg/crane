//! CSS Tables 3 §§3.5 and 5.2: table flags and two-axis border spacing.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "table flags parse independently of an element's display type" {
    inline for (.{
        .{ "border-collapse", "collapse" },
        .{ "border-collapse", "separate" },
        .{ "caption-side", "top" },
        .{ "caption-side", "bottom" },
        .{ "empty-cells", "show" },
        .{ "empty-cells", "hide" },
        .{ "table-layout", "auto" },
        .{ "table-layout", "fixed" },
    }) |case| {
        try h.check(testing.allocator, case[0], case[1], case[1], false);
        try h.check(testing.allocator, case[0], case[1], case[1], true);
        try h.check(testing.allocator, case[0], "none", "", false);
        try h.check(testing.allocator, case[0], case[1] ++ " " ++ case[1], "", false);
    }
    try h.check(testing.allocator, "caption-side", "left", "", false);
    try h.check(testing.allocator, "border-collapse", "SePaRaTe", "separate", false);
}

test "border spacing computes both nonnegative length axes and omits equal values" {
    inline for (.{
        .{ "0", "0px", "0px" },
        .{ "1px 2px", "1px 2px", "1px 2px" },
        .{ "2em 2em", "2em", "32px" },
        .{ "2em 3px", "2em 3px", "32px 3px" },
        .{ "calc(10px + 0.5em) calc(10px - 0.5em)", "calc(0.5em + 10px) calc(-0.5em + 10px)", "18px 2px" },
        .{ "calc(1px - 2em) 3px", "calc(-2em + 1px) 3px", "0px 3px" },
    }) |case| {
        try h.check(testing.allocator, "border-spacing", case[0], case[1], false);
        try h.check(testing.allocator, "border-spacing", case[0], case[2], true);
    }
    inline for (.{ "-1px", "1px -1px", "1%", "0px 2%", "auto", "1px 2px 3px", "1", "calc(1px + 1%)" }) |input|
        try h.check(testing.allocator, "border-spacing", input, "", false);
}

test "table inheritance and spacing preserve the parent's computed lengths" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "font-size: 20px; border-collapse: collapse; border-spacing: 1em 2em; caption-side: bottom; empty-cells: hide; table-layout: fixed");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var child_block = try h.Block.parse(.{ .allocator = testing.allocator }, "font-size: 40px");
    defer child_block.deinit();
    const child = try h.compute(testing.allocator, &child_block, parent);
    defer child.destroy();
    try h.expect(child, "border-collapse", "collapse", testing.allocator);
    try h.expect(child, "border-spacing", "20px 40px", testing.allocator);
    try h.expect(child, "caption-side", "bottom", testing.allocator);
    try h.expect(child, "empty-cells", "hide", testing.allocator);
    try h.expect(child, "table-layout", "auto", testing.allocator);
}

test "table property initial values exist before any table layout" {
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    const style = try h.compute(testing.allocator, &block, null);
    defer style.destroy();
    inline for (.{
        .{ "border-collapse", "separate" },
        .{ "border-spacing", "0px" },
        .{ "caption-side", "top" },
        .{ "empty-cells", "show" },
        .{ "table-layout", "auto" },
    }) |case| try h.expect(style, case[0], case[1], testing.allocator);
}

test "table spacing releases all partial parses and computations under OOM" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

test "border spacing retains eligible container geometry through retry" {
    try testing.checkAllAllocationFailures(testing.allocator, @import("fm1_geometry_helpers.zig").check, .{ "border-spacing", "10cqw 2px", "5px", true });
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "border-spacing", "calc(10px + 0.5em) calc(10px - 0.5em)", "18px 2px", true);
    try h.check(allocator, "border-spacing", "1em calc(2em) invalid", "", false);
    try h.check(allocator, "border-spacing", "0", "0px", true);
}
