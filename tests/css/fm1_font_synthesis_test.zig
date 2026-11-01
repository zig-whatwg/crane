//! CSS Fonts 4 §§2.7–2.8: synthesis controls cascade independently of font.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "font synthesis longhands preserve their keyword grammar" {
    inline for (.{ "font-synthesis-weight", "font-synthesis-style", "font-synthesis-small-caps", "font-synthesis-position" }) |name| {
        inline for (.{ "auto", "none" }) |value| {
            try h.check(testing.allocator, name, value, value, false);
            try h.check(testing.allocator, name, value, value, true);
        }
        inline for (.{ "normal", "weight", "auto none", "1" }) |input|
            try h.check(testing.allocator, name, input, "", false);
    }
    try h.check(testing.allocator, "font-synthesis-style", "oblique-only", "oblique-only", true);
    try h.check(testing.allocator, "font-synthesis-weight", "oblique-only", "", false);
}

test "font synthesis shorthand maps every subset including oblique-only" {
    const components = [_][]const u8{ "weight", "style", "small-caps", "position" };
    for (0..16) |mask| {
        var input: std.ArrayList(u8) = .empty;
        defer input.deinit(testing.allocator);
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(testing.allocator);
        for (0..4) |index| {
            if (mask & (@as(usize, 1) << @intCast(3 - index)) != 0) {
                if (input.items.len > 0) try input.append(testing.allocator, ' ');
                try input.appendSlice(testing.allocator, components[3 - index]);
            }
            if (mask & (@as(usize, 1) << @intCast(index)) != 0) {
                if (expected.items.len > 0) try expected.append(testing.allocator, ' ');
                try expected.appendSlice(testing.allocator, components[index]);
            }
        }
        if (mask == 0) {
            try input.appendSlice(testing.allocator, "none");
            try expected.appendSlice(testing.allocator, "none");
        }
        try h.check(testing.allocator, "font-synthesis", input.items, expected.items, false);
        try h.check(testing.allocator, "font-synthesis", input.items, expected.items, true);
        var declaration: std.ArrayList(u8) = .empty;
        defer declaration.deinit(testing.allocator);
        try declaration.appendSlice(testing.allocator, "font-synthesis:");
        try declaration.appendSlice(testing.allocator, input.items);
        var block = try h.Block.parse(.{ .allocator = testing.allocator }, declaration.items);
        defer block.deinit();
        const computed = try h.compute(testing.allocator, &block, null);
        defer computed.destroy();
        const mapped_longhands = [_][]const u8{
            "font-synthesis-weight",
            "font-synthesis-style",
            "font-synthesis-small-caps",
            "font-synthesis-position",
        };
        for (mapped_longhands, 0..) |longhand, index| {
            const expected_value: []const u8 = if (mask & (@as(usize, 1) << @intCast(index)) != 0) "auto" else "none";
            try h.expect(computed, longhand, expected_value, testing.allocator);
        }
    }
    // The oblique-only value occupies the shorthand's style slot.
    // Exercise each combination of the other three slots in specified and
    // computed serialization, plus the longhand tuple reset by each omission.
    const oblique_forms = [_][]const u8{
        "oblique-only",                     "oblique-only weight",                     "small-caps oblique-only",
        "position oblique-only",            "small-caps oblique-only weight",          "position weight oblique-only",
        "position small-caps oblique-only", "position weight small-caps oblique-only",
    };
    const oblique_expected = [_][]const u8{
        "oblique-only",                     "weight oblique-only",                     "oblique-only small-caps",
        "oblique-only position",            "weight oblique-only small-caps",          "weight oblique-only position",
        "oblique-only small-caps position", "weight oblique-only small-caps position",
    };
    for (oblique_forms, oblique_expected) |input, expected| {
        try h.check(testing.allocator, "font-synthesis", input, expected, false);
        try h.check(testing.allocator, "font-synthesis", input, expected, true);
        var declaration: std.ArrayList(u8) = .empty;
        defer declaration.deinit(testing.allocator);
        try declaration.appendSlice(testing.allocator, "font-synthesis:");
        try declaration.appendSlice(testing.allocator, input);
        var block = try h.Block.parse(.{ .allocator = testing.allocator }, declaration.items);
        defer block.deinit();
        const computed = try h.compute(testing.allocator, &block, null);
        defer computed.destroy();
        try h.expect(computed, "font-synthesis-style", "oblique-only", testing.allocator);
        try h.expect(computed, "font-synthesis-weight", if (std.mem.indexOf(u8, input, "weight") != null) "auto" else "none", testing.allocator);
        try h.expect(computed, "font-synthesis-small-caps", if (std.mem.indexOf(u8, input, "small-caps") != null) "auto" else "none", testing.allocator);
        try h.expect(computed, "font-synthesis-position", if (std.mem.indexOf(u8, input, "position") != null) "auto" else "none", testing.allocator);
    }
    var style_block = try h.Block.parse(.{ .allocator = testing.allocator }, "font-synthesis:style");
    defer style_block.deinit();
    const style_computed = try h.compute(testing.allocator, &style_block, null);
    defer style_computed.destroy();
    try h.expect(style_computed, "font-synthesis-style", "auto", testing.allocator);

    inline for (.{ "auto", "none weight", "weight weight", "weight, style" }) |input|
        try h.check(testing.allocator, "font-synthesis", input, "", false);
}

test "font synthesis shorthand rejects mutually exclusive and none combinations" {
    inline for (.{ "none oblique-only", "oblique-only none", "style oblique-only", "oblique-only style", "oblique-only oblique-only" }) |input|
        try h.check(testing.allocator, "font-synthesis", input, "", false);
}

test "font shorthand leaves independent synthesis and palette values intact" {
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "font-synthesis-weight:none;font-palette:dark;font:12px serif");
    defer block.deinit();
    try h.specified(&block, "font-synthesis-weight", "none", testing.allocator);
    try h.specified(&block, "font-palette", "dark", testing.allocator);
    const parent = try h.compute(testing.allocator, &block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    try h.expect(child, "font-synthesis-weight", "none", testing.allocator);
    try h.expect(child, "font-synthesis-style", "auto", testing.allocator);
    try h.expect(child, "font-palette", "dark", testing.allocator);
}

test "font synthesis shorthand releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "font-synthesis", "position weight small-caps", "weight small-caps position", true);
    try h.check(allocator, "font-synthesis", "oblique-only position", "oblique-only position", true);
    try h.check(allocator, "font-synthesis", "weight weight", "", false);
}
