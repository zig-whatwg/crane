const std = @import("std");
const encoding = @import("encoding");
const streams = encoding.streams;
const testing = std.testing;

test "encoder scalar state survives a ToString stub freeing its codec" {
    const original = try testing.allocator.create(streams.Encoder);
    original.* = .{ .allocator = testing.allocator, .leading_surrogate = 0xd83d };
    var active = original.*;
    const ToString = struct {
        fn run(codec: *streams.Encoder) []const u8 {
            codec.allocator.destroy(codec);
            // WTF-8 for the trailing surrogate paired with the saved lead.
            return "\xed\xb8\x80";
        }
    };
    const converted = ToString.run(original);
    const output = try active.push(converted, false);
    defer testing.allocator.free(output);
    try testing.expectEqualStrings("😀", output);
    try testing.expect(active.leading_surrogate == null);
}

fn expectPart(codec: anytype, input: []const u8, final: bool, expected: []const u8) !void {
    const result = try codec.push(input, final);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

test "stream encoder preserves split surrogate pairs and restores non-trailing code units" {
    var encoder: streams.Encoder = .{ .allocator = testing.allocator };
    try expectPart(&encoder, "\xed\xa0\xbd", false, "");
    try expectPart(&encoder, "", false, "");
    try expectPart(&encoder, "\xed\xb8\x80", false, "😀");
    try expectPart(&encoder, "\xed\xa0\xbd", false, "");
    try expectPart(&encoder, "A", false, "�A");
    try expectPart(&encoder, "\xed\xb8\x80", false, "�");
    try expectPart(&encoder, "\xed\xa0\xbd", true, "�");
}

test "stream decoder flushes state even when all bytes were consumed" {
    var decoder = streams.Decoder.init(testing.allocator, encoding.UTF_8, false, false);
    try expectPart(&decoder, &.{0xe2}, false, "");
    try expectPart(&decoder, &.{0x82}, false, "");
    try expectPart(&decoder, "", true, "�");
}

test "stream decoder does not swallow a restored byte after a split malformed sequence" {
    var decoder = streams.Decoder.init(testing.allocator, encoding.UTF_8, false, false);
    try expectPart(&decoder, &.{0xe2}, false, "");
    try expectPart(&decoder, "A", false, "�A");
    try expectPart(&decoder, &.{ 0xff, 0x41, 0xc2, 0x42 }, true, "�A�B");
}

test "stream decoder BOM is suppressed once, including across chunks" {
    var decoder = streams.Decoder.init(testing.allocator, encoding.UTF_8, false, false);
    try expectPart(&decoder, &.{0xef}, false, "");
    try expectPart(&decoder, &.{0xbb}, false, "");
    try expectPart(&decoder, &.{0xbf}, false, "");
    try expectPart(&decoder, "\xef\xbb\xbf😀", true, "\xef\xbb\xbf😀");
    var ignored = streams.Decoder.init(testing.allocator, encoding.UTF_8, false, true);
    try expectPart(&ignored, "\xef\xbb\xbfA", true, "\xef\xbb\xbfA");
}

test "stream decoder fatal errors reject malformed and truncated input" {
    var invalid = streams.Decoder.init(testing.allocator, encoding.UTF_8, true, false);
    try testing.expectError(error.InvalidData, invalid.push(&.{0xff}, false));
    var truncated = streams.Decoder.init(testing.allocator, encoding.UTF_8, true, false);
    try expectPart(&truncated, &.{0xe2}, false, "");
    try testing.expectError(error.InvalidData, truncated.push("", true));
}

test "stream decoder retains UTF-16 and legacy states across chunks" {
    var decoder = streams.Decoder.init(testing.allocator, &encoding.encoding.UTF_16LE, false, false);
    try expectPart(&decoder, &.{0xff}, false, "");
    try expectPart(&decoder, &.{ 0xfe, 0x3d, 0xd8 }, false, "");
    try expectPart(&decoder, &.{ 0, 0xde }, true, "😀");
    var legacy = streams.Decoder.init(testing.allocator, &encoding.encoding.WINDOWS_1252, false, false);
    try expectPart(&legacy, &.{ 0x80, 0x41 }, true, "€A");
}
