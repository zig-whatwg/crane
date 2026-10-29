//! CSS Sizing 3 §3.2: a minimum auto resolves to zero without a box.
//! Row 125 Q41: only physical minimums at the CSSOM serialization boundary.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;

fn element(allocator: Allocator, parent: ?*const Style, text: []const u8) !*Style {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn minimum(allocator: Allocator, style: *const Style, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for ([_]css.properties.Longhand{ .min_width, .min_height }) |property| {
        // Resolving the CSSOM text must not mutate the computed auto.
        try testing.expect(style.get(property).isKeyword(.auto));
        out.clearRetainingCapacity();
        try style.serializeResolved(property, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
        try testing.expect(style.get(property).isKeyword(.auto));
    }
}

test "minimum auto resolves to zero for own display none" {
    const style = try element(testing.allocator, null, "display: none; min-width: auto; min-height: auto");
    defer style.destroy();
    try minimum(testing.allocator, style, "0px");
}

test "minimum auto resolves to zero below display none through contents" {
    const parent = try element(testing.allocator, null, "display: none");
    defer parent.destroy();
    const middle = try element(testing.allocator, parent, "display: contents");
    defer middle.destroy();
    const child = try element(testing.allocator, middle, "display: flex; min-width: auto; min-height: auto");
    defer child.destroy();
    try minimum(testing.allocator, child, "0px");
}

test "minimum auto resolves to zero for own display contents" {
    const parent = try element(testing.allocator, null, "display: grid");
    defer parent.destroy();
    const child = try element(testing.allocator, parent, "display: contents; min-width: auto; min-height: auto");
    defer child.destroy();
    try minimum(testing.allocator, child, "0px");
}

test "minimum auto is retained for ordinary flex and grid items through contents" {
    inline for (.{ "display: flex", "display: grid" }) |text| {
        const parent = try element(testing.allocator, null, text);
        defer parent.destroy();
        const middle = try element(testing.allocator, parent, "display: contents");
        defer middle.destroy();
        const child = try element(testing.allocator, middle, "display: block; min-width: auto; min-height: auto");
        defer child.destroy();
        try minimum(testing.allocator, child, "auto");
    }
}

test "explicit minimums and other auto sizes remain unchanged without a box" {
    inline for (.{ "none", "contents" }) |display| {
        const style = try element(testing.allocator, null, "display: " ++ display ++ "; min-width: 7px; min-height: 25%; width: auto; height: auto");
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        inline for (.{
            .{ css.properties.Longhand.min_width, "7px" },
            .{ css.properties.Longhand.min_height, "25%" },
            .{ css.properties.Longhand.width, "auto" },
            .{ css.properties.Longhand.height, "auto" },
        }) |case| {
            out.clearRetainingCapacity();
            try style.serializeResolved(case[0], &out, testing.allocator);
            try testing.expectEqualStrings(case[1], out.items);
        }
    }
}

test "no box minimum serialization releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: Allocator) !void {
    const style = try element(allocator, null, "display: contents; min-width: auto; min-height: auto");
    defer style.destroy();
    try minimum(allocator, style, "0px");
}
