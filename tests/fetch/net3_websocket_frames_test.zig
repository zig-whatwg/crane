//! RFC 6455 framing as kit/curl's WebSocket transport does it (lane net3):
//! the client's masked frames (5.3), sent in parts with one header; the
//! server's frames decoded as they arrive, a control frame whole; and what
//! the client must fail the connection for (5.1, 5.2, 5.4, 5.5).
const std = @import("std");
const frames = @import("kit_curl_share").websocket_frames;
const Encoder = frames.Encoder;
const Decoder = frames.Decoder;
const Kind = frames.Kind;
const encodeHeader = frames.encodeHeader;
const max_header_len = frames.max_header_len;
const max_control_payload = frames.max_control_payload;

fn fixedKey(key: *[4]u8) void {
    key.* = .{ 0x37, 0xfa, 0x21, 0x3d };
}

test "a masked text frame is RFC 6455 5.7's example" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    var encoder: Encoder = .{};
    try std.testing.expectEqual(@as(usize, 5), try encoder.write(std.testing.allocator, &out, .text, "Hello", 5, fixedKey));
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 }, out.items);
    try std.testing.expect(!encoder.busy());
}

test "a frame sent in parts keeps one header and one mask" {
    var whole: std.ArrayList(u8) = .empty;
    defer whole.deinit(std.testing.allocator);
    var parts: std.ArrayList(u8) = .empty;
    defer parts.deinit(std.testing.allocator);
    var a: Encoder = .{};
    _ = try a.write(std.testing.allocator, &whole, .binary, "abcdefghij", 100, fixedKey);
    var b: Encoder = .{};
    try std.testing.expectEqual(@as(usize, 3), try b.write(std.testing.allocator, &parts, .binary, "abcdefghij", 3, fixedKey));
    try std.testing.expect(b.busy());
    try std.testing.expectError(error.FrameKindChanged, b.write(std.testing.allocator, &parts, .text, "defghij", 3, fixedKey));
    try std.testing.expectEqual(@as(usize, 7), try b.write(std.testing.allocator, &parts, .binary, "defghij", 100, fixedKey));
    try std.testing.expect(!b.busy());
    try std.testing.expectEqualSlices(u8, whole.items, parts.items);
}

test "payload lengths take 7, 16 and 64 bits" {
    var header: [max_header_len]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 6), encodeHeader(&header, .binary, true, 125, .{ 0, 0, 0, 0 }));
    try std.testing.expectEqual(@as(u8, 0x80 | 125), header[1]);
    try std.testing.expectEqual(@as(usize, 8), encodeHeader(&header, .binary, true, 256, .{ 0, 0, 0, 0 }));
    try std.testing.expectEqualSlices(u8, &.{ 0x82, 0xFE, 0x01, 0x00 }, header[0..4]);
    try std.testing.expectEqual(@as(usize, 14), encodeHeader(&header, .binary, true, 65536, .{ 0, 0, 0, 0 }));
    try std.testing.expectEqualSlices(u8, &.{ 0x82, 0xFF, 0, 0, 0, 0, 0, 1, 0, 0 }, header[0..10]);
}

test "unmasked frames from the server decode one byte at a time" {
    // 5.7: a fragmented unmasked text message, a ping, and a 256-byte binary
    // frame, fed a byte per call.
    var input: std.ArrayList(u8) = .empty;
    defer input.deinit(std.testing.allocator);
    try input.appendSlice(std.testing.allocator, &.{ 0x01, 0x03, 'H', 'e', 'l', 0x89, 0x05, 'H', 'e', 'l', 'l', 'o', 0x80, 0x02, 'l', 'o', 0x82, 0x7E, 0x01, 0x00 });
    for (0..256) |i| try input.append(std.testing.allocator, @truncate(i));

    var decoder: Decoder = .{};
    var buf: [max_control_payload]u8 = undefined;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(std.testing.allocator);
    var binary: std.ArrayList(u8) = .empty;
    defer binary.deinit(std.testing.allocator);
    var pings: usize = 0;
    var ends: usize = 0;
    for (0..input.items.len) |i| {
        const result = try decoder.decode(input.items[i .. i + 1], &buf);
        try std.testing.expectEqual(@as(usize, 1), result.consumed);
        const chunk = result.chunk orelse continue;
        switch (chunk.kind) {
            .text => {
                try text.appendSlice(std.testing.allocator, buf[0..chunk.len]);
                if (chunk.bytes_left == 0 and !chunk.more_fragments) ends += 1;
            },
            .ping => {
                pings += 1;
                try std.testing.expectEqualStrings("Hello", buf[0..chunk.len]);
            },
            .binary => try binary.appendSlice(std.testing.allocator, buf[0..chunk.len]),
            else => return error.TestUnexpectedResult,
        }
    }
    try std.testing.expectEqualStrings("Hello", text.items);
    try std.testing.expectEqual(@as(usize, 1), ends);
    try std.testing.expectEqual(@as(usize, 1), pings);
    try std.testing.expectEqual(@as(usize, 256), binary.items.len);
    try std.testing.expectEqual(@as(u8, 255), binary.items[255]);
}

test "an empty frame is a chunk of its own" {
    var decoder: Decoder = .{};
    var buf: [max_control_payload]u8 = undefined;
    const result = try decoder.decode(&.{ 0x81, 0x00 }, &buf);
    try std.testing.expectEqual(@as(usize, 2), result.consumed);
    const chunk = result.chunk.?;
    try std.testing.expectEqual(Kind.text, chunk.kind);
    try std.testing.expectEqual(@as(usize, 0), chunk.len);
    try std.testing.expectEqual(@as(u64, 0), chunk.bytes_left);
    try std.testing.expect(!chunk.more_fragments);
}

test "what the client must fail the connection for (RFC 6455 5.1, 5.2, 5.4, 5.5)" {
    var buf: [max_control_payload]u8 = undefined;
    for ([_][]const u8{
        &.{ 0x81, 0x81, 1, 2, 3, 4, 'x' }, // masked by the server
        &.{ 0xC1, 0x00 }, // RSV1 with no extension
        &.{ 0x83, 0x00 }, // reserved opcode 3
        &.{ 0x8B, 0x00 }, // reserved control opcode 0xB
        &.{ 0x80, 0x00 }, // a continuation with no message
        &.{ 0x09, 0x00 }, // a fragmented ping
        &.{ 0x89, 0x7E, 0x00, 0x7E }, // a 126-byte ping
        &.{ 0x82, 0x7F, 0x80, 0, 0, 0, 0, 0, 0, 0 }, // a 64-bit length with its top bit set
    }) |frame| {
        var decoder: Decoder = .{};
        try std.testing.expectError(error.ProtocolError, decoder.decode(frame, &buf));
    }
    // A new data message inside a fragmented one.
    var decoder: Decoder = .{};
    _ = try decoder.decode(&.{ 0x01, 0x01, 'a' }, &buf);
    try std.testing.expectError(error.ProtocolError, decoder.decode(&.{ 0x81, 0x01, 'b' }, &buf));
}

test "a control frame between two fragments is allowed (5.4)" {
    var decoder: Decoder = .{};
    var buf: [max_control_payload]u8 = undefined;
    var r = try decoder.decode(&.{ 0x02, 0x01, 'a' }, &buf);
    try std.testing.expect(r.chunk.?.more_fragments);
    r = try decoder.decode(&.{ 0x8A, 0x00 }, &buf);
    try std.testing.expectEqual(Kind.pong, r.chunk.?.kind);
    r = try decoder.decode(&.{ 0x80, 0x01, 'b' }, &buf);
    try std.testing.expectEqual(Kind.binary, r.chunk.?.kind);
    try std.testing.expect(!r.chunk.?.more_fragments);
    try std.testing.expectEqualStrings("b", buf[0..r.chunk.?.len]);
}
