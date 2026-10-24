//! Stream's next-token offset includes the url() token's function spelling.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(input: []const u8, expected: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "content", input, ""));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("content", &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "content starts an unquoted URL at its token boundary" {
    try check("url(picture.svg) 'tail'", "url(\"picture.svg\") \"tail\"");
}
test "content retains quoted URL lookahead" {
    try check("url('picture.svg') 'tail'", "url(\"picture.svg\") \"tail\"");
}
test "content starts an escaped URL function at its token boundary" {
    try check("u\\72 l(picture.svg) 'tail'", "url(\"picture.svg\") \"tail\"");
}
test "content skips leading comments and padded unquoted URL whitespace" {
    try check("  /* prefix */ url( \tpicture.svg \n) 'tail'", "url(\"picture.svg\") \"tail\"");
}
test "content preserves a function following an unquoted URL" {
    try check("url(picture.svg) counter(item)", "url(\"picture.svg\") counter(item)");
}
test "content preserves an unquoted URL following a string" {
    try check("'lead' url(picture.svg)", "\"lead\" url(\"picture.svg\")");
}
