//! The supported-property set must not be limited to 256 entries.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Longhand = css.properties.Longhand;

test "longhand IDs have room beyond u8 without changing declaration or style layout" {
    // Measurement for the mechanical widening, intentionally before the red
    // assertion so the same test records both endpoints' native layouts.
    std.debug.print("BX1_LAYOUT longhands={d} Longhand={d} Declaration={d} Entry={d} Assignment={d} Property={d} ComputedStyle={d}\n", .{
        Longhand.count,
        @sizeOf(Longhand),
        @sizeOf(css.declarations.Declaration),
        @sizeOf(css.declarations.Entry),
        @sizeOf(css.properties.Assignment),
        @sizeOf(css.properties.Property),
        @sizeOf(css.computed_style.ComputedStyle),
    });
    try testing.expect(@typeInfo(@typeInfo(Longhand).@"enum".tag_type).int.bits > 8);
    try testing.expectEqual(@typeInfo(Longhand).@"enum".fields.len, Longhand.count);
    try testing.expectEqual(Longhand.count, css.properties.lexicographic.len);
    try testing.expectEqual(Longhand.count, css.computed_style.initial_values.len);
    try testing.expectEqual(Longhand.count, css.cascade.default_path.len);
    // The computed style stores every non-logical longhand once, in a group
    // (computed_groups.zig); a logical one maps onto a physical one.
    try testing.expectEqual(Longhand.count, css.computed_style.groups.location.len);
    // Cascade's pseudo-property filters use the same count-derived EnumSet.
    const all = std.EnumSet(Longhand).full;
    try testing.expectEqual(Longhand.count, all.count());
    for (css.properties.lexicographic) |longhand| {
        try testing.expect(all.contains(longhand));
        try testing.expectEqual(longhand, longhand.info().longhand);
        try testing.expectEqual(longhand, css.properties.lookup(longhand.name()).?.longhand);
    }
}

test "every supported longhand survives declaration storage and cascade indexing" {
    try allLonghands(testing.allocator);
}

test "longhand container traversal releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allLonghands, .{});
}

fn allLonghands(allocator: std.mem.Allocator) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    for (css.properties.lexicographic) |longhand| {
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, longhand.name(), "initial", ""));
    }
    try testing.expectEqual(Longhand.count, block.entries.items.len);
    var seen = std.EnumSet(Longhand).empty;
    for (block.entries.items) |entry| {
        try testing.expect(entry == .typed);
        try testing.expect(!seen.contains(entry.typed.longhand));
        seen.insert(entry.typed.longhand);
        try testing.expectEqual(css.properties.Assigned{ .css_wide = .initial }, entry.typed.value);
    }
    try testing.expectEqual(Longhand.count, seen.count());

    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for (css.properties.lexicographic) |longhand| {
        out.clearRetainingCapacity();
        try style.serializeResolved(longhand, &out, allocator);
        try testing.expect(out.items.len > 0);
    }
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, .{ .shorthand = .all }, "initial", &assignments));
    try testing.expectEqual(css.properties.max_assignments, assignments.items.len);
    // Cascade 5: all excludes direction and unicode-bidi.
    try testing.expectEqual(Longhand.count - 2, assignments.items.len);
}
