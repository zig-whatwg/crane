//! Scroll Snap1 §§4–5 and Appendix A: parsing, computation and logical mapping.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const h = @import("bx1_helpers.zig");

test "scroll snap type canonicalizes proximity without dropping its axis" {
    inline for (.{ "x", "y", "block", "inline", "both", "pair" }) |axis| {
        try h.check(testing.allocator, "scroll-snap-type", axis, axis, true);
        try h.check(testing.allocator, "scroll-snap-type", axis ++ " proximity", axis, true);
        try h.check(testing.allocator, "scroll-snap-type", axis ++ " mandatory", axis ++ " mandatory", true);
    }
    inline for (.{ "mandatory", "proximity x", "x y", "none proximity", "x mandatory proximity" }) |input|
        try h.check(testing.allocator, "scroll-snap-type", input, "", false);
    try h.check(testing.allocator, "scroll-snap-type", "none", "none", true);
}

test "scroll snap alignment preserves two axes and omits a repeated second keyword" {
    inline for (.{ "none", "start", "end", "center" }) |first| {
        inline for (.{ "none", "start", "end", "center" }) |second| {
            const expected = if (std.mem.eql(u8, first, second)) first else first ++ " " ++ second;
            try h.check(testing.allocator, "scroll-snap-align", first ++ " " ++ second, expected, false);
            try h.check(testing.allocator, "scroll-snap-align", first ++ " " ++ second, expected, true);
        }
    }
    inline for (.{ "auto", "left", "start center end", "start, end" }) |input|
        try h.check(testing.allocator, "scroll-snap-align", input, "", false);
}

test "scroll padding keeps auto and percentages while margins accept signed lengths only" {
    inline for (.{ .{ "scroll-padding", "auto 10% 2em", "auto 10% 32px" }, .{ "scroll-margin", "-1em 2px 3px 4px", "-16px 2px 3px 4px" }, .{ "scroll-padding-inline", "calc(2em + 5%) auto", "calc(5% + 32px) auto" }, .{ "scroll-margin-block", "-2em 1px", "-32px 1px" } }) |case|
        try h.check(testing.allocator, case[0], case[1], case[2], true);
    inline for (.{ "auto", "10%", "calc(1px + 2%)", "1px 2px 3px 4px 5px" }) |input|
        try h.check(testing.allocator, "scroll-margin", input, "", false);
    inline for (.{ "none", "-1px", "-5%", "1px 2px 3px 4px 5px" }) |input|
        try h.check(testing.allocator, "scroll-padding", input, "", false);
    try h.check(testing.allocator, "scroll-padding", "calc(-1px)", "0px", true);
}

test "scroll shorthand expansion, removal and priority use the normal declaration container" {
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(css.properties.lookup("scroll-margin") != null);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "scroll-margin", "1px 2px 3px", "important");
    try testing.expectEqual(@as(usize, 4), block.length());
    try h.specified(&block, "scroll-margin-left", "2px", testing.allocator);
    try h.specified(&block, "scroll-margin-bottom", "3px", testing.allocator);
    try testing.expect(block.getPropertyPriority("scroll-margin-left"));
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "scroll-margin-left", "4px", "");
    try h.specified(&block, "scroll-margin", "", testing.allocator);
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(testing.allocator);
    try testing.expect(try block.removeProperty("scroll-margin", &removed));
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "logical scroll properties honor declaration order in every writing mode" {
    inline for (.{ "scroll-margin", "scroll-padding" }) |group| {
        for ([_][]const u8{ "horizontal-tb", "vertical-rl", "vertical-lr", "sideways-rl", "sideways-lr" }) |mode| {
            for ([_][]const u8{ "ltr", "rtl" }) |direction| {
                // Expected physical inline-start from Writing Modes4 §6.4.
                const physical = if (std.mem.eql(u8, mode, "horizontal-tb"))
                    (if (std.mem.eql(u8, direction, "rtl")) "right" else "left")
                else if (std.mem.eql(u8, mode, "sideways-lr"))
                    (if (std.mem.eql(u8, direction, "rtl")) "top" else "bottom")
                else if (std.mem.eql(u8, direction, "rtl")) "bottom" else "top";
                const name = try std.fmt.allocPrint(testing.allocator, "{s}-{s}", .{ group, physical });
                defer testing.allocator.free(name);
                var block = h.Block.init(testing.allocator);
                defer block.deinit();
                try testing.expect(css.properties.lookup(name) != null);
                try testing.expect(css.properties.lookup(group ++ "-inline-start") != null);
                _ = try block.setProperty(.{ .allocator = testing.allocator }, "writing-mode", mode, "");
                _ = try block.setProperty(.{ .allocator = testing.allocator }, "direction", direction, "");
                _ = try block.setProperty(.{ .allocator = testing.allocator }, name, "5px", "");
                _ = try block.setProperty(.{ .allocator = testing.allocator }, group ++ "-inline-start", "9px", "");
                const first = try h.compute(testing.allocator, &block, null);
                defer first.destroy();
                try h.expect(first, name, "9px", testing.allocator);
                // Same value, but it must move past the logical declaration.
                try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, name, "5px", ""));
                try testing.expectEqualStrings(name, block.item(block.length() - 1).?);
                const second = try h.compute(testing.allocator, &block, null);
                defer second.destroy();
                try h.expect(second, name, "5px", testing.allocator);
                try h.expect(second, group ++ "-inline-start", "5px", testing.allocator);
            }
        }
    }
}

test "scroll properties initialize and inherit independently" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "scroll-padding:10px;scroll-margin:5px;scroll-snap-type:x mandatory;scroll-snap-align:start end;scroll-snap-stop:always;scroll-initial-target:nearest");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var child_block = h.Block.init(testing.allocator);
    defer child_block.deinit();
    const child = try h.compute(testing.allocator, &child_block, parent);
    defer child.destroy();
    inline for (.{ .{ "scroll-padding-top", "auto" }, .{ "scroll-margin-top", "0px" }, .{ "scroll-snap-type", "none" }, .{ "scroll-snap-align", "none" }, .{ "scroll-snap-stop", "normal" }, .{ "scroll-initial-target", "none" } }) |case|
        try h.expect(child, case[0], case[1], testing.allocator);
    _ = try child_block.setProperty(.{ .allocator = testing.allocator }, "scroll-margin-inline", "inherit", "");
    const inherited = try h.compute(testing.allocator, &child_block, parent);
    defer inherited.destroy();
    try h.expect(inherited, "scroll-margin-inline", "5px", testing.allocator);
}

test "scroll declaration calculations release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "scroll-padding", "auto calc(2em + 5%)", "auto calc(5% + 32px)", true);
    try h.check(allocator, "scroll-margin-inline", "calc(-2em) 1px", "-32px 1px", true);
}
