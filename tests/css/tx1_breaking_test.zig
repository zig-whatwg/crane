//! CSS Text 4 §§6.1–6.4: keyword grammars and the word-wrap legacy alias.
const std = @import("std");
const css = @import("css");

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, expected: []const u8) !void {
    try std.testing.expect(css.properties.lookup(name) != null);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try std.testing.expectEqualStrings(expected, text.items);
    if (expected.len == 0) return;
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    text.clearRetainingCapacity();
    try child.serializeResolved(css.properties.lookup(name).?.longhand, &text, allocator);
    try std.testing.expectEqualStrings(expected, text.items);
}

test "text breaking keywords parse and inherit with their complete grammars" {
    const groups = .{
        .{ "hyphens", &[_][]const u8{ "none", "manual", "auto" } },
        .{ "line-break", &[_][]const u8{ "auto", "loose", "normal", "strict", "anywhere" } },
        .{ "word-break", &[_][]const u8{ "normal", "break-all", "keep-all", "manual", "auto-phrase", "break-word" } },
        .{ "overflow-wrap", &[_][]const u8{ "normal", "break-word", "anywhere" } },
        .{ "word-wrap", &[_][]const u8{ "normal", "break-word", "anywhere" } },
    };
    inline for (groups) |group| {
        for (group[1]) |keyword| try check(std.testing.allocator, group[0], keyword, keyword);
        for ([_][]const u8{ "unknown", "1", "normal auto", "auto, normal" }) |bad| try check(std.testing.allocator, group[0], bad, "");
    }
    try check(std.testing.allocator, "word-break", "BR\\45 AK-ALL", "break-all");
    try check(std.testing.allocator, "hyphens", "/* before */ AUTO /* after */", "auto");
}

test "text breaking initial values and word-wrap alias use one canonical slot" {
    const allocator = std.testing.allocator;
    const initial = try css.computed_style.ComputedStyle.initial(allocator);
    defer initial.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    inline for (.{ .{ "hyphens", "manual" }, .{ "line-break", "auto" }, .{ "word-break", "normal" }, .{ "overflow-wrap", "normal" } }) |pair| {
        const property = css.properties.lookup(pair[0]) orelse return error.MissingTextProperty;
        text.clearRetainingCapacity();
        try initial.serializeResolved(property.longhand, &text, allocator);
        try std.testing.expectEqualStrings(pair[1], text.items);
    }
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "overflow-wrap:normal;word-wrap:ANYWHERE !important;word-wrap:invalid");
    defer block.deinit();
    text.clearRetainingCapacity();
    try block.getPropertyValue("overflow-wrap", &text);
    try std.testing.expectEqualStrings("anywhere", text.items);
    try std.testing.expectEqual(css.properties.lookup("overflow-wrap").?, css.properties.lookup("word-wrap").?);
}

test "text breaking declaration and computed ownership survive every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "hyphens", "auto", "auto" });
}
