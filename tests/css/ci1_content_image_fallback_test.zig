//! Q168: adding typed sole-color image() must preserve the existing content
//! fallback grammar. CSS Syntax 3 §5.5.10 closes open functions at EOF.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn emptyDoesNotReplace(allocator: Allocator, input: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = allocator };
    try testing.expect(try block.setProperty(options, "content", "\"previous\"", "important"));
    try testing.expect(!try block.setProperty(options, "content", input, ""));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("content", &out);
    try testing.expectEqualStrings("\"previous\"", out.items);
}

test "content image empty fallback remains invalid after typed color integration" {
    for ([_][]const u8{ "image()", "image(   )" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, emptyDoesNotReplace, .{input});
}

fn rawEof(allocator: Allocator, input: []const u8, expected: []const u8) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "content", input, ""));
        const value = block.get(.content).?.value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(.content, value, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "content image raw URL and direction forms keep EOF closure and owned text" {
    try testing.checkAllAllocationFailures(testing.allocator, rawEof, .{ "image(\"a.png\"", "image(\"a.png\")" });
    try testing.checkAllAllocationFailures(testing.allocator, rawEof, .{ "image(ltr \"a.png\"", "image(ltr \"a.png\")" });
}
