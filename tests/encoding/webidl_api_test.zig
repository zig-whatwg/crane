const std = @import("std");
const encoding = @import("encoding");

// Type aliases from encoding module
const TextDecoder = encoding.TextDecoder;
const TextDecoderOptions = encoding.TextDecoderOptions;
const TextDecodeOptions = encoding.TextDecodeOptions;
const TextEncoder = encoding.TextEncoder;
const TextEncoderEncodeIntoResult = encoding.TextEncoderEncodeIntoResult;

// ============================================================================
// TextDecoder Tests
// ============================================================================

test "WebIDL TextDecoder - constructor with default options" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    try std.testing.expectEqualStrings("utf-8", decoder.encoding());
    try std.testing.expectEqual(false, decoder.getFatal());
    try std.testing.expectEqual(false, decoder.getIgnoreBOM());
}

test "WebIDL TextDecoder - constructor with fatal option" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .fatal = true });
    defer decoder.deinit();

    try std.testing.expectEqual(true, decoder.getFatal());
}

test "WebIDL TextDecoder - constructor with ignoreBOM option" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .ignoreBOM = true });
    defer decoder.deinit();

    try std.testing.expectEqual(true, decoder.getIgnoreBOM());
}

test "WebIDL TextDecoder - invalid encoding label" {
    const allocator = std.testing.allocator;

    const result = TextDecoder.init(allocator, "invalid-encoding-xyz", .{});
    try std.testing.expectError(error.InvalidEncoding, result);
}

test "WebIDL TextDecoder - replacement encoding rejected" {
    const allocator = std.testing.allocator;

    const result = TextDecoder.init(allocator, "replacement", .{});
    try std.testing.expectError(error.ReplacementEncoding, result);
}

test "WebIDL TextDecoder - decode UTF-8 ASCII" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = "Hello, World!";
    const output = try decoder.call_decode(input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, World!", output);
}

test "WebIDL TextDecoder - decode UTF-8 with multibyte characters" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = "Hello, 世界! 🌍";
    const output = try decoder.call_decode(input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, 世界! 🌍", output);
}

test "WebIDL TextDecoder - decode UTF-8 with BOM (default strips BOM)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    // UTF-8 BOM: EF BB BF
    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 'H', 'i' };
    const output = try decoder.call_decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hi", output);
}

test "WebIDL TextDecoder - decode UTF-8 with BOM (ignoreBOM keeps BOM)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .ignoreBOM = true });
    defer decoder.deinit();

    // UTF-8 BOM: EF BB BF (should NOT be stripped)
    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 'H', 'i' };
    const output = try decoder.call_decode(&input, .{});
    defer allocator.free(output);

    // BOM is kept (EF BB BF is valid UTF-8 for U+FEFF)
    try std.testing.expectEqualStrings("\u{FEFF}Hi", output);
}

test "WebIDL TextDecoder - decode windows-1252" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "windows-1252", .{});
    defer decoder.deinit();

    // 0xA9 is copyright symbol in windows-1252
    const input = [_]u8{ 0xA9, ' ', '2', '0', '2', '4' };
    const output = try decoder.call_decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("© 2024", output);
}

test "WebIDL TextDecoder - decode empty input" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const output = try decoder.call_decode("", .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("", output);
}

test "WebIDL TextDecoder - label case insensitive" {
    const allocator = std.testing.allocator;

    var decoder1 = try TextDecoder.init(allocator, "UTF-8", .{});
    defer decoder1.deinit();
    try std.testing.expectEqualStrings("utf-8", decoder1.encoding());

    var decoder2 = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder2.deinit();
    try std.testing.expectEqualStrings("utf-8", decoder2.encoding());

    var decoder3 = try TextDecoder.init(allocator, "  utf-8  ", .{});
    defer decoder3.deinit();
    try std.testing.expectEqualStrings("utf-8", decoder3.encoding());
}

// ============================================================================
// TextEncoder Tests
// ============================================================================

test "WebIDL TextEncoder - constructor" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    try std.testing.expectEqualStrings("utf-8", encoder.encoding());
}

test "WebIDL TextEncoder - encode ASCII string" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const input = "Hello, World!";
    const output = try encoder.call_encode(input);
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, World!", output);
}

test "WebIDL TextEncoder - encode UTF-8 with multibyte characters" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const input = "Hello, 世界! 🌍";
    const output = try encoder.call_encode(input);
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, 世界! 🌍", output);
}

test "WebIDL TextEncoder - encode empty string" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const output = try encoder.call_encode("");
    defer allocator.free(output);

    try std.testing.expectEqualStrings("", output);
}

test "WebIDL TextEncoder - encodeInto basic" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const source = "Hello";
    var destination = [_]u8{0} ** 10;

    const result = try encoder.encodeInto(source, &destination);

    try std.testing.expectEqual(@as(u64, 5), result.read);
    try std.testing.expectEqual(@as(u64, 5), result.written);
    try std.testing.expectEqualStrings("Hello", destination[0..5]);
}

test "WebIDL TextEncoder - encodeInto with emoji" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const source = "🌍"; // U+1F30D, 4 bytes in UTF-8
    var destination = [_]u8{0} ** 10;

    const result = try encoder.encodeInto(source, &destination);

    // UTF-8: 4 bytes read, 4 bytes written
    try std.testing.expectEqual(@as(u64, 4), result.read);
    try std.testing.expectEqual(@as(u64, 4), result.written);
    try std.testing.expectEqualStrings("🌍", destination[0..4]);
}

test "WebIDL TextEncoder - encodeInto insufficient space" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const source = "Hello, World!";
    var destination = [_]u8{0} ** 5; // Only 5 bytes

    const result = try encoder.encodeInto(source, &destination);

    // Should only write "Hello" (5 bytes read, 5 bytes written)
    try std.testing.expectEqual(@as(u64, 5), result.read);
    try std.testing.expectEqual(@as(u64, 5), result.written);
    try std.testing.expectEqualStrings("Hello", destination[0..5]);
}

test "WebIDL TextEncoder - encodeInto multibyte character truncation" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    const source = "Hi🌍"; // "Hi" (2 bytes) + emoji (4 bytes)
    var destination = [_]u8{0} ** 3; // Only 3 bytes (not enough for emoji)

    const result = try encoder.encodeInto(source, &destination);

    // Should only write "Hi" (2 bytes), stop before emoji
    try std.testing.expectEqual(@as(u64, 2), result.read);
    try std.testing.expectEqual(@as(u64, 2), result.written);
    try std.testing.expectEqualStrings("Hi", destination[0..2]);
}

// ============================================================================
// Round-trip Tests
// ============================================================================

test "WebIDL - TextDecoder/TextEncoder round-trip" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const original = "Hello, 世界! 🌍 © 2024";

    // Encode
    const encoded = try encoder.call_encode(original);
    defer allocator.free(encoded);

    // Decode
    const decoded = try decoder.call_decode(encoded, .{});
    defer allocator.free(decoded);

    // Should match original
    try std.testing.expectEqualStrings(original, decoded);
}
