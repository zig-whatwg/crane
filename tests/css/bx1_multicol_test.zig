//! Multicol 1 §§3–4,6–7 and Multicol 2 §4: column values and CSSOM expansion.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const h = @import("bx1_helpers.zig");

test "columns separates unitless zero width from a positive integer count" {
    inline for (.{
        .{ "0 1", "0px 1" },                     .{ "1 0", "0px 1" },
        .{ "2 10px", "10px 2" },                 .{ "auto 3", "3" },
        .{ "auto auto", "auto" },                .{ "10px 2 / auto", "10px 2" },
        .{ "2 10px / 100px", "10px 2 / 100px" }, .{ "auto / 100px", "auto / 100px" },
    }) |case| try h.check(testing.allocator, "columns", case[0], case[1], false);
    inline for (.{ "0 0", "0 7px", "10 20", "10px 20px", "auto auto auto", "/ 100px", "auto /", "1 / 20%" }) |input|
        try h.check(testing.allocator, "columns", input, "", false);
}

test "columns resets three registered constituents and preserves priority" {
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(css.properties.lookup("columns") != null);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "columns", "2em 3 / 4em", "important");
    try testing.expectEqual(@as(usize, 3), block.length());
    inline for (.{ "column-width", "column-count", "column-height" }) |name|
        try testing.expect(block.getPropertyPriority(name));
    const style = try h.compute(testing.allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "columns", "32px 3 / 64px", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "columns", "2", "");
    try h.specified(&block, "column-width", "auto", testing.allocator);
    try h.specified(&block, "column-count", "2", testing.allocator);
    try h.specified(&block, "column-height", "auto", testing.allocator);
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(testing.allocator);
    try testing.expect(try block.removeProperty("columns", &removed));
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "column dimensions compute lengths without resolving a layout size" {
    inline for (.{ "column-width", "column-height" }) |name| {
        try h.check(testing.allocator, name, "0", "0px", true);
        try h.check(testing.allocator, name, "calc(10px + 0.5em)", "18px", true);
        try h.check(testing.allocator, name, "calc(1px - 2em)", "0px", true);
        inline for (.{ "-1px", "2%", "2", "none" }) |input|
            try h.check(testing.allocator, name, input, "", false);
    }
    try h.check(testing.allocator, "column-count", "calc(2.5)", "3", true);
    try h.check(testing.allocator, "column-count", "calc(-1)", "1", true);
    try h.check(testing.allocator, "column-count", "999999999999999999999999", "2147483647", false);
    try h.check(testing.allocator, "column-count", "calc(999999999999999999999999)", "2147483647", true);
    inline for (.{ "none", "0", "-1", "1.5", "auto 1" }) |input|
        try h.check(testing.allocator, "column-count", input, "", false);
}

test "column rule reconstruction omits none without zeroing the computed width" {
    inline for (.{
        .{ "currentcolor hidden medium", "hidden" },
        .{ "currentcolor none medium", "medium" },
        .{ "red solid 2px", "2px solid red" },
    }) |case| try h.check(testing.allocator, "column-rule", case[0], case[1], false);
    inline for (.{ "none", "hidden", "solid", "outset" }) |rule_style| {
        var block = h.Block.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "column-rule", "10px red", "");
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "column-rule-style", rule_style, "");
        const style = try h.compute(testing.allocator, &block, null);
        defer style.destroy();
        try h.expect(style, "column-rule-width", "10px", testing.allocator);
        try h.expect(style, "column-rule-style", rule_style, testing.allocator);
    }
    try h.check(testing.allocator, "column-rule", "10px red", "10px rgb(255, 0, 0)", true);
    try h.check(testing.allocator, "column-rule-width", "calc(1px - 2em)", "0px", true);
    // Existing border serialization remains different: its invisible width is 0.
    var border = try h.Block.parse(.{ .allocator = testing.allocator }, "border-top: 10px none red");
    defer border.deinit();
    const style = try h.compute(testing.allocator, &border, null);
    defer style.destroy();
    try h.expect(style, "border-top-width", "0px", testing.allocator);
}

test "column properties default independently and explicit inheritance computes" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "columns: 20px 3 / 50px; column-rule: 7px dotted red; column-fill: auto; column-span: all");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    inline for (.{
        .{ "column-width", "auto" },      .{ "column-count", "auto" }, .{ "column-height", "auto" },
        .{ "column-fill", "balance" },    .{ "column-span", "none" },  .{ "column-rule-width", "3px" },
        .{ "column-rule-style", "none" },
    }) |case| try h.expect(child, case[0], case[1], testing.allocator);
    _ = try empty.setProperty(.{ .allocator = testing.allocator }, "columns", "inherit", "");
    const inherited = try h.compute(testing.allocator, &empty, parent);
    defer inherited.destroy();
    try h.expect(inherited, "columns", "20px 3 / 50px", testing.allocator);
    try h.check(testing.allocator, "column-fill", "balance-all", "balance-all", true);
    // Pinned WPT rejects auto while CSSWG 11474 is unresolved (Q7).
    try h.check(testing.allocator, "column-span", "auto", "", false);
}

test "multicol compounds release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "columns", "calc(1em + 2px) calc(2 + 1) / 4em", "18px 3 / 64px", true);
    try h.check(allocator, "column-rule", "calc(1em + 2px) solid red", "18px solid rgb(255, 0, 0)", true);
    try h.check(allocator, "columns", "calc(1em + 2px) 3 / invalid", "", false);
}
