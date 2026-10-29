//! Q32 regression helpers: retain actual cascade candidates, not CSSOM history.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

pub fn check(allocator: h.Allocator, name: []const u8, earlier: []const u8, later: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingBoxProperty;
    var low = h.Block.init(allocator);
    defer low.deinit();
    var high = h.Block.init(allocator);
    defer high.deinit();
    try testing.expect(try low.setProperty(.{ .allocator = allocator }, name, earlier, ""));
    try testing.expect(try high.setProperty(.{ .allocator = allocator }, name, later, ""));
    try testing.expect(high.get(property.longhand) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .user } },
        .{ .block = &high, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    if (expected) |text| return h.expect(style, name, text, allocator);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try h.read(style, name, &text, allocator);
    // Unknown cap geometry remains typed; it must not become the lower
    // candidate, a default, or pixels made from an invented font metric.
    try testing.expect(std.mem.indexOf(u8, text.items, "cap") != null);
}
