//! CSS Text3 §8.1: typed indentation and inherited computed components.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
fn expectValue(input: []const u8, expected: ?[]const u8) !void {
    const p = css.properties.lookup("text-indent") orelse return error.TextIndentNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments));
    if (expected) |text| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeAssigned(p.longhand, assignments.items[0].value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "text-indent keeps signed length percentage and optional keywords in canonical order" {
    try expectValue("10px", "10px");
    try expectValue("0", "0px");
    try expectValue("-2em", "-2em");
    try expectValue("-20%", "-20%");
    try expectValue("each-line -20% hanging", "-20% hanging each-line");
    try expectValue("hanging 1em", "1em hanging");
    try expectValue("EACH-LINE 3px", "3px each-line");
    for ([_][]const u8{ "", "auto", "none", "1", "10deg", "hanging", "each-line", "hanging each-line", "1px 2px", "1px hanging hanging", "1px each-line each-line", "1px, 2px" }) |bad| try expectValue(bad, null);
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    const p = css.properties.lookup("text-indent") orelse return error.TextIndentNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;text-indent:each-line -2em hanging");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqualStrings("-40px hanging each-line", out.items);
    try testing.expect(parent.get(p.longhand).eql(child.get(p.longhand)));
}

test "text-indent computed value inherits its flags and unwinds on allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}

test "text-indent allows quirky lengths only when quirks mode is enabled" {
    const property = css.properties.lookup("text-indent") orelse return error.TextIndentNotImplemented;
    for ([_]bool{ false, true }) |quirks| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(testing.allocator);
        }
        try testing.expectEqual(quirks, try css.properties.parseDeclaration(.{ .allocator = testing.allocator, .quirks = quirks }, property, "12", &assignments));
        if (quirks) try testing.expect(assignments.items[0].value.value.eql(css.style_values.Value.px(12)));
    }
}
