//! IBM866 Integration Tests
//!
//! End-to-end tests for IBM866 (Cyrillic DOS) encoding.

const std = @import("std");
const encoding = @import("encoding");

test "IBM866 - decode Cyrillic text" {
    const allocator = std.testing.allocator;
    _ = allocator;

    // Get IBM866 encoding
    const ibm866 = encoding.getEncoding("ibm866") orelse return error.EncodingNotFound;
    try std.testing.expectEqualStrings("ibm866", ibm866.whatwg_name);

    // Create decoder
    var decoder = ibm866.newDecoder();

    // Input: bytes 0x80, 0x81, 0x82 → Cyrillic letters А, Б, В (U+0410, U+0411, U+0412)
    const input = [_]u8{ 0x80, 0x81, 0x82 };
    var output: [10]u16 = undefined;

    const result = decoder.decode(&input, &output, true);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x0410), output[0]); // А
    try std.testing.expectEqual(@as(u16, 0x0411), output[1]); // Б
    try std.testing.expectEqual(@as(u16, 0x0412), output[2]); // В
}

test "IBM866 - decode ASCII" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const ibm866 = encoding.getEncoding("866") orelse return error.EncodingNotFound;
    var decoder = ibm866.newDecoder();

    const input = "Hello";
    var output: [10]u16 = undefined;

    const result = decoder.decode(input, &output, true);

    try std.testing.expectEqual(@as(usize, 5), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 5), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 'H'), output[0]);
    try std.testing.expectEqual(@as(u16, 'e'), output[1]);
    try std.testing.expectEqual(@as(u16, 'l'), output[2]);
    try std.testing.expectEqual(@as(u16, 'l'), output[3]);
    try std.testing.expectEqual(@as(u16, 'o'), output[4]);
}

test "IBM866 - encode Cyrillic back" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const ibm866 = encoding.getEncoding("ibm866") orelse return error.EncodingNotFound;
    const encoder = ibm866.newEncoder() orelse return error.NoEncoder;
    var enc = encoder;

    // Input: Cyrillic letters А, Б, В
    const input = [_]u16{ 0x0410, 0x0411, 0x0412 };
    var output: [10]u8 = undefined;

    const result = enc.encode(&input, &output, true);

    try std.testing.expectEqual(@as(usize, 3), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
    try std.testing.expectEqual(@as(u8, 0x80), output[0]);
    try std.testing.expectEqual(@as(u8, 0x81), output[1]);
    try std.testing.expectEqual(@as(u8, 0x82), output[2]);
}

test "IBM866 - mixed ASCII and Cyrillic" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const ibm866 = encoding.getEncoding("ibm866") orelse return error.EncodingNotFound;
    var decoder = ibm866.newDecoder();

    // "Hi " + Cyrillic А (0x80)
    const input = [_]u8{ 'H', 'i', ' ', 0x80 };
    var output: [10]u16 = undefined;

    const result = decoder.decode(&input, &output, true);

    try std.testing.expectEqual(@as(usize, 4), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 'H'), output[0]);
    try std.testing.expectEqual(@as(u16, 'i'), output[1]);
    try std.testing.expectEqual(@as(u16, ' '), output[2]);
    try std.testing.expectEqual(@as(u16, 0x0410), output[3]); // А
}

test "IBM866 - round-trip" {
    const allocator = std.testing.allocator;
    _ = allocator;

    const ibm866 = encoding.getEncoding("ibm866") orelse return error.EncodingNotFound;

    // Original bytes
    const original = [_]u8{ 0x80, 0x81, 0x82, 'A', 'B', 'C' };

    // Decode
    var decoder = ibm866.newDecoder();
    var utf16: [10]u16 = undefined;
    const decode_result = decoder.decode(&original, &utf16, true);
    try std.testing.expectEqual(@as(usize, 6), decode_result.code_units_written);

    // Encode back
    const encoder = ibm866.newEncoder() orelse return error.NoEncoder;
    var enc = encoder;
    var bytes: [10]u8 = undefined;
    const encode_result = enc.encode(utf16[0..decode_result.code_units_written], &bytes, true);

    // Should match original
    try std.testing.expectEqual(@as(usize, 6), encode_result.bytes_written);
    try std.testing.expectEqualSlices(u8, &original, bytes[0..encode_result.bytes_written]);
}
