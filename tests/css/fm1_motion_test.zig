//! Motion 1 §§2.1–2.6: typed values, without used-value path geometry.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "motion ray syntax orders flags and computes angles and positions" {
    inline for (.{
        .{ "ray(0deg)", "ray(0deg)", "ray(0deg)" },
        .{ "ray(0rad closest-side)", "ray(0rad)", "ray(0deg)" },
        .{ "ray(at 10px 20px 0.25turn contain)", "ray(0.25turn contain at 10px 20px)", "ray(90deg contain at 10px 20px)" },
        .{ "ray(0deg at center center sides)", "ray(0deg sides at center center)", "ray(0deg sides at 50% 50%)" },
        .{ "stroke-box ray(farthest-corner -720deg)", "ray(-720deg farthest-corner) stroke-box", "ray(-720deg farthest-corner) stroke-box" },
        .{ "ray(calc(180deg - 45deg) at 1em 2em)", "ray(calc(135deg) at 1em 2em)", "ray(135deg at 16px 32px)" },
    }) |case| {
        try h.check(testing.allocator, "offset-path", case[0], case[1], false);
        try h.check(testing.allocator, "offset-path", case[0], case[2], true);
    }
    inline for (.{ "ray()", "ray(0)", "ray(contain)", "ray(1deg 2deg)", "ray(1deg contain contain)", "ray(1deg sides closest-side)", "ray(at left)", "ray(10deg at 1px 2px 3px)", "none border-box" }) |input|
        try h.check(testing.allocator, "offset-path", input, "", false);
}

test "motion paths reuse shape grammar and coordinate boxes" {
    inline for (.{
        .{ "inset(1em 2px) border-box", "inset(1em 2px)", "inset(16px 2px)" },
        .{ "fill-box ellipse(50% 60%)", "ellipse(50% 60%) fill-box", "ellipse(50% 60%) fill-box" },
        .{ "content-box", "content-box", "content-box" },
        .{ "view-box path('m 1 2 h 30 z')", "path(\"m 1 2 h 30 Z\") view-box", "path(\"m 1 2 h 30 Z\") view-box" },
        .{ "url(\"https://example.com/a.svg#p\") padding-box", "url(\"https://example.com/a.svg#p\") padding-box", "url(\"https://example.com/a.svg#p\") padding-box" },
    }) |case| {
        try h.check(testing.allocator, "offset-path", case[0], case[1], false);
        try h.check(testing.allocator, "offset-path", case[0], case[2], true);
    }
}

test "motion positions distance and rotation compute independently of layout" {
    inline for (.{ "offset-position", "offset-anchor" }) |name| {
        try h.check(testing.allocator, name, "auto", "auto", true);
        try h.check(testing.allocator, name, "right bottom", "100% 100%", true);
        try h.check(testing.allocator, name, "1em 2px", "16px 2px", true);
        try h.check(testing.allocator, name, "1px 2px 3px", "", false);
    }
    try h.check(testing.allocator, "offset-position", "normal", "normal", true);
    try h.check(testing.allocator, "offset-anchor", "normal", "", false);
    try h.check(testing.allocator, "offset-distance", "-20%", "-20%", true);
    try h.check(testing.allocator, "offset-distance", "calc(1em + 20%)", "calc(20% + 16px)", true);
    inline for (.{
        .{ "auto", "auto", "auto" },
        .{ "reverse", "reverse", "auto 180deg" },
        .{ "-50grad reverse", "reverse -50grad", "auto 135deg" },
        .{ "auto 5turn", "auto 5turn", "auto 1800deg" },
        .{ "calc(90deg - 0.5turn)", "calc(-90deg)", "-90deg" },
    }) |case| {
        try h.check(testing.allocator, "offset-rotate", case[0], case[1], false);
        try h.check(testing.allocator, "offset-rotate", case[0], case[2], true);
    }
    inline for (.{ "0", "none", "auto reverse", "1deg 2deg", "1%", "calc(1px)" }) |input|
        try h.check(testing.allocator, "offset-rotate", input, "", false);
}

test "offset shorthand orders path components omits defaults and resets" {
    inline for (.{
        .{ "100px", "100px center" },
        .{ "normal none reverse", "none reverse" },
        .{ "none 30deg reverse", "none reverse 30deg" },
        .{ "none calc(20% + 10px) auto", "none calc(20% + 10px)" },
        .{ "ray(sides 0deg) 50% 90deg auto", "ray(0deg sides) 50% auto 90deg" },
        .{ "right bottom / left top", "right bottom / left top" },
    }) |case| try h.check(testing.allocator, "offset", case[0], case[1], false);
    inline for (.{ "/ auto", "none none", "none 1px 2px", "left top auto", "none / left / right" }) |input|
        try h.check(testing.allocator, "offset", input, "", false);
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "offset: left top ray(45deg) 2em reverse / right bottom");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "offset", "none", "");
    inline for (.{ .{ "offset-position", "normal" }, .{ "offset-path", "none" }, .{ "offset-distance", "0px" }, .{ "offset-rotate", "auto" }, .{ "offset-anchor", "auto" } }) |case|
        try h.specified(&block, case[0], case[1], testing.allocator);
}

test "motion length components retain eligible container geometry and rotation does not" {
    const geometry = @import("fm1_geometry_helpers.zig");
    inline for (.{
        .{ "offset-distance", "10cqw", "5px" },
        .{ "offset-position", "10cqw 2px", "5px 2px" },
        .{ "offset-anchor", "10cqw 2px", "5px 2px" },
        .{ "offset-path", "ray(45deg at 10cqw 2px)", "ray(45deg)" },
        .{ "offset-path", "circle(10cqw)", "circle(5px)" },
    }) |case| try geometry.check(testing.allocator, case[0], case[1], case[2], true);
    try geometry.check(testing.allocator, "offset-rotate", "calc(sign(10cqw - 1px) * 1deg)", "5deg", false);
}

test "motion shorthand and paths release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

test "motion properties are initially independent of the parent motion" {
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "offset: left top ray(45deg) 2em reverse / right bottom");
    defer block.deinit();
    const parent = try h.compute(testing.allocator, &block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    inline for (.{ .{ "offset-position", "normal" }, .{ "offset-path", "none" }, .{ "offset-distance", "0px" }, .{ "offset-rotate", "auto" }, .{ "offset-anchor", "auto" } }) |case|
        try h.expect(child, case[0], case[1], testing.allocator);
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "offset", "left top ray(0.25turn at 1em 2em) 20% auto 3deg / right bottom", "left top ray(0.25turn at 1em 2em) 20% auto 3deg / right bottom", false);
    try h.check(allocator, "offset-path", "circle(1em at right bottom)", "circle(16px at 100% 100%)", true);
    try h.check(allocator, "offset-rotate", "reverse calc(1turn / 2)", "auto 360deg", true);
    try h.check(allocator, "offset", "ray(0deg) 1em 2em", "", false);
}
