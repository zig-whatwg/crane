//! Identifier names are Unicode code points; token offsets remain UTF-8 bytes.
const std = @import("std");
const up = @import("urlpattern");

test "URLPattern tokenizer accepts Unicode IdentifierName" {
    const cases = [_][]const u8{ "caf\xc3\xa9", "\xe5\x90\x8d", "\xf0\x90\x90\x80", "a\xcc\x81", "a\xe2\x80\x8c", "a\xe2\x80\x8d" };
    for (cases) |name| {
        const input = try std.fmt.allocPrint(std.testing.allocator, "/:{s}/", .{name});
        defer std.testing.allocator.free(input);
        var tokens = try up.tokenize(std.testing.allocator, input, .strict);
        defer tokens.deinit();
        try std.testing.expectEqual(up.TokenType.name, tokens.tokens[1].type);
        try std.testing.expectEqualStrings(name, tokens.tokens[1].value);
        try std.testing.expectEqual(@as(usize, 2) + name.len, tokens.tokens[2].index);
    }
}

test "URLPattern tokenizer rejects invalid identifier starts and non-ASCII regexp" {
    const invalid = [_][]const u8{ ":\xf0\x9f\x98\x80", ":\xcc\x81", ":\xe2\x80\x8c", "(\xc3\xa9)", "(\\\xc3\xa9)" };
    for (invalid) |input| try std.testing.expectError(error.InvalidPattern, up.tokenize(std.testing.allocator, input, .strict));
}

test "URLPattern tokenizer treats an escaped Unicode character as one token" {
    var tokens = try up.tokenize(std.testing.allocator, "\\\xc3\xa9:x", .strict);
    defer tokens.deinit();
    try std.testing.expectEqual(@as(usize, 3), tokens.tokens.len);
    try std.testing.expectEqualStrings("\xc3\xa9", tokens.tokens[0].value);
    try std.testing.expectEqual(@as(usize, 3), tokens.tokens[1].index);
}
