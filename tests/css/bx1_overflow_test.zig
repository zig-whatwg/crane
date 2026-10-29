//! Overflow 3 §§3.1–3.2,5.2 and Overflow 4 §§4–5: computation and CSSOM.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const h = @import("bx1_helpers.zig");

test "overflow keeps clip on a non-scrolling axis and only converts visible" {
    const keywords = [_][]const u8{ "visible", "hidden", "clip", "scroll", "auto" };
    for (keywords) |x| for (keywords) |y| {
        var block = h.Block.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "overflow-x", x, "");
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "overflow-y", y, "");
        const style = try h.compute(testing.allocator, &block, null);
        defer style.destroy();
        const x_scrolls = !std.mem.eql(u8, x, "visible") and !std.mem.eql(u8, x, "clip");
        const y_scrolls = !std.mem.eql(u8, y, "visible") and !std.mem.eql(u8, y, "clip");
        try h.expect(style, "overflow-x", if (y_scrolls and std.mem.eql(u8, x, "visible")) "auto" else x, testing.allocator);
        try h.expect(style, "overflow-y", if (x_scrolls and std.mem.eql(u8, y, "visible")) "auto" else y, testing.allocator);
    };
}

test "overlay is accepted only as one complete overflow axis value" {
    // Q31 PART2's specified/computed readbacks are pinned in the ruling tests.
    inline for (.{ "overflow-x", "overflow-y", "overflow-block", "overflow-inline" }) |name| {
        try testing.expect(css.properties.lookup(name) != null);
        inline for (.{ "overlay", "OVERLAY", "ov\\65 rlay" }) |input| {
            var block = h.Block.init(testing.allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, name, input, ""));
            try testing.expectEqual(@as(usize, 1), block.length());
            try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, name, "overlay hidden", ""));
            try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, name, "overlay nonsense", ""));
        }
    }
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "overflow", "overlay hidden", "important"));
    try testing.expectEqual(@as(usize, 2), block.length());
    try testing.expect(block.getPropertyPriority("overflow-x"));
    try testing.expect(block.getPropertyPriority("overflow-y"));
    try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "overflow", "overlay nonsense", ""));
}

test "logical overflow preserves order in all writing modes and both axes" {
    for ([_][]const u8{ "horizontal-tb", "vertical-rl", "vertical-lr", "sideways-rl", "sideways-lr" }) |mode| {
        for ([_][]const u8{ "ltr", "rtl" }) |direction| {
            for ([_][]const u8{ "overflow-inline", "overflow-block" }) |logical| {
                const horizontal = std.mem.eql(u8, mode, "horizontal-tb");
                const is_inline = std.mem.eql(u8, logical, "overflow-inline");
                const physical = if (horizontal == is_inline) "overflow-x" else "overflow-y";
                var block = h.Block.init(testing.allocator);
                defer block.deinit();
                try testing.expect(css.properties.lookup(logical) != null);
                _ = try block.setProperty(.{ .allocator = testing.allocator }, "writing-mode", mode, "");
                _ = try block.setProperty(.{ .allocator = testing.allocator }, "direction", direction, "");
                _ = try block.setProperty(.{ .allocator = testing.allocator }, physical, "scroll", "");
                _ = try block.setProperty(.{ .allocator = testing.allocator }, logical, "clip", "");
                const first = try h.compute(testing.allocator, &block, null);
                defer first.destroy();
                try h.expect(first, physical, "clip", testing.allocator);
                try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, physical, "scroll", ""));
                try testing.expectEqualStrings(physical, block.item(block.length() - 1).?);
                const second = try h.compute(testing.allocator, &block, null);
                defer second.destroy();
                try h.expect(second, physical, "scroll", testing.allocator);
                try h.expect(second, logical, "scroll", testing.allocator);
            }
        }
    }
}

test "scroll navigation keywords retain ordered marker grammar and computed links" {
    inline for (.{ .{ "none", "none", "none" }, .{ "before", "before", "before links" }, .{ "after", "after", "after links" }, .{ "before tabs", "before tabs", "before tabs" }, .{ "after links", "after links", "after links" } }) |case| {
        try h.check(testing.allocator, "scroll-marker-group", case[0], case[1], false);
        try h.check(testing.allocator, "scroll-marker-group", case[0], case[2], true);
    }
    inline for (.{ "links", "tabs", "links after", "tabs before", "none links", "before after", "after tabs links" }) |input|
        try h.check(testing.allocator, "scroll-marker-group", input, "", false);
    inline for (.{ "none", "auto" }) |input|
        try h.check(testing.allocator, "scroll-target-group", input, input, true);
    // Overflow 5 §4.1 admits only auto and none.
    inline for (.{ "auto", "none" }) |input|
        try h.check(testing.allocator, "scroll-axis-lock", input, input, true);
    inline for (.{ "free", "lock" }) |input|
        try h.check(testing.allocator, "scroll-axis-lock", input, "", false);
}

test "overflow clip margin canonicalizes reference boxes and signed lengths" {
    inline for (.{
        .{ "padding-box", "0px", "0px" },
        .{ "content-box 0px", "content-box", "content-box" },
        .{ "0px border-box", "border-box", "border-box" },
        .{ "-10px border-box", "border-box -10px", "border-box -10px" },
        .{ "padding-box calc(100px - 150px)", "calc(-50px)", "-50px" },
        .{ "content-box calc(0.5em + 100px)", "content-box calc(0.5em + 100px)", "content-box 108px" },
    }) |case| {
        try h.check(testing.allocator, "overflow-clip-margin", case[0], case[1], false);
        try h.check(testing.allocator, "overflow-clip-margin", case[0], case[2], true);
    }
    inline for (.{ "margin-box", "inset(10px)", "10px 20px", "50%", "calc(100% - 50px)", "border-box content-box" }) |input|
        try h.check(testing.allocator, "overflow-clip-margin", input, "", false);
}

test "scrollbar gutter requires stable when both edges is present" {
    inline for (.{ .{ "auto", "auto" }, .{ "stable", "stable" }, .{ "stable both-edges", "stable both-edges" }, .{ "both-edges stable", "stable both-edges" } }) |case|
        try h.check(testing.allocator, "scrollbar-gutter", case[0], case[1], true);
    inline for (.{ "both-edges", "auto both-edges", "stable stable", "stable both-edges both-edges" }) |input|
        try h.check(testing.allocator, "scrollbar-gutter", input, "", false);
}

test "line clamp distinguishes its normal and webkit reset expansions" {
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(css.properties.lookup("line-clamp") != null);
    try testing.expect(css.properties.lookup("-webkit-line-clamp") != null);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "line-clamp", "5", "");
    try testing.expectEqual(@as(usize, 3), block.length());
    try h.specified(&block, "max-lines", "5", testing.allocator);
    try h.specified(&block, "block-ellipsis", "ellipsis", testing.allocator);
    try h.specified(&block, "continue", "collapse", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "line-clamp", "none", "");
    try h.specified(&block, "max-lines", "auto", testing.allocator);
    try h.specified(&block, "block-ellipsis", "no-ellipsis", testing.allocator);
    try h.specified(&block, "continue", "normal", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "-webkit-line-clamp", "none", "");
    try h.specified(&block, "block-ellipsis", "no-ellipsis", testing.allocator);
    try h.specified(&block, "continue", "normal", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "-webkit-line-clamp", "3", "");
    try h.specified(&block, "max-lines", "3", testing.allocator);
    try h.specified(&block, "continue", "-webkit-legacy", testing.allocator);
    try h.specified(&block, "line-clamp", "3 -webkit-legacy", testing.allocator);
}

test "block ellipsis inherits while max lines and continuation default independently" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "line-clamp: 4 \"more\"");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    try h.expect(child, "block-ellipsis", "\"more\"", testing.allocator);
    try h.expect(child, "max-lines", "auto", testing.allocator);
    try h.expect(child, "continue", "normal", testing.allocator);
}

test "max lines keeps the independent auto component and computes integer math" {
    inline for (.{
        .{ "auto", "auto", "auto" },
        .{ "7 auto", "7 auto", "7 auto" },
        .{ "auto 8", "8 auto", "8 auto" },
        .{ "auto calc(2 + 3)", "calc(5) auto", "5 auto" },
        .{ "calc(NaN)", "calc(NaN)", "1" },
        .{ "999999999999999999999999 auto", "2147483647 auto", "2147483647 auto" },
    }) |case| {
        try h.check(testing.allocator, "max-lines", case[0], case[1], false);
        try h.check(testing.allocator, "max-lines", case[0], case[2], true);
    }
    inline for (.{ "none", "0", "-1", "1.5", "auto auto", "2 3" }) |input|
        try h.check(testing.allocator, "max-lines", input, "", false);
    inline for (.{
        .{ "ellipsis", "auto" },
        .{ "auto 8", "8 auto" },
        .{ "8 ellipsis", "8" },
        .{ "no-ellipsis -webkit-legacy", "auto no-ellipsis -webkit-legacy" },
        .{ "3 auto -webkit-legacy", "3 auto -webkit-legacy" },
    }) |case|
        try h.check(testing.allocator, "line-clamp", case[0], case[1], false);
}

test "webkit line clamp rejects shorthand reconstruction from incompatible constituents" {
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "max-lines: 3 auto; block-ellipsis: ellipsis; continue: -webkit-legacy");
    defer block.deinit();
    try h.specified(&block, "line-clamp", "3 auto -webkit-legacy", testing.allocator);
    try h.specified(&block, "-webkit-line-clamp", "", testing.allocator);
    const style = try h.compute(testing.allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "-webkit-line-clamp", "", testing.allocator);
}

test "text overflow keeps distinct one and two edge semantics including empty strings" {
    inline for (.{ "clip", "ellipsis", "\"\"", "\"more\"", "clip ellipsis", "ellipsis ellipsis", "\"start\" \"end\"" }) |input|
        try h.check(testing.allocator, "text-overflow", input, input, true);
    inline for (.{ "auto", "clip clip clip", "10px" }) |input|
        try h.check(testing.allocator, "text-overflow", input, "", false);
}

test "overflow compounds release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "overflow-clip-margin", "border-box calc(1em + 5px)", "border-box 21px", true);
    try h.check(allocator, "block-ellipsis", "\"more\"", "\"more\"", true);
    try h.check(allocator, "text-overflow", "\"left\" \"right\"", "\"left\" \"right\"", true);
    try h.check(allocator, "max-lines", "calc(NaN)", "1", true);
    try h.check(allocator, "max-lines", "auto calc(2 + 3)", "5 auto", true);
    try h.check(allocator, "line-clamp", "auto calc(2 + 3) \"more\"", "5 auto \"more\"", true);
    try h.check(allocator, "line-clamp", "auto calc(2 + 3) \"more\" invalid", "", false);
    try h.check(allocator, "overflow-clip-margin", "border-box calc(1em + 5px) invalid", "", false);
}

test "existing ordinary display parsing and float blockification retain their outputs" {
    inline for (.{
        .{ "inline", "inline", "block" },                         .{ "block", "block", "block" },
        .{ "inline flow-root", "inline-block", "block" },         .{ "flow-root", "flow-root", "flow-root" },
        .{ "inline flex", "inline-flex", "flex" },                .{ "flex", "flex", "flex" },
        .{ "inline grid", "inline-grid", "grid" },                .{ "grid", "grid", "grid" },
        .{ "inline table", "inline-table", "table" },             .{ "table-row", "table-row", "block" },
        .{ "none", "none", "none" },                              .{ "contents", "contents", "contents" },
        .{ "inline list-item", "inline list-item", "list-item" },
    }) |case| {
        try h.check(testing.allocator, "display", case[0], case[1], false);
        var block = h.Block.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "display", case[0], "");
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "float", "left", "");
        const style = try h.compute(testing.allocator, &block, null);
        defer style.destroy();
        try h.expect(style, "display", case[2], testing.allocator);
    }
}

test "legacy display aliases retain the distinction required by clamping" {
    inline for (.{ .{ "-webkit-box", "-webkit-box" }, .{ "-webkit-inline-box", "-webkit-inline-box" }, .{ "-webkit-flex", "flex" }, .{ "-webkit-inline-flex", "inline-flex" } }) |case| {
        try h.check(testing.allocator, "display", case[0], case[1], false);
        try h.check(testing.allocator, "display", case[0], case[1], true);
    }
    inline for (.{ "block -webkit-box", "inline -webkit-flex", "-webkit-box flex", "-webkit-box list-item" }) |input|
        try h.check(testing.allocator, "display", input, "", false);
}

test "vertical legacy clamp follows blockification without changing real flex" {
    for ([_][]const u8{ "-webkit-box", "-webkit-inline-box", "flex", "inline-flex", "-webkit-flex", "-webkit-inline-flex" }) |display| {
        for ([_][]const u8{ "horizontal", "vertical", "inline-axis", "block-axis" }) |orient| {
            for ([_][]const u8{ "none", "3" }) |clamp| {
                for ([_]bool{ false, true }) |floated| {
                    var block = h.Block.init(testing.allocator);
                    defer block.deinit();
                    try testing.expect(css.properties.lookup("-webkit-box-orient") != null);
                    try testing.expect(css.properties.lookup("-webkit-line-clamp") != null);
                    _ = try block.setProperty(.{ .allocator = testing.allocator }, "display", display, "");
                    _ = try block.setProperty(.{ .allocator = testing.allocator }, "-webkit-box-orient", orient, "");
                    _ = try block.setProperty(.{ .allocator = testing.allocator }, "-webkit-line-clamp", clamp, "");
                    if (floated) _ = try block.setProperty(.{ .allocator = testing.allocator }, "float", "left", "");
                    const style = try h.compute(testing.allocator, &block, null);
                    defer style.destroy();
                    const legacy = std.mem.endsWith(u8, display, "box");
                    const inline_box = std.mem.indexOf(u8, display, "inline") != null;
                    const vertical = std.mem.eql(u8, orient, "vertical") or std.mem.eql(u8, orient, "block-axis");
                    const clamped = legacy and vertical and std.mem.eql(u8, clamp, "3");
                    const expected = if (legacy)
                        (if (clamped) (if (inline_box and !floated) "inline-block" else "flow-root") else (if (inline_box and !floated) "-webkit-inline-box" else "-webkit-box"))
                    else if (inline_box and !floated) "inline-flex" else "flex";
                    try h.expect(style, "display", expected, testing.allocator);
                    try h.expect(style, "-webkit-box-orient", if (vertical) "vertical" else "horizontal", testing.allocator);
                    try h.expect(style, "flex-direction", "row", testing.allocator);
                    try h.specified(&block, "-webkit-box-orient", orient, testing.allocator);
                }
            }
        }
    }
}

test "box orientation does not inherit by default or alias flex direction" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "display:flex;-webkit-box-orient:vertical;flex-direction:column");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    inline for (.{ .{ "inherit", "vertical" }, .{ "initial", "horizontal" }, .{ "unset", "horizontal" }, .{ "block-axis", "vertical" } }) |case| {
        var child_block = try h.Block.parse(.{ .allocator = testing.allocator }, "display:-webkit-inline-box;-webkit-line-clamp:3");
        defer child_block.deinit();
        _ = try child_block.setProperty(.{ .allocator = testing.allocator }, "-webkit-box-orient", case[0], "");
        const child = try h.compute(testing.allocator, &child_block, parent);
        defer child.destroy();
        try h.expect(child, "-webkit-box-orient", case[1], testing.allocator);
        try h.expect(child, "flex-direction", "row", testing.allocator);
        try h.expect(child, "display", if (std.mem.eql(u8, case[1], "vertical")) "flow-root" else "-webkit-box", testing.allocator);
    }
}

test "legacy clamping follows flex and grid parent blockification for every continuation" {
    inline for (.{ "flex", "grid" }) |parent_display| {
        var parent_block = h.Block.init(testing.allocator);
        defer parent_block.deinit();
        _ = try parent_block.setProperty(.{ .allocator = testing.allocator }, "display", parent_display, "");
        const parent = try h.compute(testing.allocator, &parent_block, null);
        defer parent.destroy();
        inline for (.{ "normal", "collapse", "discard", "-webkit-legacy" }) |continuation| {
            var block = try h.Block.parse(.{ .allocator = testing.allocator }, "display:-webkit-inline-box;-webkit-box-orient:vertical");
            defer block.deinit();
            try testing.expect(css.properties.lookup("continue") != null);
            _ = try block.setProperty(.{ .allocator = testing.allocator }, "continue", continuation, "");
            const style = try h.compute(testing.allocator, &block, parent);
            defer style.destroy();
            try h.expect(style, "display", if (std.mem.eql(u8, continuation, "normal")) "-webkit-box" else "flow-root", testing.allocator);
            try h.expect(style, "continue", continuation, testing.allocator);
        }
    }
}
