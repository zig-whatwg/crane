//! Q32 geometric capability and Q38 origin resolution without invented boxes.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;

fn origin(allocator: h.Allocator, name: []const u8, mode: []const u8, input: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingBoxProperty;
    const suppressed = std.mem.eql(u8, mode, "suppressed");
    var parent_block = h.Block.init(allocator);
    defer parent_block.deinit();
    _ = try parent_block.setProperty(.{ .allocator = allocator }, "display", if (suppressed) "none" else "block", "");
    const parent = try h.compute(allocator, &parent_block, null);
    defer parent.destroy();
    var block = h.Block.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "display", if (suppressed) "block" else mode, "");
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, ""));
    const style = try h.compute(allocator, &block, parent);
    defer style.destroy();
    var before: std.ArrayList(u8) = .empty;
    defer before.deinit(allocator);
    try css.properties.serializeValue(property.longhand, style.get(property.longhand), &before, allocator);
    try h.expect(style, name, expected, allocator);
    var after: std.ArrayList(u8) = .empty;
    defer after.deinit(allocator);
    try css.properties.serializeValue(property.longhand, style.get(property.longhand), &after, allocator);
    try testing.expectEqualStrings(before.items, after.items);
}

const cases = .{
    .{ "left 10px", "0px 10px", "0% 10px" },
    .{ "40px top", "40px 0px", "40px 0%" },
    .{ "0% 0%", "0px 0px", "0% 0%" },
    .{ "calc(0% + 10px) 0%", "10px 0px", "calc(0% + 10px) 0%" },
};

test "origin zero percentages resolve for block and inline boxes without mutating stored values" {
    inline for (.{ "transform-origin", "perspective-origin" }) |name|
        inline for (.{ "block", "inline" }) |mode|
            inline for (cases) |case|
                try origin(testing.allocator, name, mode, case[0], case[1]);
}

test "origin percentages remain computed for none contents and suppressed descendants" {
    inline for (.{ "transform-origin", "perspective-origin" }) |name| {
        inline for (.{ "none", "contents", "suppressed" }) |mode| {
            inline for (cases) |case|
                try origin(testing.allocator, name, mode, case[0], case[2]);
            try origin(testing.allocator, name, mode, "0% 50%", "0% 50%");
        }
    }
}

test "origin nonzero geometry and unrelated position percentages remain unresolved" {
    inline for (.{ "transform-origin", "perspective-origin" }) |name| {
        try origin(testing.allocator, name, "block", "20% 30%", "20% 30%");
        // Each axis resolves independently: an unknown nonzero axis must
        // neither prevent zero resolution nor acquire an invented size.
        try origin(testing.allocator, name, "block", "0% 50%", "0px 50%");
        try origin(testing.allocator, name, "block", "50% 0%", "50% 0px");
    }
    try h.check(testing.allocator, "object-position", "0% 0%", "0% 0%", true);
    try h.check(testing.allocator, "object-position", "calc(0% + 10px) 0%", "calc(0% + 10px) 0%", true);
}

test "origin zero percentage resolution covers simplified and bounded math" {
    inline for (.{ "transform-origin", "perspective-origin" }) |name| {
        inline for (.{
            .{ "calc(25% - 25% + 12px) 0%", "12px 0px" },
            .{ "min(0%, 10px) 0%", "0px 0px" },
            .{ "max(0%, -10px) 0%", "0px 0px" },
            .{ "clamp(1px, 0%, 10px) 0%", "1px 0px" },
        }) |case| try origin(testing.allocator, name, "block", case[0], case[1]);
    }
}

test "origin zero percentages preserve independent z omission and position complements" {
    inline for (.{ "block", "none", "contents", "suppressed" }) |mode| {
        const box = std.mem.eql(u8, mode, "block");
        try origin(testing.allocator, "transform-origin", mode, "0% 0% 0px", if (box) "0px 0px" else "0% 0%");
        try origin(testing.allocator, "transform-origin", mode, "0% 0% 5px", if (box) "0px 0px 5px" else "0% 0% 5px");
        try origin(testing.allocator, "perspective-origin", mode, "right 100% bottom 100%", if (box) "0px 0px" else "0% 0%");
        try origin(testing.allocator, "perspective-origin", mode, "right 0px bottom 0px", "100% 100%");
    }
}

test "transform geometry retains cap lengths and unavailable scalars keep their earlier candidate" {
    inline for (.{
        .{ "transform", "translateX(9px)", "translateX(1cap)" },
        .{ "transform", "translateX(9px)", "translate(calc(1cap + 2px), 3px)" },
        .{ "transform-origin", "9px 9px", "1cap 2px" },
        .{ "transform-origin", "9px 9px", "calc(1cap + 2px) 3px" },
        .{ "transform-origin", "9px 9px", "calc(1cap + 0%) 0%" },
        .{ "perspective", "9px", "1cap" },
        .{ "perspective", "9px", "calc(1cap + 2px)" },
        .{ "perspective-origin", "9px 9px", "1cap 2px" },
    }) |case| metrics.check(testing.allocator, case[0], case[1], case[2], null) catch |err| {
        std.debug.print("BX1_METRIC_CASE property={s} earlier={s} later={s}\n", .{ case[0], case[1], case[2] });
        return err;
    };
    try metrics.check(testing.allocator, "transform", "translateX(9px)", "scale(calc(1cap / 1px))", "matrix(1, 0, 0, 1, 9, 0)");
    try metrics.check(testing.allocator, "transform", "translateX(9px)", "rotate(calc(sign(1cap - 1px) * 1deg))", "matrix(1, 0, 0, 1, 9, 0)");
    try metrics.check(testing.allocator, "object-position", "9px 9px", "1cap 2px", "9px 9px");
}

test "resolved origin zero percentages release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    try origin(allocator, "transform-origin", "block", "calc(0% + 10px) 0%", "10px 0px");
    try origin(allocator, "perspective-origin", "inline", "calc(0% + 10px) 0%", "10px 0px");
    try origin(allocator, "transform-origin", "contents", "calc(0% + 10px) 0%", "calc(0% + 10px) 0%");
    try origin(allocator, "perspective-origin", "block", "min(0%, 10px) 0%", "0px 0px");
    try metrics.check(allocator, "perspective", "9px", "calc(1cap + 2px)", null);
}
