const std = @import("std");
const encoding = @import("encoding");

// Type aliases for cleaner code
const TextDecoder = encoding.TextDecoder;
const TextDecoderOptions = encoding.TextDecoderOptions;
const TextDecodeOptions = encoding.TextDecodeOptions;

test "TextDecoder - constructor with default label (utf-8)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    try std.testing.expectEqualStrings("UTF-8", decoder.get_encoding());
    try std.testing.expectEqual(false, decoder.get_fatal());
    try std.testing.expectEqual(false, decoder.get_ignoreBOM());
}

test "TextDecoder - constructor with options" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .fatal = true, .ignoreBOM = true });
    defer decoder.deinit();

    try std.testing.expectEqual(true, decoder.get_fatal());
    try std.testing.expectEqual(true, decoder.get_ignoreBOM());
}

test "TextDecoder - invalid encoding label" {
    const allocator = std.testing.allocator;

    const result = TextDecoder.init(allocator, "invalid-encoding", .{});
    try std.testing.expectError(error.InvalidEncoding, result);
}

test "TextDecoder - replacement encoding is rejected" {
    const allocator = std.testing.allocator;

    const result = TextDecoder.init(allocator, "replacement", .{});
    try std.testing.expectError(error.ReplacementEncoding, result);
}

test "TextDecoder - decode UTF-8 ASCII" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = "Hello, World!";
    const output = try decoder.call_decode(input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, World!", output);
}

test "TextDecoder - decode UTF-8 with multibyte characters" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = "Hello, 世界!";
    const output = try decoder.call_decode(input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, 世界!", output);
}

test "TextDecoder - decode UTF-8 with BOM (removed by default)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 'H', 'i' };
    const output = try decoder.call_decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hi", output);
}

test "TextDecoder - decode windows-1252" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "windows-1252", .{});
    defer decoder.deinit();

    const input = [_]u8{ 0xA9, ' ', 0x32, 0x30, 0x32, 0x34 };
    const output = try decoder.call_decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("© 2024", output);
}

test "TextDecoder - decode ISO-8859-2" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "iso-8859-2", .{});
    defer decoder.deinit();

    const input = [_]u8{ 0xE1, 0x62, 0x63 };
    const output = try decoder.call_decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("ábc", output);
}

test "TextDecoder - label variations (case insensitive)" {
    const allocator = std.testing.allocator;

    var decoder1 = try TextDecoder.init(allocator, "UTF-8", .{});
    defer decoder1.deinit();
    try std.testing.expectEqualStrings("UTF-8", decoder1.get_encoding());

    var decoder2 = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder2.deinit();
    try std.testing.expectEqualStrings("UTF-8", decoder2.get_encoding());

    var decoder3 = try TextDecoder.init(allocator, "  utf-8  ", .{});
    defer decoder3.deinit();
    try std.testing.expectEqualStrings("UTF-8", decoder3.get_encoding());
}

test "TextDecoder - empty input" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const output = try decoder.call_decode("", .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("", output);
}

test "TextDecoder - BOM reset bug (streaming then non-streaming)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    // UTF-8 BOM: EF BB BF
    const bom = [_]u8{ 0xEF, 0xBB, 0xBF };
    const hello = "Hello";
    const input_with_bom = bom ++ hello;

    // Step 1: Streaming decode (stream:true) - should strip BOM
    {
        const output1 = try decoder.call_decode(input_with_bom, .{ .stream = true });
        defer allocator.free(output1);
        try std.testing.expectEqualStrings("Hello", output1);
    }

    // Step 2: Non-streaming decode (stream:false) with BOM again
    // BUG: bom_seen flag is not reset, so BOM won't be stripped!
    {
        const output2 = try decoder.call_decode(input_with_bom, .{ .stream = false });
        defer allocator.free(output2);

        // Expected: "Hello" (BOM should be stripped because do_not_flush is reset)
        // Actual: "Hello" with BOM because bom_seen is not reset
        try std.testing.expectEqualStrings("Hello", output2);
    }
}
