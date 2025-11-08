const std = @import("std");
const gb18030 = @import("../../src/chinese/gb18030.zig");

test "gb18030 decoder - ASCII" {
    var decoder = gb18030.Decoder{};

    try std.testing.expectEqual(@as(?u21, 'A'), try decoder.decode('A'));
    try std.testing.expectEqual(@as(?u21, 'Z'), try decoder.decode('Z'));
    try std.testing.expectEqual(@as(?u21, '0'), try decoder.decode('0'));
    try std.testing.expectEqual(@as(?u21, ' '), try decoder.decode(' '));
}

test "gb18030 decoder - Euro sign (0x80)" {
    var decoder = gb18030.Decoder{};
    try std.testing.expectEqual(@as(?u21, 0x20AC), try decoder.decode(0x80)); // €
}

test "gb18030 decoder - 2-byte sequence" {
    var decoder = gb18030.Decoder{};

    // Test 0x81 0x40 -> U+4E02
    try std.testing.expectEqual(@as(?u21, null), try decoder.decode(0x81)); // Continue
    try std.testing.expectEqual(@as(?u21, 0x4E02), try decoder.decode(0x40)); // 丂
}

test "gb18030 decoder - 4-byte sequence" {
    var decoder = gb18030.Decoder{};

    // Test 4-byte sequence: 0x81 0x30 0x81 0x30 -> U+0080
    try std.testing.expectEqual(@as(?u21, null), try decoder.decode(0x81)); // Continue
    try std.testing.expectEqual(@as(?u21, null), try decoder.decode(0x30)); // Continue
    try std.testing.expectEqual(@as(?u21, null), try decoder.decode(0x81)); // Continue
    try std.testing.expectEqual(@as(?u21, 0x0080), try decoder.decode(0x30)); // Result
}

test "gb18030 decoder - invalid sequence" {
    var decoder = gb18030.Decoder{};

    // Invalid second byte after leading byte
    _ = try decoder.decode(0x81);
    try std.testing.expectError(error.InvalidSequence, decoder.decode(0x20));
}

test "gb18030 decoder - end of stream with pending bytes" {
    var decoder = gb18030.Decoder{};

    _ = try decoder.decode(0x81);
    try std.testing.expectError(error.InvalidSequence, decoder.decode(null));
}

test "gb18030 encoder - ASCII" {
    const allocator = std.testing.allocator;
    const encoder = gb18030.Encoder{};

    const result_a = try encoder.encode(allocator, 'A');
    defer allocator.free(result_a);
    try std.testing.expectEqualSlices(u8, &[_]u8{'A'}, result_a);

    const result_0 = try encoder.encode(allocator, '0');
    defer allocator.free(result_0);
    try std.testing.expectEqualSlices(u8, &[_]u8{'0'}, result_0);
}

test "gb18030 encoder - Euro sign GBK mode" {
    const allocator = std.testing.allocator;
    const encoder = gb18030.Encoder{ .is_gbk = true };

    const result = try encoder.encode(allocator, 0x20AC); // €
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x80}, result);
}

test "gb18030 encoder - 2-byte sequence" {
    const allocator = std.testing.allocator;
    const encoder = gb18030.Encoder{};

    // U+4E02 -> 0x81 0x40
    const result = try encoder.encode(allocator, 0x4E02); // 丂
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x81, 0x40 }, result);
}

test "gb18030 encoder - 4-byte sequence" {
    const allocator = std.testing.allocator;
    const encoder = gb18030.Encoder{};

    // U+0080 -> 4-byte sequence
    const result = try encoder.encode(allocator, 0x0080);
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x81, 0x30, 0x81, 0x30 }, result);
}

test "gb18030 encoder - unencodable in GBK mode" {
    const allocator = std.testing.allocator;
    const encoder = gb18030.Encoder{ .is_gbk = true };

    // U+0080 requires 4-byte sequence, not available in GBK
    try std.testing.expectError(error.Unencodable, encoder.encode(allocator, 0x0080));
}

test "gb18030 encoder - special mappings" {
    const allocator = std.testing.allocator;
    const encoder = gb18030.Encoder{};

    // U+E78D -> 0xA6 0xD9 (special mapping)
    const result = try encoder.encode(allocator, 0xE78D);
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xA6, 0xD9 }, result);
}

test "gb18030 round-trip - ASCII" {
    const allocator = std.testing.allocator;
    var decoder = gb18030.Decoder{};
    const encoder = gb18030.Encoder{};

    const original: u21 = 'X';
    const encoded = try encoder.encode(allocator, original);
    defer allocator.free(encoded);

    for (encoded) |byte| {
        if (try decoder.decode(byte)) |decoded| {
            try std.testing.expectEqual(original, decoded);
            return;
        }
    }
}

test "gb18030 round-trip - 2-byte" {
    const allocator = std.testing.allocator;
    var decoder = gb18030.Decoder{};
    const encoder = gb18030.Encoder{};

    const original: u21 = 0x4E02; // 丂
    const encoded = try encoder.encode(allocator, original);
    defer allocator.free(encoded);

    for (encoded) |byte| {
        if (try decoder.decode(byte)) |decoded| {
            try std.testing.expectEqual(original, decoded);
            return;
        }
    }
}

test "gb18030 round-trip - 4-byte" {
    const allocator = std.testing.allocator;
    var decoder = gb18030.Decoder{};
    const encoder = gb18030.Encoder{};

    const original: u21 = 0x0080;
    const encoded = try encoder.encode(allocator, original);
    defer allocator.free(encoded);

    for (encoded) |byte| {
        if (try decoder.decode(byte)) |decoded| {
            try std.testing.expectEqual(original, decoded);
            return;
        }
    }
}
