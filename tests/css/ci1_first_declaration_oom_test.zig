//! An owned first declaration must unwind if the entry array cannot grow.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn firstDeclaration(allocator: std.mem.Allocator, text: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    try testing.expectEqual(@as(usize, 1), block.entries.items.len);
    try testing.expect(block.entries.items[0] == .typed);
}

test "a first owned text-indent declaration cleans up if entry allocation fails" {
    _ = css.properties.lookup("text-indent") orelse return error.TextIndentNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, firstDeclaration, .{"text-indent:1em hanging"});
}

test "a first owned cursor declaration cleans up if entry allocation fails" {
    _ = css.properties.lookup("cursor") orelse return error.CursorNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, firstDeclaration, .{"cursor:url(cursor.cur) 1 2, pointer"});
}
