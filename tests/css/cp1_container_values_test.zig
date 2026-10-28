//! CSS Conditional 5 sections 5.1–5.3, independent of layout/query evaluation.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn specified(allocator: std.mem.Allocator, property: []const u8, input: []const u8, expected: []const u8) !void {
    _ = css.properties.lookup(property) orelse return error.MissingContainerProperty;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, property, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(property, &out);
    try std.testing.expectEqualStrings(expected, out.items);
}

fn valid(allocator: std.mem.Allocator) !void {
    try specified(allocator, "container-name", "none", "none");
    try specified(allocator, "container-name", "FOO foo FOO \\21 escaped auto normal", "FOO foo FOO \\!escaped auto normal");
    try specified(allocator, "container-type", "NORMAL", "normal");
    try specified(allocator, "container-type", "scroll-state INLINE-SIZE", "inline-size scroll-state");
    try specified(allocator, "container-type", "SIZE scroll-state", "size scroll-state");
    try specified(allocator, "container", "none / normal", "none");
    try specified(allocator, "container", "foo bar / normal", "foo bar");
    try specified(allocator, "container", "FOO/bar", "");
    try specified(allocator, "container", "FOO/scroll-state size", "FOO / size scroll-state");
    try specified(allocator, "container", "normal / size", "normal / size");
}

test "container names and types preserve case duplicates and grammar order" {
    errdefer std.debug.print("CP1_CONTAINER_CASE FAIL: container names and types preserve case duplicates and grammar order\n", .{});
    try valid(a);
    std.debug.print("CP1_CONTAINER_CASE PASS: container names and types preserve case duplicates and grammar order\n", .{});
}

test "container properties reject reserved names duplicate types and malformed shorthands" {
    errdefer std.debug.print("CP1_CONTAINER_CASE FAIL: container properties reject reserved names duplicate types and malformed shorthands\n", .{});
    for ([_][]const u8{ "none none", "foo, bar", "default", "and", "aNd", "not", "or", "foo initial", "foo inherit", "foo unset", "foo revert", "foo revert-layer", "foo default", "\"foo\"", "1px" }) |text|
        try specified(a, "container-name", text, "");
    for ([_][]const u8{ "none", "normal size", "size normal", "inline-size size", "scroll-state scroll-state", "size size", "auto", "block-size", "style", "size, scroll-state", "\"size\"" }) |text|
        try specified(a, "container-type", text, "");
    for ([_][]const u8{ "", "/ size", "foo /", "foo bar / size normal", "none foo", "foo / size / inline-size", "foo, bar" }) |text|
        try specified(a, "container", text, "");
    std.debug.print("CP1_CONTAINER_CASE PASS: container properties reject reserved names duplicate types and malformed shorthands\n", .{});
}

fn computed(allocator: std.mem.Allocator) !void {
    _ = css.properties.lookup("container") orelse return error.MissingContainerProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "--type: inline-size; container: FOO foo / var(--type)");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    inline for (.{ .{ "container-name", "FOO foo", "none" }, .{ "container-type", "inline-size", "normal" } }) |row| {
        const property = css.properties.lookup(row[0]).?.longhand;
        try parent.serializeResolved(property, &out, allocator);
        try std.testing.expectEqualStrings(row[1], out.items);
        out.clearRetainingCapacity();
        try child.serializeResolved(property, &out, allocator);
        try std.testing.expectEqualStrings(row[2], out.items);
        out.clearRetainingCapacity();
    }
    // A real pending shorthand is reparsed after substitution, including
    // the default type reset when the substituted value omits the slash.
    _ = try block.setProperty(.{ .allocator = allocator }, "container", "var(--names, new)", "");
    const reset = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer reset.destroy();
    try reset.serializeResolved(css.properties.lookup("container-type").?.longhand, &out, allocator);
    try std.testing.expectEqualStrings("normal", out.items);
}

test "container values compute through real substitution and do not inherit" {
    errdefer std.debug.print("CP1_CONTAINER_CASE FAIL: container values compute through real substitution and do not inherit\n", .{});
    try computed(a);
    std.debug.print("CP1_CONTAINER_CASE PASS: container values compute through real substitution and do not inherit\n", .{});
}

test "container value parsing and computation unwind every allocation failure" {
    errdefer std.debug.print("CP1_CONTAINER_CASE FAIL: container value parsing and computation unwind every allocation failure\n", .{});
    try std.testing.checkAllAllocationFailures(a, valid, .{});
    try std.testing.checkAllAllocationFailures(a, computed, .{});
    std.debug.print("CP1_CONTAINER_CASE PASS: container value parsing and computation unwind every allocation failure\n", .{});
}
