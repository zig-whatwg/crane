//! Transforms 1 §§3–5,12 and Transforms 2 §§8–10,16; no layout geometry.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const h = @import("bx1_helpers.zig");

test "transform delegates the shared function grammar and retains specified optional arguments" {
    inline for (.{
        .{ "scaleX(720%)", "scaleX(7.2)" },
        .{ "skewY(0)", "skewY(0deg)" },
        .{ "RoTaTe(0)", "rotate(0deg)" },
        .{ "translate(1px, 0px)", "translate(1px, 0px)" },
        .{ "scale(2, 2)", "scale(2, 2)" },
        .{ "skew(90deg, 0)", "skew(90deg, 0deg)" },
        .{ "translate(1px, 2%) scale(3, 4) rotate(-90deg)", "translate(1px, 2%) scale(3, 4) rotate(-90deg)" },
    }) |case| try h.check(testing.allocator, "transform", case[0], case[1], false);
    inline for (.{ "none scale(2)", "translateX(3%) none", "matrix(1, 2)", "scale(1 2)", "scale(1,)", "scaleX(2), scaleY(3)", "perspective(1000)", "translateZ(5%)", "rotate(1)" }) |input|
        try h.check(testing.allocator, "transform", input, "", false);
}

test "resolved transforms multiply in CSS order and recognize two dimensional matrices" {
    inline for (.{
        .{ "translate(10px, 20px) scale(2, 3)", "matrix(2, 0, 0, 3, 10, 20)" },
        .{ "scale(2, 3) translate(10px, 20px)", "matrix(2, 0, 0, 3, 20, 60)" },
        .{ "rotate(90deg) translateX(10px)", "matrix(0, 1, -1, 0, 0, 10)" },
        .{ "rotate(-180deg)", "matrix(-1, 0, 0, -1, 0, 0)" },
        .{ "scaleX(2) scaleY(3)", "matrix(2, 0, 0, 3, 0, 0)" },
        .{ "matrix(1, 2, 3, 4, 5, 6)", "matrix(1, 2, 3, 4, 5, 6)" },
        .{ "matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)", "matrix(1, 0, 0, 1, 0, 0)" },
        .{ "perspective(none)", "matrix(1, 0, 0, 1, 0, 0)" },
        .{ "translateY(2em)", "matrix(1, 0, 0, 1, 0, 32)" },
        .{ "skew(45deg)", "matrix(1, 0, 1, 1, 0, 0)" },
        .{ "skewY(45deg)", "matrix(1, 1, 0, 1, 0, 0)" },
    }) |case| try h.check(testing.allocator, "transform", case[0], case[1], true);
}

test "three dimensional transforms normalize axes and clamp perspective used depth" {
    inline for (.{
        .{ "translate3d(10px, 20px, 30px)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 20, 30, 1)" },
        .{ "scale3d(2, 3, 4)", "matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1)" },
        .{ "rotateX(90deg)", "matrix3d(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1)" },
        .{ "rotateY(90deg)", "matrix3d(0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1)" },
        .{ "rotate3d(2, 0, 0, 90deg)", "matrix3d(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1)" },
        .{ "rotate3d(1e308, 0, 0, 90deg)", "matrix3d(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1)" },
        .{ "rotate3d(1, 1, 0, 180deg)", "matrix3d(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1)" },
        .{ "rotate3d(0, 0, 0, 90deg)", "matrix(1, 0, 0, 1, 0, 0)" },
        .{ "perspective(10px)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -0.1, 0, 0, 0, 1)" },
        // Transforms2 §16; Firefox+Safari agree in Q14's browser probe.
        .{ "perspective(0.5px)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -1, 0, 0, 0, 1)" },
    }) |case| try h.check(testing.allocator, "transform", case[0], case[1], true);
}

test "transform and perspective origins retain their distinct component grammars" {
    inline for (.{
        .{ "left", "left center" },
        .{ "bottom right 0px", "right bottom 0px" },
        .{ "-1px -2px 0px", "-1px -2px 0px" },
        .{ "center left 6px", "left center 6px" },
    }) |case| try h.check(testing.allocator, "transform-origin", case[0], case[1], false);
    inline for (.{ "1px left", "top 1px", "right left", "top bottom", "1px 2px 3%", "right 20px bottom 30px", "1px 2px 3px 4px" }) |input|
        try h.check(testing.allocator, "transform-origin", input, "", false);
    try h.check(testing.allocator, "perspective-origin", "bottom 10% right 20%", "right 20% bottom 10%", false);
    inline for (.{ "left 4px top", "center top 2px", "1px 2px 3px", "left right" }) |input|
        try h.check(testing.allocator, "perspective-origin", input, "", false);
    try h.check(testing.allocator, "transform-origin", "1em 2em 3em", "16px 32px 48px", true);
    try h.check(testing.allocator, "transform-origin", "1em 2em 0px", "16px 32px", true);
    try h.check(testing.allocator, "perspective-origin", "1em 2em", "16px 32px", true);
}

test "transform computation remains independent of origin and individual transforms" {
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "transform: translateY(100px); transform-origin: 10px 20px 30px; translate: 5px; rotate: 90deg; scale: 2");
    defer block.deinit();
    const style = try h.compute(testing.allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "transform", "matrix(1, 0, 0, 1, 0, 100)", testing.allocator);
    try h.expect(style, "translate", "5px", testing.allocator);
    try h.expect(style, "rotate", "90deg", testing.allocator);
    try h.expect(style, "scale", "2", testing.allocator);
}

test "transform related properties preserve their computed values and initial states" {
    inline for (.{
        .{ "transform-box", "content-box" },   .{ "transform-box", "border-box" },
        .{ "transform-box", "fill-box" },      .{ "transform-box", "stroke-box" },
        .{ "transform-box", "view-box" },      .{ "backface-visibility", "visible" },
        .{ "backface-visibility", "hidden" },  .{ "transform-style", "flat" },
        .{ "transform-style", "preserve-3d" },
    }) |case| try h.check(testing.allocator, case[0], case[1], case[1], true);
    try h.check(testing.allocator, "perspective", "0.5px", "0.5px", true);
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "transform: scale(2); transform-box: content-box; perspective: 20px; backface-visibility: hidden; transform-style: preserve-3d");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    inline for (.{ .{ "transform", "none" }, .{ "transform-box", "view-box" }, .{ "perspective", "none" }, .{ "backface-visibility", "visible" }, .{ "transform-style", "flat" } }) |case|
        try h.expect(child, case[0], case[1], testing.allocator);
}

test "legacy transform aliases preserve strict canonical grammar and canonical storage" {
    inline for (.{
        .{ "-webkit-transform", "perspective(25)", "perspective(25px)" },
        .{ "-webkit-transform", "perspective(calc(25))", "perspective(25px)" },
        .{ "-webkit-perspective", "25", "25px" },
        .{ "-webkit-perspective", "calc(25)", "25px" },
        .{ "-webkit-perspective", "calc(-1)", "0px" },
    }) |case| try h.check(testing.allocator, case[0], case[1], case[2], false);
    inline for (.{
        .{ "transform", "perspective(25)" },
        .{ "transform", "perspective(calc(25))" },
        .{ "perspective", "25" },
        .{ "perspective", "calc(25)" },
        .{ "-webkit-transform", "perspective(-1)" },
        .{ "-webkit-transform", "translateX(25)" },
        .{ "-webkit-perspective", "-1" },
    }) |case| try h.check(testing.allocator, case[0], case[1], "", false);
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "-webkit-transform", "perspective(25)", "important");
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expectEqualStrings("transform", block.item(0).?);
    try h.specified(&block, "transform", "perspective(25px)", testing.allocator);
    try h.specified(&block, "-webkit-transform", "perspective(25px)", testing.allocator);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings("transform: perspective(25px) !important;", out.items);
}

test "pending transform aliases keep their own parsing grammar and the ruled CSSOM readback" {
    // Browser probe 1026i, Q16: transform readbacks alias, while perspective
    // keeps shorthand pending-substitution readbacks. Neither loses its parser.
    inline for (.{ "transform", "perspective" }) |canonical| {
        const alias = "-webkit-" ++ canonical;
        inline for (.{ false, true }) |via_alias| {
            const authored = if (via_alias) alias else canonical;
            const input = if (comptime std.mem.eql(u8, canonical, "transform")) "perspective(25)" else "25";
            var block = h.Block.init(testing.allocator);
            defer block.deinit();
            _ = try block.setProperty(.{ .allocator = testing.allocator }, "--bx-depth", input, "");
            _ = try block.setProperty(.{ .allocator = testing.allocator }, authored, "var(--bx-depth)", "important");
            try testing.expectEqual(@as(usize, 2), block.length());
            try testing.expectEqualStrings(canonical, block.item(1).?);
            const transforms = comptime std.mem.eql(u8, canonical, "transform");
            try h.specified(&block, canonical, if (transforms or !via_alias) "var(--bx-depth)" else "", testing.allocator);
            try h.specified(&block, alias, if (transforms or via_alias) "var(--bx-depth)" else "", testing.allocator);
            try testing.expect(block.getPropertyPriority(canonical));
            try testing.expect(block.getPropertyPriority(alias));
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(testing.allocator);
            try block.serialize(&out);
            const serialized_name = if (!transforms and via_alias) alias else canonical;
            try testing.expectEqualStrings("--bx-depth: " ++ input ++ "; " ++ serialized_name ++ ": var(--bx-depth) !important;", out.items);
            const style = try h.compute(testing.allocator, &block, null);
            defer style.destroy();
            const expected = if (!via_alias) "none" else if (transforms)
                "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -0.04, 0, 0, 0, 1)"
            else
                "25px";
            try h.expect(style, canonical, expected, testing.allocator);
            try h.expect(style, alias, expected, testing.allocator);
        }
    }
}

test "legacy perspective converts known math without inventing a font context" {
    // Q19, three-browser probe 1026k: C+S admit known calculations;
    // C+F reject numbers needing style context. The ruled conversion is C's.
    inline for (.{
        .{ "calc(25)", "25px" },
        .{ "calc(-1)", "0px" },
        .{ "calc(NaN)", "0px" },
        .{ "calc(sign(1px) * 25)", "25px" },
    }) |case| {
        try h.check(testing.allocator, "-webkit-perspective", case[0], case[1], false);
        try h.check(testing.allocator, "-webkit-perspective", case[0], case[1], true);
        try h.check(testing.allocator, "-webkit-transform", "perspective(" ++ case[0] ++ ")", "perspective(" ++ case[1] ++ ")", false);
    }
    inline for (.{ "calc(sign(1em - 20px) * 25)", "calc(1em / 1px)" }) |input| {
        try h.check(testing.allocator, "-webkit-perspective", input, "", false);
        try h.check(testing.allocator, "-webkit-transform", "perspective(" ++ input ++ ")", "", false);
    }
}

test "transform aggregates release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "translate(calc(1em + 2px), 20px) scale(2, 3)", "matrix(2, 0, 0, 3, 18, 20)", true);
    try h.check(allocator, "transform-origin", "calc(1em + 2px) 2em 3px", "18px 32px 3px", true);
    try h.check(allocator, "perspective-origin", "1em 2em", "16px 32px", true);
    try h.check(allocator, "transform", "translate(1em) scale()", "", false);
    try h.check(allocator, "-webkit-transform", "perspective(calc(25))", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -0.04, 0, 0, 0, 1)", true);
    try h.check(allocator, "-webkit-perspective", "calc(NaN)", "0px", false);
    try h.check(allocator, "-webkit-transform", "perspective(calc(1em / 1px))", "", false);
}

test "transforms retain unresolved percentages and computed flattening inputs" {
    try h.check(testing.allocator, "transform", "translateX(25%)", "translateX(25%)", true);
    try h.check(testing.allocator, "transform", "translateX(0%)", "matrix(1, 0, 0, 1, 0, 0)", true);
    try h.check(testing.allocator, "transform-origin", "left center", "0px 50%", true);
    try h.check(testing.allocator, "transform-origin", "20% 30% 0px", "20% 30%", true);
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const initial = try h.compute(testing.allocator, &empty, null);
    defer initial.destroy();
    try h.expect(initial, "transform-origin", "50% 50%", testing.allocator);
    try h.expect(initial, "perspective-origin", "50% 50%", testing.allocator);
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "transform-style:preserve-3d;opacity:0.5;overflow:hidden");
    defer block.deinit();
    const style = try h.compute(testing.allocator, &block, null);
    defer style.destroy();
    // Transforms2 §7's grouping rule changes USED, not computed, flatness.
    try h.expect(style, "transform-style", "preserve-3d", testing.allocator);
}

test "transform name aliases with unchanged grammar use canonical storage" {
    // WHATWG Compat §3.4.1 mandates these four legacy name aliases.
    inline for (.{ .{ "transform-origin", "left center", "left center" }, .{ "perspective-origin", "top left", "left top" }, .{ "transform-style", "preserve-3d", "preserve-3d" }, .{ "backface-visibility", "hidden", "hidden" } }) |case| {
        const alias = "-webkit-" ++ case[0];
        try testing.expect(css.properties.lookup(alias) != null);
        inline for (.{ case[0], alias }) |authored| {
            var block = h.Block.init(testing.allocator);
            defer block.deinit();
            _ = try block.setProperty(.{ .allocator = testing.allocator }, authored, case[1], "important");
            try testing.expectEqualStrings(case[0], block.item(0).?);
            try h.specified(&block, case[0], case[2], testing.allocator);
            try h.specified(&block, alias, case[2], testing.allocator);
            try testing.expect(block.getPropertyPriority(alias));
            _ = try block.setProperty(.{ .allocator = testing.allocator }, "--bx-origin", case[1], "");
            _ = try block.setProperty(.{ .allocator = testing.allocator }, authored, "var(--bx-origin)", "important");
            try h.specified(&block, case[0], "var(--bx-origin)", testing.allocator);
            try h.specified(&block, alias, "var(--bx-origin)", testing.allocator);
            const computed = try h.compute(testing.allocator, &block, null);
            defer computed.destroy();
            var canonical_value: std.ArrayList(u8) = .empty;
            defer canonical_value.deinit(testing.allocator);
            try h.read(computed, case[0], &canonical_value, testing.allocator);
            try h.expect(computed, alias, canonical_value.items, testing.allocator);
        }
    }
}
