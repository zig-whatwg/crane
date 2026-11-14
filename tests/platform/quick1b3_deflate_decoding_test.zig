//! The deflate_decoding capability (src/platform/protocol.zig, kit/inflate/
//! zlib.zig): raw DEFLATE (RFC 1951) decoded by zlib's own inflate, a chunk
//! at a time, with the caller's allocator - what Fetch's "gzip" and
//! "deflate" content codings run (src/fetch/content_coding/flate.zig), as
//! Chromium's GzipSourceStream and Firefox's nsHTTPCompressConv run zlib.
//!
//! The streams are made by other encoders than the decoder under test:
//! Python's zlib (raw, level 9: fixtures/zlib/small.deflate, the same bytes
//! as tests/fetch/fixtures/content_coding/small.deflate) and Zig's own
//! std.compress.flate compressor (the 1 MB body).
const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

const small_deflate = @embedFile("fixtures/zlib/small.deflate");

/// tests/fetch/quick1b3_coding_fixtures.zig `small`: 40 lines, 2,519 bytes.
fn small(allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    for (0..40) |i| {
        try out.print(allocator, "line {d}: the quick brown fox jumps over the lazy dog, {d} times.\n", .{ i, (i * 7) % 13 });
    }
    return out.toOwnedSlice(allocator);
}

const supported = platform.capabilities.deflate_decoding != .unsupported;

/// Decode `pieces` in order through one decoder, `out_len` bytes of output
/// per call; the decoded bytes (OWNED) and the last status.
fn decodePieces(allocator: std.mem.Allocator, pieces: []const []const u8, out_len: usize) !struct { bytes: []u8, status: platform.CodecStatus, left: usize } {
    const decoder = try platform.createDeflateDecoder(allocator);
    defer platform.destroyDeflateDecoder(decoder);
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    const buffer = try allocator.alloc(u8, out_len);
    defer allocator.free(buffer);
    var status: platform.CodecStatus = .need_input;
    var left: usize = 0;
    for (pieces) |piece| {
        var input = piece;
        while (true) {
            const progress = try platform.decompressDeflate(decoder, .from(input), buffer);
            try testing.expect(progress.consumed <= input.len);
            try testing.expect(progress.produced <= buffer.len);
            input = input[progress.consumed..];
            try out.appendSlice(allocator, buffer[0..progress.produced]);
            status = progress.status;
            switch (progress.status) {
                .need_output => continue,
                // need_input means every byte given was taken.
                .need_input => {
                    try testing.expectEqual(@as(usize, 0), input.len);
                    break;
                },
                .finished => break,
            }
        }
        left = input.len;
        if (status == .finished) break;
    }
    return .{ .bytes = try out.toOwnedSlice(allocator), .status = status, .left = left };
}

test "deflate_decoding decodes a whole stream in one call" {
    // Supported where the bundled libcurl links the zlib build.zig.zon pins
    // (every platform but a -Dsystem-curl build).
    if (!supported) return;
    const text = try small(testing.allocator);
    defer testing.allocator.free(text);
    const result = try decodePieces(testing.allocator, &.{small_deflate}, 64 * 1024);
    defer testing.allocator.free(result.bytes);
    try testing.expectEqual(platform.CodecStatus.finished, result.status);
    try testing.expectEqual(@as(usize, 0), result.left);
    try testing.expectEqualStrings(text, result.bytes);
}

test "deflate_decoding: the stream split at every byte decodes the same" {
    if (!supported) return;
    const text = try small(testing.allocator);
    defer testing.allocator.free(text);
    for (0..small_deflate.len + 1) |split| {
        const result = try decodePieces(testing.allocator, &.{ small_deflate[0..split], small_deflate[split..] }, 64);
        defer testing.allocator.free(result.bytes);
        try testing.expectEqual(platform.CodecStatus.finished, result.status);
        try testing.expectEqualStrings(text, result.bytes);
    }
}

test "deflate_decoding: a one-byte output asks for more output, never loses a byte" {
    if (!supported) return;
    const text = try small(testing.allocator);
    defer testing.allocator.free(text);
    const decoder = try platform.createDeflateDecoder(testing.allocator);
    defer platform.destroyDeflateDecoder(decoder);
    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(testing.allocator);
    var input: []const u8 = small_deflate;
    var need_output: usize = 0;
    for (0..text.len * 4) |_| {
        var byte: [1]u8 = undefined;
        const progress = try platform.decompressDeflate(decoder, .from(input), &byte);
        input = input[progress.consumed..];
        try out.appendSlice(testing.allocator, byte[0..progress.produced]);
        if (progress.status == .need_output) need_output += 1;
        if (progress.status == .finished) break;
    } else return error.TestUnexpectedResult;
    try testing.expect(need_output > 0);
    try testing.expectEqualStrings(text, out.items);
    // After the end: finished again, nothing taken.
    var byte: [1]u8 = undefined;
    const again = try platform.decompressDeflate(decoder, .from("more"), &byte);
    try testing.expectEqual(platform.CodecStatus.finished, again.status);
    try testing.expectEqual(@as(usize, 0), again.produced);
}

test "deflate_decoding: a truncated stream asks for more input and keeps what decoded" {
    if (!supported) return;
    const text = try small(testing.allocator);
    defer testing.allocator.free(text);
    for ([_]usize{ 1, 2, 17, small_deflate.len / 2, small_deflate.len - 1 }) |len| {
        const result = try decodePieces(testing.allocator, &.{small_deflate[0..len]}, 256);
        defer testing.allocator.free(result.bytes);
        try testing.expectEqual(platform.CodecStatus.need_input, result.status);
        // Without its last byte the stream may still have made all its
        // output (only the end-of-block code is missing): never more.
        try testing.expect(result.bytes.len <= text.len);
        if (len < small_deflate.len / 2) try testing.expect(result.bytes.len < text.len);
        try testing.expect(std.mem.startsWith(u8, text, result.bytes));
    }
}

test "deflate_decoding: bytes after the stream's end are left to the caller" {
    if (!supported) return;
    const text = try small(testing.allocator);
    defer testing.allocator.free(text);
    const trailing = "trailing garbage after the final block";
    const result = try decodePieces(testing.allocator, &.{small_deflate ++ trailing}, 1024);
    defer testing.allocator.free(result.bytes);
    try testing.expectEqual(platform.CodecStatus.finished, result.status);
    try testing.expectEqual(trailing.len, result.left);
    try testing.expectEqualStrings(text, result.bytes);
}

test "deflate_decoding: what is not DEFLATE fails with InvalidData" {
    if (!supported) return;
    // BFINAL 1, BTYPE 11: the reserved block type (RFC 1951 3.2.3).
    try testing.expectError(error.InvalidData, decodePieces(testing.allocator, &.{"\x07\x00"}, 64));
    // A stored block whose LEN and NLEN disagree.
    try testing.expectError(error.InvalidData, decodePieces(testing.allocator, &.{"\x01\x05\x00\x00\x00hello"}, 64));
    // A distance past the start of the output: fixed Huffman, length 3 at
    // distance 1 before any literal.
    try testing.expectError(error.InvalidData, decodePieces(testing.allocator, &.{"\x03\x02\x00"}, 64));
}

test "deflate_decoding: a 1 MB body from another encoder decodes in network-sized pieces" {
    if (!supported) return;
    const allocator = testing.allocator;
    // 1 MiB of text that compresses about as a page does.
    const text = try allocator.alloc(u8, 1 << 20);
    defer allocator.free(text);
    var state: u64 = 1;
    for (text, 0..) |*c, i| {
        state = (state *% 6364136223846793005 +% 1442695040888963407);
        c.* = if (i % 80 == 79) '\n' else "abcdefghij klmnop qrstuv wxyz <div class=\"x\">"[@intCast((state >> 33) % 46)];
    }
    var encoded: std.Io.Writer.Allocating = try .initCapacity(allocator, 1 << 20);
    defer encoded.deinit();
    {
        const window = try allocator.alloc(u8, std.compress.flate.max_window_len);
        defer allocator.free(window);
        var compress: std.compress.flate.Compress = try .init(&encoded.writer, window, .raw, .default);
        try compress.writer.writeAll(text);
        try compress.finish();
    }
    const bytes = encoded.written();
    var pieces: std.ArrayListUnmanaged([]const u8) = .empty;
    defer pieces.deinit(allocator);
    var at: usize = 0;
    while (at < bytes.len) : (at += 16 * 1024) try pieces.append(allocator, bytes[at..@min(at + 16 * 1024, bytes.len)]);
    const result = try decodePieces(allocator, pieces.items, 32 * 1024);
    defer allocator.free(result.bytes);
    try testing.expectEqual(platform.CodecStatus.finished, result.status);
    try testing.expectEqual(text.len, result.bytes.len);
    try testing.expect(std.mem.eql(u8, text, result.bytes));
}

fn decodeWithAllocator(allocator: std.mem.Allocator) !void {
    const result = try decodePieces(allocator, &.{ small_deflate[0..40], small_deflate[40..] }, 512);
    allocator.free(result.bytes);
}

test "deflate_decoding cleans up on every allocation failure, zlib's own included" {
    if (!supported) return;
    try testing.checkAllAllocationFailures(testing.allocator, decodeWithAllocator, .{});
}
