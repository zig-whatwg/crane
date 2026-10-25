//! Shared Q206 interim read-back checks. This is not complete CSS Variables support.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn checkText(allocator: std.mem.Allocator, property: []const u8, function: []const u8, setter: bool, important: bool) !void {
    const options: css.properties.ParseOptions = .{ .allocator = allocator };
    const source_value = try std.fmt.allocPrint(allocator, "  {s}  ", .{function});
    defer allocator.free(source_value);
    const priority = if (important) "important" else "";
    const input = try std.fmt.allocPrint(allocator, "{s}: {s}{s};", .{ property, source_value, if (important) " !important" else "" });
    defer allocator.free(input);
    const expected_value = std.mem.trim(u8, source_value, " \t\n\r\x0c");
    const source = try allocator.dupe(u8, if (setter) source_value else input);
    var source_owned = true;
    defer if (source_owned) allocator.free(source);

    var block = if (setter) css.declarations.DeclarationBlock.init(allocator) else try css.declarations.DeclarationBlock.parse(options, source);
    defer block.deinit();
    if (setter) try testing.expect(try block.setProperty(options, property, source, priority));
    @memset(source, 'x');
    allocator.free(source);
    source_owned = false;

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(property, &out);
    try testing.expectEqualStrings(expected_value, out.items);
    try testing.expectEqual(important, block.getPropertyPriority(property));
    out.clearRetainingCapacity();
    try block.serialize(&out);
    const expected_css = try std.fmt.allocPrint(allocator, "{s}: {s}{s};", .{ property, expected_value, if (important) " !important" else "" });
    defer allocator.free(expected_css);
    try testing.expectEqualStrings(expected_css, out.items);

    const shorthand = (css.properties.lookup(property) orelse return error.MissingShorthand).shorthand;
    for (shorthand.longhands()) |longhand| {
        out.clearRetainingCapacity();
        try block.getPropertyValue(longhand.name(), &out);
        try testing.expectEqualStrings("", out.items);
        try testing.expect(block.get(longhand) == null);
    }
    out.clearRetainingCapacity();
    try testing.expect(try block.removeProperty(property, &out));
    try testing.expectEqualStrings(expected_value, out.items);
    out.clearRetainingCapacity();
    try block.getPropertyValue(property, &out);
    try testing.expectEqualStrings("", out.items);
    try testing.expect(!block.getPropertyPriority(property));
    out.clearRetainingCapacity();
    try block.serialize(&out);
    try testing.expectEqualStrings("", out.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

pub fn allocationCase(allocator: std.mem.Allocator, property: []const u8, function: []const u8, setter: bool) !void {
    try checkText(allocator, property, function, setter, false);
    try checkText(allocator, property, function, setter, true);
}

pub fn rejectionControls() !void {
    inline for (.{ "var(--ci1)", "env(ci1)" }) |function| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "width", function, ""));
        try testing.expectEqual(@as(usize, 0), block.length());
    }
}
