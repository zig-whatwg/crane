const std = @import("std");
const webidl = @import("webidl");
const encoding = @import("encoding");

const TextEncoder = encoding.TextEncoder;

test "TextEncoder - get_encoding returns utf-8 as DOMString" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: encoding getter returns DOMString (UTF-16)
    const encoding_name = encoder.get_encoding();
    const expected: []const u16 = &.{ 'u', 't', 'f', '-', '8' };
    try std.testing.expectEqualSlices(u16, expected, encoding_name);
}

test "TextEncoder - encode ASCII string" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: input is USVString (UTF-16)
    const input: []const u16 = &.{ 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!' };
    const result = try encoder.call_encode(input);
    defer result.buffer.deinit(allocator);
    defer allocator.destroy(result.buffer);

    // WebIDL: output is Uint8Array
    const output = try result.asConstSlice();
    const expected = "Hello, World!";
    try std.testing.expectEqualStrings(expected, output);
}

test "TextEncoder - encode UTF-16 string with emoji" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: input is USVString (UTF-16)
    // "Hello 🌍" - emoji U+1F30D requires surrogate pair in UTF-16
    const input: []const u16 = &.{ 'H', 'e', 'l', 'l', 'o', ' ', 0xD83C, 0xDF0D };
    const result = try encoder.call_encode(input);
    defer result.buffer.deinit(allocator);
    defer allocator.destroy(result.buffer);

    // WebIDL: output is Uint8Array (UTF-8 bytes)
    const output = try result.asConstSlice();
    const expected = "Hello 🌍";
    try std.testing.expectEqualStrings(expected, output);
}

test "TextEncoder - encode handles unpaired surrogates in USVString" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: USVString should NOT contain unpaired surrogates
    // But if they exist, they should be handled gracefully
    // High surrogate without low surrogate: 0xD800
    const input: []const u16 = &.{0xD800};
    const result = try encoder.call_encode(input);
    defer result.buffer.deinit(allocator);
    defer allocator.destroy(result.buffer);

    // WebIDL: output is Uint8Array
    // Unpaired surrogate should be encoded as itself (not U+FFFD for USVString)
    const output = try result.asConstSlice();
    // UTF-8 encoding of U+D800 (if preserved) or handled specially
    // Actually, USVString should have already replaced this with U+FFFD
    // For now, test that it encodes without error
    try std.testing.expect(output.len > 0);
}

test "TextEncoder - encodeInto basic" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: source is USVString (UTF-16)
    const source: []const u16 = &.{ 'H', 'e', 'l', 'l', 'o' };

    // WebIDL: destination is Uint8Array
    var buffer = try webidl.ArrayBuffer.init(allocator, 10);
    defer buffer.deinit(allocator);
    var destination = try webidl.TypedArray(u8).init(&buffer, 0, 10);

    const result = try encoder.encodeInto(source, destination);

    try std.testing.expectEqual(@as(u64, 5), result.read);
    try std.testing.expectEqual(@as(u64, 5), result.written);

    const output = try destination.asConstSlice();
    try std.testing.expectEqualStrings("Hello", output[0..5]);
}

test "TextEncoder - encodeInto with emoji" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: source is USVString (UTF-16)
    // "🌍" U+1F30D requires surrogate pair: 0xD83C 0xDF0D
    const source: []const u16 = &.{ 0xD83C, 0xDF0D };

    // WebIDL: destination is Uint8Array
    var buffer = try webidl.ArrayBuffer.init(allocator, 10);
    defer buffer.deinit(allocator);
    var destination = try webidl.TypedArray(u8).init(&buffer, 0, 10);

    const result = try encoder.encodeInto(source, destination);

    // Read 2 UTF-16 code units (surrogate pair), written 4 UTF-8 bytes
    try std.testing.expectEqual(@as(u64, 2), result.read);
    try std.testing.expectEqual(@as(u64, 4), result.written);

    const output = try destination.asConstSlice();
    try std.testing.expectEqualStrings("🌍", output[0..4]);
}

test "TextEncoder - encodeInto insufficient space" {
    const allocator = std.testing.allocator;
    var encoder = TextEncoder.init(allocator);
    defer encoder.deinit();

    // WebIDL: source is USVString (UTF-16)
    const source: []const u16 = &.{ 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!' };

    // WebIDL: destination is Uint8Array (only 5 bytes)
    var buffer = try webidl.ArrayBuffer.init(allocator, 5);
    defer buffer.deinit(allocator);
    var destination = try webidl.TypedArray(u8).init(&buffer, 0, 5);

    const result = try encoder.encodeInto(source, destination);

    // Should only write "Hello" (5 code units read, 5 bytes written)
    try std.testing.expectEqual(@as(u64, 5), result.read);
    try std.testing.expectEqual(@as(u64, 5), result.written);

    const output = try destination.asConstSlice();
    try std.testing.expectEqualStrings("Hello", output[0..5]);
}
