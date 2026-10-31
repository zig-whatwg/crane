//! CSS Rhythm 1 §§2.1–2.5: declaration values, without used-size layout.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "animated block step size clamps its final nonnegative length" {
    const css = @import("css");
    const property = css.properties.lookup("block-step-size") orelse return error.MissingBoxProperty;
    inline for (.{ @as(f64, -3), @as(f64, 0), @as(f64, 7) }) |number| {
        const result = css.interpolation.clampFinal(property.longhand, css.style_values.Value.px(number));
        try testing.expectEqual(@max(number, 0), result.length.value);
    }
}

test "block step longhands implement the draft's keyword and length grammars" {
    inline for (.{
        .{ "block-step-align", "auto" },         .{ "block-step-align", "center" },
        .{ "block-step-align", "start" },        .{ "block-step-align", "end" },
        .{ "block-step-insert", "margin-box" },  .{ "block-step-insert", "padding-box" },
        .{ "block-step-insert", "content-box" }, .{ "block-step-round", "up" },
        .{ "block-step-round", "down" },         .{ "block-step-round", "nearest" },
    }) |case| {
        try h.check(testing.allocator, case[0], case[1], case[1], false);
        try h.check(testing.allocator, case[0], case[1], case[1], true);
        try h.check(testing.allocator, case[0], "none", "", false);
    }
    inline for (.{
        .{ "none", "none" },           .{ "0", "0px" }, .{ "1em", "16px" },
        .{ "calc(1px - 2em)", "0px" },
    }) |case| try h.check(testing.allocator, "block-step-size", case[0], case[1], true);
    inline for (.{ "-1px", "1%", "1", "auto", "1px 2px", "calc(1px + 1%)" }) |input|
        try h.check(testing.allocator, "block-step-size", input, "", false);
}

test "block step shorthand orders and resets independent constituents" {
    inline for (.{
        .{ "auto up margin-box", "none" },
        .{ "none auto up margin-box", "none" },
        .{ "none padding-box up", "padding-box" },
        .{ "content-box start 100px", "100px content-box start" },
        .{ "100px center down padding-box", "100px padding-box center down" },
        .{ "end nearest 100px", "100px end nearest" },
    }) |case| {
        try h.check(testing.allocator, "block-step", case[0], case[1], false);
        try h.check(testing.allocator, "block-step", case[0], case[1], true);
    }
    inline for (.{ "auto auto", "none none", "1px 2px", "up down", "center start", "margin-box content-box", "none / center", "inherit 1px" }) |input|
        try h.check(testing.allocator, "block-step", input, "", false);
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "block-step: 1em padding-box center down");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "block-step", "nearest", "");
    try h.specified(&block, "block-step-size", "none", testing.allocator);
    try h.specified(&block, "block-step-insert", "margin-box", testing.allocator);
    try h.specified(&block, "block-step-align", "auto", testing.allocator);
    try h.specified(&block, "block-step-round", "nearest", testing.allocator);
}

test "block step values are not inherited and computed math stays nonnegative" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "block-step: 1em padding-box center down");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    const child = try h.compute(testing.allocator, &block, parent);
    defer child.destroy();
    try h.expect(child, "block-step", "none", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "block-step", "inherit", "");
    const inherited = try h.compute(testing.allocator, &block, parent);
    defer inherited.destroy();
    try h.expect(inherited, "block-step", "16px padding-box center down", testing.allocator);
}

test "block step shorthand releases all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

test "block step size retains eligible container geometry through retry" {
    try testing.checkAllAllocationFailures(testing.allocator, @import("fm1_geometry_helpers.zig").check, .{ "block-step-size", "10cqw", "5px", true });
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "block-step", "calc(1px + 2em) center down padding-box", "33px padding-box center down", true);
    try h.check(allocator, "block-step", "calc(1em) calc(2em)", "", false);
}
