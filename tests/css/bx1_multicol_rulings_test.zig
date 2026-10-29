//! Q28/Q44 legacy name aliases; Q32 property-owned geometric capability.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;

const cases = .{
    .{ "column-count", "3" },
    .{ "column-width", "20px" },
    .{ "column-span", "all" },
    .{ "column-gap", "10px" },
    .{ "column-rule-color", "red" },
    .{ "column-rule-style", "dotted" },
    .{ "column-rule-width", "2px" },
    .{ "columns", "20px 3" },
    .{ "column-rule", "2px dotted red" },
};

test "multicol legacy names share canonical lookup and CSSOM storage" {
    inline for (cases) |case| {
        const canonical = css.properties.lookup(case[0]) orelse return error.MissingBoxProperty;
        const alias = "-webkit-" ++ case[0];
        try testing.expectEqual(canonical, css.properties.lookup(alias) orelse return error.MissingMulticolAlias);
        inline for (.{ case[0], alias }) |authored| {
            var block = h.Block.init(testing.allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, authored, case[1], ""));
            try h.specified(&block, case[0], case[1], testing.allocator);
            try h.specified(&block, alias, case[1], testing.allocator);
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(testing.allocator);
            try block.serialize(&out);
            try testing.expectEqualStrings(case[0] ++ ": " ++ case[1] ++ ";", out.items);
            _ = try block.setProperty(.{ .allocator = testing.allocator }, case[0], case[1], "important");
            try testing.expect(block.getPropertyPriority(alias));
        }
    }
}

test "multicol aliases retain canonical pending identities and real var substitution" {
    inline for (cases) |case| {
        const property = css.properties.lookup(case[0]) orelse return error.MissingBoxProperty;
        const alias = "-webkit-" ++ case[0];
        _ = css.properties.lookup(alias) orelse return error.MissingMulticolAlias;
        var block = h.Block.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, alias, "var(--value)", "");
        try h.specified(&block, alias, "var(--value)", testing.allocator);
        try h.specified(&block, case[0], "var(--value)", testing.allocator);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.serialize(&out);
        try testing.expectEqualStrings(case[0] ++ ": var(--value);", out.items);
        for (block.entries.items) |entry| {
            const value = entry.typed.value.value;
            try testing.expect(value == .pending);
            try testing.expectEqual(property, value.pending.property.?);
        }
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "--value", case[1], "");
        const style = try h.compute(testing.allocator, &block, null);
        defer style.destroy();
        var control = h.Block.init(testing.allocator);
        defer control.deinit();
        _ = try control.setProperty(.{ .allocator = testing.allocator }, case[0], case[1], "");
        const expected = try h.compute(testing.allocator, &control, null);
        defer expected.destroy();
        out.clearRetainingCapacity();
        try h.read(expected, case[0], &out, testing.allocator);
        try h.expect(style, alias, out.items, testing.allocator);
        try h.expect(style, case[0], out.items, testing.allocator);
    }
}

test "column fill and height legacy names remain excluded by the browser ruling" {
    try testing.expect(css.properties.lookup("-webkit-column-fill") == null);
    try testing.expect(css.properties.lookup("-webkit-column-height") == null);
}

test "column sizes preserve unknown geometry but integer counts require metrics" {
    inline for (.{ "column-width", "column-height" }) |name| {
        try metrics.check(testing.allocator, name, "9px", "1cap", null);
        try metrics.check(testing.allocator, name, "9px", "calc(1cap + 2px)", null);
    }
    try metrics.check(testing.allocator, "column-count", "2", "calc(1cap / 1px)", "2");
}

test "multicol alias pending values and unavailable geometry release all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    _ = css.properties.lookup("-webkit-columns") orelse return error.MissingMulticolAlias;
    var block = try h.Block.parse(.{ .allocator = allocator }, "--value:2em 3 / 4em;-webkit-columns:var(--value)");
    defer block.deinit();
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "columns", "32px 3 / 64px", allocator);
    try h.expect(style, "-webkit-columns", "32px 3 / 64px", allocator);
    try metrics.check(allocator, "column-width", "9px", "calc(1cap + 2px)", null);
}
