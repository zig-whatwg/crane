//! The parser's byte decoding uses the handler's restored bytes/state.
const std = @import("std");
const sniffing = @import("html_core").parser.encoding_sniffing;
const testing = std.testing;

test "parser UTF-16LE decoding retains the code unit after an unpaired surrogate" {
    const document = [_]u8{ '<', 0, 'p', 0, '>', 0, 0, 0xd8, 'A', 0, '<', 0, '/', 0, 'p', 0, '>', 0 };
    const text = try sniffing.decodeWith(testing.allocator, &document, sniffing.lookup("utf-16le").?);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("<p>�A</p>", text);
}

test "parser ISO-2022-JP decoding restores an invalid escape and preserves Roman output state" {
    const document = "<p>\x1b(J\\\x1b(A\\\x1b(B</p>";
    const text = try sniffing.decodeWith(testing.allocator, document, sniffing.lookup("iso-2022-jp").?);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("<p>¥�(A¥</p>", text);
}
