//! CSS Text 4 §8.2: scalar computed tracking and the legacy resolved zero.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(allocator: std.mem.Allocator, input: []const u8, expected: []const u8, resolved: bool) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "letter-spacing", input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (resolved) {
        const property = css.properties.lookup("letter-spacing") orelse return error.MissingLetterSpacing;
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try style.serializeResolved(property.longhand, &out, allocator);
    } else try block.getPropertyValue("letter-spacing", &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "letter spacing accepts normal and signed lengths percentages and calculations" {
    inline for (.{
        .{ "normal", "normal" }, .{ "0", "0px" },     .{ "-10px", "-10px" },
        .{ "120%", "120%" },     .{ "-10%", "-10%" }, .{ "calc(2em + 3px)", "calc(2em + 3px)" },
    }) |c| try check(testing.allocator, c[0], c[1], false);
    for ([_][]const u8{ "auto", "20", "normal 10px", "10% 10px", "1s" }) |bad|
        try check(testing.allocator, bad, "", false);
}

test "letter spacing computes font relative lengths and resolves zero to normal" {
    try check(testing.allocator, "normal", "normal", true);
    try check(testing.allocator, "0px", "normal", true);
    try check(testing.allocator, "0%", "normal", true);
    try check(testing.allocator, "calc(0% + 0px)", "normal", true);
    try check(testing.allocator, "calc(2em - 32px)", "normal", true);
    try check(testing.allocator, "calc(2em - 10px)", "22px", true);
    try check(testing.allocator, "calc(10% - 20%)", "-10%", true);
    try check(testing.allocator, "calc(2em - 10%)", "calc(-10% + 32px)", true);
}

test "letter spacing inherits absolute lengths and percentages intact" {
    const property = css.properties.lookup("letter-spacing") orelse return error.MissingLetterSpacing;
    inline for (.{ .{ "1em", "20px" }, .{ "10%", "10%" }, .{ "normal", "normal" } }) |c| {
        const parent_text = try std.fmt.allocPrint(testing.allocator, "font-size:20px;letter-spacing:{s}", .{c[0]});
        defer testing.allocator.free(parent_text);
        var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, parent_text);
        defer parent_block.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:40px");
        defer child_block.deinit();
        const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
        defer child.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try child.serializeResolved(property.longhand, &out, testing.allocator);
        try testing.expectEqualStrings(c[1], out.items);
        if (std.mem.eql(u8, c[0], "normal")) {
            try testing.expectEqual(@as(f64, 0), child.get(property.longhand).length.value);
        }
    }
}

test "letter spacing parsing computation and serialization release every failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    try check(allocator, "calc(2em - 10%)", "calc(-10% + 32px)", true);
}
