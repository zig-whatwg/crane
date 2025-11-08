const std = @import("std");
const encoding = @import("encoding");
const TextDecoder = encoding.TextDecoder;
const TextEncoder = encoding.TextEncoder;

test "TextDecoder - no memory leaks with repeated decode()" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const output = try decoder.decode("Hello, World!", .{});
        defer allocator.free(output);
        try std.testing.expectEqualStrings("Hello, World!", output);
    }
}

test "TextDecoder - no memory leaks with streaming" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const chunk1 = try decoder.decode("Hello", .{ .stream = true });
    defer allocator.free(chunk1);

    const chunk2 = try decoder.decode(", ", .{ .stream = true });
    defer allocator.free(chunk2);

    const chunk3 = try decoder.decode("World!", .{ .stream = false });
    defer allocator.free(chunk3);

    try std.testing.expectEqualStrings("Hello", chunk1);
    try std.testing.expectEqualStrings(", ", chunk2);
    try std.testing.expectEqualStrings("World!", chunk3);
}

test "TextDecoder - no memory leaks with fatal error" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .fatal = true });
    defer decoder.deinit();

    const invalid_utf8 = &[_]u8{ 0xFF, 0xFE };
    const result = decoder.decode(invalid_utf8, .{});

    try std.testing.expectError(error.DecodingError, result);
}

test "TextDecoder - no memory leaks with BOM" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{ .ignoreBOM = false });
    defer decoder.deinit();

    const with_bom = "\xEF\xBB\xBFHello";
    const output = try decoder.decode(with_bom, .{});
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello", output);
}

test "TextDecoder - no memory leaks with large input" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const large_input = try allocator.alloc(u8, 10 * 1024);
    defer allocator.free(large_input);
    @memset(large_input, 'A');

    const output = try decoder.decode(large_input, .{});
    defer allocator.free(output);

    try std.testing.expectEqual(@as(usize, 10 * 1024), output.len);
}

test "TextDecoder - buffer reuse correctness" {
    const allocator = std.testing.allocator;

    var decoder = try TextDecoder.init(allocator, "utf-8", .{});
    defer decoder.deinit();

    const small = try decoder.decode("Hi", .{});
    defer allocator.free(small);
    try std.testing.expectEqualStrings("Hi", small);

    const large_input = try allocator.alloc(u8, 1000);
    defer allocator.free(large_input);
    @memset(large_input, 'X');

    const large = try decoder.decode(large_input, .{});
    defer allocator.free(large);
    try std.testing.expectEqual(@as(usize, 1000), large.len);

    const small2 = try decoder.decode("Bye", .{});
    defer allocator.free(small2);
    try std.testing.expectEqualStrings("Bye", small2);
}

test "TextEncoder - no memory leaks with repeated encode()" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const output = try encoder.encode("Hello, World!");
        defer allocator.free(output);
        try std.testing.expectEqualStrings("Hello, World!", output);
    }
}

test "TextEncoder - no memory leaks with invalid UTF-8" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);

    const invalid_utf8 = &[_]u8{ 'H', 'i', 0xFF, '!' };
    const output = try encoder.encode(invalid_utf8);
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
}

test "TextEncoder - no memory leaks with large input" {
    const allocator = std.testing.allocator;

    var encoder = TextEncoder.init(allocator);

    const large_input = try allocator.alloc(u8, 10 * 1024);
    defer allocator.free(large_input);
    @memset(large_input, 'B');

    const output = try encoder.encode(large_input);
    defer allocator.free(output);

    try std.testing.expectEqual(@as(usize, 10 * 1024), output.len);
}
