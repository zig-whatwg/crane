//! Tests migrated from src/encoding/html_encoding.zig
//! Per WHATWG specifications

const std = @import("std");

const encoding = @import("encoding");

test "HTML entity encoding - max code point" {
    const allocator = std.testing.allocator;

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    // Encode U+10FFFF as &#1114111;
    try encoding.encodeAsHtmlEntity(0x10FFFF, &output);

    const result = try output.toSlice(allocator);
    defer allocator.free(result);

    const expected = "&#1114111;";
    try std.testing.expectEqualStrings(expected, result);
}
test "HTML entity encoding to slice" {
    var buffer: [20]u8 = undefined;

    // Encode U+06DE
    const len = try encoding.encodeAsHtmlEntityToSlice(0x06DE, &buffer);

    const expected = "&#1758;";
    try std.testing.expectEqualStrings(expected, buffer[0..len]);
}
test "HTML entity encoding to slice - buffer too small" {
    var buffer: [4]u8 = undefined;

    // Should fail - need at least 5 bytes for &#65; but only have 4
    const result = encoding.encodeAsHtmlEntityToSlice(0x0041, &buffer);
    try std.testing.expectError(error.OutputBufferTooSmall, result);
}