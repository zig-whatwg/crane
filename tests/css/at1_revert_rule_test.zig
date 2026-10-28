//! attr-revert-rule.html: a selected fallback performs ordinary rule rollback.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(source: []const u8) !void {
    var first = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:green");
    defer first.deinit();
    var second = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, source);
    defer second.deinit();
    const matched = [_]css.cascade.Matched{
        .{ .block = &first, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &second, .source = .{ .origin = .author, .order = 2 } },
    };
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &matched);
    defer style.destroy();
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(testing.allocator);
    try style.serializeResolved(.color, &serialized, testing.allocator);
    try testing.expectEqualStrings("rgb(0, 128, 0)", serialized.items);
}

test "attr revert-rule: literal control discards the winning rule" {
    try check("color:red;color:revert-rule");
}

test "attr revert-rule: selected fallback discards the winning rule" {
    try check("color:red;color:attr(data-missing, revert-rule)");
}
