//! CSS Writing Modes 4 §5.1, prerequisite for Values 4 ch/rch metrics.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn value(style: *const css.computed_style.ComputedStyle, expected: []const u8) !void {
    const property = css.properties.lookup("text-orientation") orelse return error.MissingTextOrientation;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(property.longhand, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "text orientation is inherited mixed by default with a strict keyword grammar" {
    const property = css.properties.lookup("text-orientation") orelse return error.MissingTextOrientation;
    const initial = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{});
    defer initial.destroy();
    try value(initial, "mixed");
    for ([_][]const u8{ "mixed", "upright", "sideways" }) |keyword| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "text-orientation", keyword, ""));
        const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
        defer child.destroy();
        try value(parent, keyword);
        try value(child, keyword);
    }
    for ([_][]const u8{ "vertical", "none", "auto", "mixed upright", "12", "'upright'" }) |invalid| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer assignments.deinit(testing.allocator);
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, invalid, &assignments));
    }
}

test "legacy orientation spellings follow the shipping browser mechanisms" {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    for ([_][]const u8{ "text-orientation", "-webkit-text-orientation" }) |name| {
        const property = css.properties.lookup(name) orelse return error.MissingLegacyOrientation;
        _ = property;
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, name, "sideways-right", ""));
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(if (name[0] == '-') "sideways" else "sideways-right", out.items);
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try value(style, "sideways");
    }
    const prefixed = css.properties.lookup("-webkit-text-orientation") orelse return error.MissingLegacyOrientation;
    for ([_][]const u8{ "upright", "sideways" }) |keyword| {
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "-webkit-text-orientation", keyword, ""));
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue("text-orientation", &out);
        try testing.expectEqualStrings(keyword, out.items);
        out.clearRetainingCapacity();
        try block.serialize(&out);
        try testing.expect(std.mem.startsWith(u8, out.items, "text-orientation:"));
    }
    for ([_][]const u8{ "mixed", "auto", "upright sideways" }) |invalid| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer assignments.deinit(testing.allocator);
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, prefixed, invalid, &assignments));
    }
}
