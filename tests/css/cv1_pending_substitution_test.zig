const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn computed(text: []const u8, longhand: css.properties.Longhand, expected: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(longhand, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "substitution preserves token boundaries and resolves nested ordinary functions" {
    try computed("left:random-item(fixed 0,20)px", .left, "auto");
    try computed("left:calc(random-item(fixed 0,20) * 1px)", .left, "20px");
    try computed("font-family:random-item(fixed 0,{Times,serif},sans-serif)", .font_family, "Times, serif");
}

test "spread expands before argument division but only with adjacent delimiter tokens" {
    try computed("left:random-item(...random-item(fixed 0,{fixed 1,3px,7px}))", .left, "7px");
    try computed("left:random-item(fixed 0,...random-item(fixed 0,{3px,7px}))", .left, "3px");
    try computed("left:random-item(fixed 1,... random-item(fixed 0,{3px,7px}),9px)", .left, "9px");
    try computed("left:random-item(fixed 0,... random-item(fixed 0,{3px,7px}),9px)", .left, "auto");
}

test "pending grammar checks all argument syntax while leaving a key unparsed" {
    inline for (.{
        "random-item()",                       "random-item(auto)",             "random-item(,1px)",
        "random-item(auto, !)",                "random-item(auto, ;)",          "random-item(auto, ])",
        "random-item(auto,{1px} extra)",       "random-item(auto,extra {1px})", "random-item(auto,{1px)",
        "random-item(auto,1px,random-item())",
    }) |text| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "left", text, ""));
    }
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "left", "random-item(invalid-key, 1px,2px)", ""));
}

test "pending shorthand serializes only its intact original set of placeholders" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin:random-item(fixed 0, 1px 2px, 3px)");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("margin", &out);
    try testing.expectEqualStrings("random-item(fixed 0, 1px 2px, 3px)", out.items);
    out.clearRetainingCapacity();
    try block.getPropertyValue("margin-left", &out);
    try testing.expectEqualStrings("", out.items);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "margin-left", "9px", "");
    try block.getPropertyValue("margin", &out);
    try testing.expectEqualStrings("", out.items);
}

test "selected fixed keys obtain sibling counts lazily with their source restriction" {
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    const Counter = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) css.math_values.TreeCounts {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 2, .count = 2 };
        }
    };
    var counter = Counter{};
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin:random-item(fixed calc(sibling-index() / sibling-count()),1px,2px)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .tree_counts = .{ .context = &counter, .get = Counter.get } }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try testing.expectEqual(@as(usize, 1), counter.calls);
    try testing.expectEqual(@as(f64, 2), style.get(.margin_left).length.value);
}
