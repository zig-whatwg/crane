const std = @import("std");
const TextDecoder = @import("../../src/text_decoder.zig").TextDecoder;
const TextDecoderOptions = @import("../../src/text_decoder_options.zig").TextDecoderOptions;
const TextDecodeOptions = @import("../../src/text_decode_options.zig").TextDecodeOptions;

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

    // "replacement" encoding should be rejected
    const result = TextDecoder.init(allocator, "replacement", .{});
    try std.testing.expectError(error.ReplacementEncoding, result);
}

test "TextDecoder - decode UTF-8 ASCII" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = "Hello, World!";
    const output = try decoder.decode(input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, World!", output);
}

test "TextDecoder - decode UTF-8 with multibyte characters" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = "Hello, 世界!";
    const output = try decoder.decode(input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello, 世界!", output);
}

test "TextDecoder - decode UTF-8 with BOM (removed by default)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 'H', 'i' }; // BOM + "Hi"
    const output = try decoder.decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hi", output);
}

test "TextDecoder - decode UTF-8 with BOM (kept if ignoreBOM=true)" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .ignoreBOM = true });
    defer decoder.deinit();

    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 'H', 'i' }; // BOM + "Hi"
    const output = try decoder.decode(&input, .{});
    defer allocator.free(output);

    // BOM should be kept (U+FEFF)
    try std.testing.expect(output.len > 2);
    try std.testing.expect(std.mem.startsWith(u8, output, "\u{FEFF}"));
}

test "TextDecoder - decode windows-1252" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "windows-1252", .{});
    defer decoder.deinit();

    // Windows-1252: 0xA9 = © (copyright sign)
    const input = [_]u8{ 0xA9, ' ', 0x32, 0x30, 0x32, 0x34 }; // "© 2024"
    const output = try decoder.decode(&input, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("© 2024", output);
}

test "TextDecoder - decode ISO-8859-2" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "iso-8859-2", .{});
    defer decoder.deinit();

    // ISO-8859-2: 0xE1 = á
    const input = [_]u8{ 0xE1, 0x62, 0x63 }; // "ábc"
    const output = try decoder.decode(&input, .{});
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

    const output = try decoder.decode("", .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("", output);
}
