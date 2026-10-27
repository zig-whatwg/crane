//! SelectorText filters Unicode input through the shared component serializer.
const std = @import("std");
const css = @import("css");

fn check(a: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
    const actual = try css.rules.serializeComponentValues(a, input);
    defer a.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

fn cases(a: std.mem.Allocator) !void {
    try check(a, "foo\x00", "foo�");
    try check(a, "f\xed\xa0\x80oo", "f�oo");
    try check(a, "\x00\x00\x00", "���");
    try check(a, " \r\n.a\r.b\x0c.c\t", ".a .b .c");
    try check(a, "[x='a\x00b']", "[x=\"a�b\"]");
    try check(a, "a/**/b", "a/**/b");
    try check(a, "a/**/(", "a/**/(");
    try check(a, ":has(:is(.a,123))", ":has(:is(.a,123))");
    try check(a, "[x=\"broken\n]", "[x=\"broken\n ]");
}

test "selector component values preprocess names without joining distinct tokens" {
    try cases(std.testing.allocator);
}

test "selector component serialization unwinds every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cases, .{});
}
