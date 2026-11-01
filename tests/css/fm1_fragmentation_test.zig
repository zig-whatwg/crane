//! CSS Fragmentation 3/4 §§3.1–3.3,5.4: values independent of layout.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "fragmentation keywords parse and compute without a fragmentation context" {
    // Break 4 §3.1 adds always/all; Gecko ships always. The region values
    // are rejected by Blink, Gecko and WebKit (liaison ANSWER Q3).
    inline for (.{ "break-before", "break-after" }) |property| {
        inline for (.{ "auto", "avoid", "always", "all", "avoid-page", "page", "left", "right", "recto", "verso", "avoid-column", "column" }) |value| {
            try h.check(testing.allocator, property, value, value, false);
            try h.check(testing.allocator, property, value, value, true);
        }
        inline for (.{ "none", "avoid region", "auto auto", "region", "avoid-region" }) |value|
            try h.check(testing.allocator, property, value, "", false);
    }
    inline for (.{ "auto", "avoid", "avoid-page", "avoid-column" }) |value| {
        try h.check(testing.allocator, "break-inside", value, value, false);
        try h.check(testing.allocator, "break-inside", value, value, true);
    }
    inline for (.{ "always", "page", "left", "all", "region", "avoid-region" }) |value|
        try h.check(testing.allocator, "break-inside", value, "", false);
    inline for (.{ "slice", "clone" }) |value| {
        try h.check(testing.allocator, "box-decoration-break", value, value, false);
        try h.check(testing.allocator, "box-decoration-break", value, value, true);
    }
    try h.check(testing.allocator, "break-before", "AvOiD-PaGe", "avoid-page", false);
    try h.check(testing.allocator, "box-decoration-break", "clone slice", "", false);
}

test "orphans and widows use positive integers with computed math range clamping" {
    inline for (.{ "orphans", "widows" }) |property| {
        inline for (.{ "1", "234", "+3" }) |value| {
            const expected = if (value[0] == '+') value[1..] else value;
            try h.check(testing.allocator, property, value, expected, false);
            try h.check(testing.allocator, property, value, expected, true);
        }
        inline for (.{ "auto", "-1", "0", "2.5", "2px", "1 234", "1e2" }) |value|
            try h.check(testing.allocator, property, value, "", false);
        try h.check(testing.allocator, property, "calc(1 + 234)", "235", true);
        try h.check(testing.allocator, property, "calc(2.5)", "3", true);
        try h.check(testing.allocator, property, "calc(-20)", "1", true);
    }
}

test "fragmentation initial values and inheritance follow the property tables" {
    var parent_block = try h.Block.parse(.{ .allocator = testing.allocator }, "break-before: page; break-after: right; break-inside: avoid; box-decoration-break: clone; orphans: 5; widows: 7");
    defer parent_block.deinit();
    const parent = try h.compute(testing.allocator, &parent_block, null);
    defer parent.destroy();
    var child_block = h.Block.init(testing.allocator);
    defer child_block.deinit();
    const child = try h.compute(testing.allocator, &child_block, parent);
    defer child.destroy();
    inline for (.{ "break-before", "break-after", "break-inside" }) |property|
        try h.expect(child, property, "auto", testing.allocator);
    try h.expect(child, "box-decoration-break", "slice", testing.allocator);
    try h.expect(child, "orphans", "5", testing.allocator);
    try h.expect(child, "widows", "7", testing.allocator);
    _ = try child_block.setProperty(.{ .allocator = testing.allocator }, "break-before", "inherit", "");
    _ = try child_block.setProperty(.{ .allocator = testing.allocator }, "orphans", "initial", "");
    const inherited = try h.compute(testing.allocator, &child_block, parent);
    defer inherited.destroy();
    try h.expect(inherited, "break-before", "page", testing.allocator);
    try h.expect(inherited, "orphans", "2", testing.allocator);
}

test "animated orphans and widows clamp the final integer to one" {
    inline for (.{ "orphans", "widows" }) |name| {
        const property = css.properties.lookup(name) orelse return error.MissingBoxProperty;
        inline for (.{ @as(i32, -3), @as(i32, 0), @as(i32, 7) }) |number| {
            const result = css.interpolation.clampFinal(property.longhand, .{ .integer = number });
            try testing.expectEqual(@max(number, 1), result.integer);
        }
    }
}

test "fragmentation declarations and math release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "orphans", "calc(1 + 234)", "235", true);
    try h.check(allocator, "widows", "calc(-20)", "1", true);
    try h.check(allocator, "break-before", "avoid-page", "avoid-page", true);
    try h.check(allocator, "break-inside", "avoid page", "", false);
}

test "CSS family style layout receipt" {
    const style = css.computed_style;
    const header = std.mem.alignForward(usize, @sizeOf(style.Group), @alignOf(css.style_values.Value));
    var all_groups_bytes: usize = 0;
    for (style.groups.lengths) |count| all_groups_bytes += header + @as(usize, count) * @sizeOf(css.style_values.Value);
    // Untouched groups are shared. This upper bound assumes every group
    // is private, excluding independently owned composite value payloads.
    std.debug.print("FM1_STYLE_LAYOUT longhands={d} groups={d} stored={d} ComputedStyle={d} Value={d} private_groups={d} max_shallow_style={d}\n", .{
        css.properties.Longhand.count,
        css.computed_style.groups.count,
        css.computed_style.groups.stored,
        @sizeOf(css.computed_style.ComputedStyle),
        @sizeOf(css.style_values.Value),
        all_groups_bytes,
        @sizeOf(style.ComputedStyle) + all_groups_bytes,
    });
}
