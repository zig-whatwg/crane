//! Shared allocation-checking helpers for the box-property regression tests.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
pub const Allocator = std.mem.Allocator;
pub const Style = css.computed_style.ComputedStyle;
pub const Block = css.declarations.DeclarationBlock;

pub fn read(style: *const Style, name: []const u8, out: *std.ArrayList(u8), allocator: Allocator) !void {
    const property = css.properties.lookup(name) orelse return error.MissingBoxProperty;
    if (property == .longhand) return style.serializeResolved(property.longhand, out, allocator);
    if (try style.serializeResolvedShorthand(property.shorthand, out, allocator)) return;
    var assignments: [css.properties.max_assignments]css.properties.Assigned = undefined;
    const longhands = property.shorthand.longhands();
    for (longhands, 0..) |longhand, i| assignments[i] = .{ .value = style.get(longhand) };
    if (!try css.properties.serializeShorthand(property.shorthand, assignments[0..longhands.len], .computed, out, allocator))
        out.clearRetainingCapacity();
}

pub fn expect(style: *const Style, name: []const u8, expected: []const u8, allocator: Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try read(style, name, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

pub fn compute(allocator: Allocator, block: *const Block, parent: ?*const Style) !*Style {
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = block, .source = .{ .origin = .author } }});
}

pub fn check(allocator: Allocator, name: []const u8, input: []const u8, expected: []const u8, resolved: bool) !void {
    // Recognition is a separate assertion: unsupported declarations can be
    // stored for specified readback, which must not make a positive test pass.
    _ = css.properties.lookup(name) orelse return error.MissingBoxProperty;
    var block = Block.init(allocator);
    defer block.deinit();
    const accepted = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    if (expected.len > 0) try testing.expect(accepted);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (resolved) {
        const style = try compute(allocator, &block, null);
        defer style.destroy();
        try read(style, name, &out, allocator);
    } else try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

pub fn specified(block: *const Block, name: []const u8, expected: []const u8, allocator: Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}
