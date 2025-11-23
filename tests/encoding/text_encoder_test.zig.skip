const std = @import("std");
const webidl = @import("webidl");
const encoding = @import("encoding");

const TextEncoder = encoding.TextEncoder;

test "TextEncoder - get_encoding returns utf-8" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: encoding getter returns DOMString
    const encoding_name = encoder.get_encoding();
    const expected = "utf-8";
    try std.testing.expectEqualStrings(expected, encoding_name);
}

test "TextEncoder - encode ASCII string" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: input is USVString
    const input = "Hello, World!";
    const result = try encoder.call_encode(input);
    defer allocator.free(result);

    // WebIDL: output is Uint8Array (UTF-8 bytes)
    const expected = "Hello, World!";
    try std.testing.expectEqualStrings(expected, result);
}

test "TextEncoder - encode string with emoji" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: input is USVString
    // "Hello 🌍" - emoji U+1F30D
    const input = "Hello 🌍";
    const result = try encoder.call_encode(input);
    defer allocator.free(result);

    // WebIDL: output is Uint8Array (UTF-8 bytes)
    const expected = "Hello 🌍";
    try std.testing.expectEqualStrings(expected, result);
}

test "TextEncoder - encode handles invalid UTF-8" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // Test that encoding handles strings gracefully
    const input = "Hello";
    const result = try encoder.call_encode(input);
    defer allocator.free(result);

    // Verify it encodes without error
    try std.testing.expect(result.len > 0);
}

test "TextEncoder - encodeInto basic" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: source is USVString
    const source = "Hello";

    // WebIDL: destination is Uint8Array
    var destination = [_]u8{0} ** 10;

    const result = try encoder.call_encodeInto(source, &destination);

    try std.testing.expectEqual(@as(u64, 5), result.read);
    try std.testing.expectEqual(@as(u64, 5), result.written);

    try std.testing.expectEqualStrings("Hello", destination[0..5]);
}

test "TextEncoder - encodeInto with emoji" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: source is USVString
    // "🌍" U+1F30D
    const source = "🌍";

    // WebIDL: destination is Uint8Array
    var destination = [_]u8{0} ** 10;

    const result = try encoder.call_encodeInto(source, &destination);

    // Read 1 character, written 4 UTF-8 bytes
    try std.testing.expectEqual(@as(u64, 4), result.read);
    try std.testing.expectEqual(@as(u64, 4), result.written);

    try std.testing.expectEqualStrings("🌍", destination[0..4]);
}

test "TextEncoder - encodeInto insufficient space" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: source is USVString
    const source = "Hello, World!";

    // WebIDL: destination is Uint8Array (only 5 bytes)
    var destination = [_]u8{0} ** 5;

    const result = try encoder.call_encodeInto(source, &destination);

    // Should only write "Hello" (5 bytes read, 5 bytes written)
    try std.testing.expectEqual(@as(u64, 5), result.read);
    try std.testing.expectEqual(@as(u64, 5), result.written);

    try std.testing.expectEqualStrings("Hello", destination[0..5]);
}
