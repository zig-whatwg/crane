const std = @import("std");
const compression = @import("compression");
const testing = std.testing;
const foo = [_]u8{ 0x21, 0x08, 0x00, 0x04, 0x66, 0x6f, 0x6f, 0x03 };

test "Brotli stream rejects trailing bytes after preserving complete output" {
    if (!compression.brotli_supported) return;
    const decoder = try compression.Decoder.create(testing.allocator, .brotli);
    defer decoder.destroy();
    const trailing = foo ++ "x".*;
    try testing.expectError(error.InvalidData, decoder.push(&trailing, false));
    const prefix = decoder.takeValidPrefix();
    defer testing.allocator.free(prefix);
    try testing.expectEqualStrings("foo", prefix);
    try testing.expectError(error.InvalidData, decoder.push(&.{}, true));
}

test "Brotli stream empty chunks and final validation" {
    if (!compression.brotli_supported) return;
    const decoder = try compression.Decoder.create(testing.allocator, .brotli);
    defer decoder.destroy();
    const empty = try decoder.push(&.{}, false);
    defer testing.allocator.free(empty);
    try testing.expectEqual(@as(usize, 0), empty.len);
    try testing.expectError(error.InvalidData, decoder.push(&.{}, true));
}

test "Brotli stream round trips chunked input" {
    if (!compression.brotli_supported) return;
    const encoder = try compression.Encoder.create(testing.allocator, .brotli);
    defer encoder.destroy();
    const decoder = try compression.Decoder.create(testing.allocator, .brotli);
    defer decoder.destroy();
    var result: std.Io.Writer.Allocating = .init(testing.allocator);
    defer result.deinit();
    for ([_][]const u8{ "one", "", "two", "three" }, 0..) |chunk, i| {
        const encoded = try encoder.push(chunk, i == 3);
        defer testing.allocator.free(encoded);
        const decoded = try decoder.push(encoded, i == 3);
        defer testing.allocator.free(decoded);
        try result.writer.writeAll(decoded);
    }
    try testing.expectEqualStrings("onetwothree", result.written());
}
