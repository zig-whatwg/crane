const std = @import("std");
const codec = @import("compression");

/// `s` repeated `n` times: what `s ** n` was (Zig 0.17 removes `**`; roadmap zig-017).
fn repeat(comptime s: []const u8, comptime n: usize) *const [s.len * n:0]u8 {
    return comptime blk: {
        @setEvalBranchQuota(10 * n + 1000);
        var out: [s.len * n:0]u8 = undefined;
        for (0..n) |i| @memcpy(out[i * s.len ..][0..s.len], s);
        const final = out;
        break :blk &final;
    };
}
const testing = std.testing;

const Vector = struct { format: codec.Format, bytes: []const u8 };
const vectors = [_]Vector{
    .{ .format = .deflate, .bytes = &.{ 120, 156, 203, 72, 205, 201, 201, 7, 0, 6, 44, 2, 21 } },
    .{ .format = .deflate_raw, .bytes = &.{ 203, 72, 205, 201, 201, 7, 0 } },
    .{ .format = .gzip, .bytes = &.{ 31, 139, 8, 0, 0, 0, 0, 0, 0, 3, 203, 72, 205, 201, 201, 7, 0, 134, 166, 16, 54, 5, 0, 0, 0 } },
};

test "compression: trailing data preserves complete output before the error" {
    for (vectors) |vector| {
        const input = try std.mem.concat(testing.allocator, u8, &.{ vector.bytes, &.{0} });
        defer testing.allocator.free(input);
        const decoder = try codec.Decoder.create(testing.allocator, vector.format);
        defer decoder.destroy();
        try testing.expectError(error.InvalidData, decoder.push(input, false));
        const prefix = decoder.takeValidPrefix();
        defer testing.allocator.free(prefix);
        try testing.expectEqualStrings("hello", prefix);
    }
}

test "compression: decode externally produced vectors at every split" {
    for (vectors) |vector| {
        for (0..vector.bytes.len + 1) |split| {
            const decoder = try codec.Decoder.create(testing.allocator, vector.format);
            defer decoder.destroy();
            const a = try decoder.push(vector.bytes[0..split], false);
            defer testing.allocator.free(a);
            const b = try decoder.push(vector.bytes[split..], true);
            defer testing.allocator.free(b);
            const result = try std.mem.concat(testing.allocator, u8, &.{ a, b });
            defer testing.allocator.free(result);
            try testing.expectEqualStrings("hello", result);
        }
    }
}

test "compression: complete input emits before finalization; empty chunks are accepted" {
    for (vectors) |vector| {
        const decoder = try codec.Decoder.create(testing.allocator, vector.format);
        defer decoder.destroy();
        const a = try decoder.push(vector.bytes, false);
        defer testing.allocator.free(a);
        try testing.expectEqualStrings("hello", a);
        const b = try decoder.push("", false);
        defer testing.allocator.free(b);
        try testing.expectEqual(@as(usize, 0), b.len);
        const c = try decoder.push("", true);
        defer testing.allocator.free(c);
        try testing.expectEqual(@as(usize, 0), c.len);
    }
}

test "compression: every truncated prefix and trailing byte is rejected" {
    for (vectors) |vector| {
        for (0..vector.bytes.len) |end| {
            const decoder = try codec.Decoder.create(testing.allocator, vector.format);
            defer decoder.destroy();
            try testing.expectError(error.InvalidData, decoder.push(vector.bytes[0..end], true));
        }
        const decoder = try codec.Decoder.create(testing.allocator, vector.format);
        defer decoder.destroy();
        const data = try decoder.push(vector.bytes, false);
        defer testing.allocator.free(data);
        try testing.expectError(error.InvalidData, decoder.push(&.{0}, false));
    }
}

test "compression: container checksum, size, dictionary and reserved flags" {
    for (vectors) |vector| {
        if (vector.format == .deflate_raw) continue;
        const bad = try testing.allocator.dupe(u8, vector.bytes);
        defer testing.allocator.free(bad);
        bad[bad.len - 1] ^= 1;
        const decoder = try codec.Decoder.create(testing.allocator, vector.format);
        defer decoder.destroy();
        try testing.expectError(error.InvalidData, decoder.push(bad, true));
    }
    for ([_][]const u8{ &.{ 0x78, 0x20 }, &.{ 0x78, 0x9d }, &.{ 0x1f, 0x8b, 8, 0x20, 0, 0, 0, 0, 0, 3 } }, 0..) |bytes, i| {
        const decoder = try codec.Decoder.create(testing.allocator, if (i < 2) .deflate else .gzip);
        defer decoder.destroy();
        try testing.expectError(error.InvalidData, decoder.push(bytes, true));
    }
}

test "compression: gzip optional header CRC is checked" {
    var bytes: [vectors[2].bytes.len + 2]u8 = undefined;
    @memcpy(bytes[0..10], vectors[2].bytes[0..10]);
    bytes[3] = 2;
    std.mem.writeInt(u16, bytes[10..12], @truncate(std.hash.Crc32.hash(bytes[0..10])), .little);
    @memcpy(bytes[12..], vectors[2].bytes[10..]);
    const good = try codec.Decoder.create(testing.allocator, .gzip);
    defer good.destroy();
    const result = try good.push(&bytes, true);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("hello", result);
    bytes[10] ^= 1;
    const bad = try codec.Decoder.create(testing.allocator, .gzip);
    defer bad.destroy();
    try testing.expectError(error.InvalidData, bad.push(&bytes, true));
}

test "compression: stateful compressed output round trips and reduces repetition" {
    const input = repeat("abcdefg", 10000);
    for ([_]codec.Format{ .deflate, .deflate_raw, .gzip }) |format| {
        const encoder = try codec.Encoder.create(testing.allocator, format);
        defer encoder.destroy();
        const a = try encoder.push(input[0..33333], false);
        defer testing.allocator.free(a);
        const b = try encoder.push(input[33333..], true);
        defer testing.allocator.free(b);
        const encoded = try std.mem.concat(testing.allocator, u8, &.{ a, b });
        defer testing.allocator.free(encoded);
        try testing.expect(encoded.len < input.len / 10);
        const decoder = try codec.Decoder.create(testing.allocator, format);
        defer decoder.destroy();
        var result: std.Io.Writer.Allocating = .init(testing.allocator);
        defer result.deinit();
        for (encoded, 0..) |byte, i| {
            const part = try decoder.push(&.{byte}, i == encoded.len - 1);
            defer testing.allocator.free(part);
            try result.writer.writeAll(part);
        }
        try testing.expectEqualStrings(input, result.written());
    }
}

test "compression: empty streams have valid framing" {
    for ([_]codec.Format{ .deflate, .deflate_raw, .gzip }) |format| {
        const encoder = try codec.Encoder.create(testing.allocator, format);
        defer encoder.destroy();
        const encoded = try encoder.push("", true);
        defer testing.allocator.free(encoded);
        try testing.expect(encoded.len > 0);
        const decoder = try codec.Decoder.create(testing.allocator, format);
        defer decoder.destroy();
        const result = try decoder.push(encoded, true);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("", result);
    }
}

test "compression: a truncated dynamic Huffman block never consumes lookahead" {
    const input = repeat("abcdefg", 10000);
    const encoder = try codec.Encoder.create(testing.allocator, .deflate_raw);
    defer encoder.destroy();
    const encoded = try encoder.push(input, true);
    defer testing.allocator.free(encoded);
    // The stdlib short-bit reader used to assert during dynamic-table setup.
    // Every truncated prefix must be an ordinary stream error, even when the
    // missing bits are zero and the lookahead would form a plausible symbol.
    for (0..encoded.len) |end| {
        const decoder = try codec.Decoder.create(testing.allocator, .deflate_raw);
        defer decoder.destroy();
        const partial = try decoder.push(encoded[0..end], false);
        defer testing.allocator.free(partial);
        try testing.expect(partial.len <= input.len);
        try testing.expectEqualSlices(u8, input[0..partial.len], partial);
        try testing.expectError(error.InvalidData, decoder.push("", true));
    }
}

test "compression: optional gzip header fields stay bounded at byte boundaries" {
    var header: std.Io.Writer.Allocating = .init(testing.allocator);
    defer header.deinit();
    try header.writer.writeAll(&.{ 31, 139, 8, 0x1e, 0, 0, 0, 0, 0, 3 });
    try header.writer.writeAll(&.{ 3, 0, 'a', 'b', 'c' });
    try header.writer.writeAll("filename\x00comment\x00");
    var crc: [2]u8 = undefined;
    std.mem.writeInt(u16, &crc, @truncate(std.hash.Crc32.hash(header.written())), .little);
    try header.writer.writeAll(&crc);
    try header.writer.writeAll(vectors[2].bytes[10..]);
    const decoder = try codec.Decoder.create(testing.allocator, .gzip);
    defer decoder.destroy();
    var result: std.Io.Writer.Allocating = .init(testing.allocator);
    defer result.deinit();
    for (header.written(), 0..) |byte, i| {
        const out = try decoder.push(&.{byte}, i == header.written().len - 1);
        defer testing.allocator.free(out);
        try result.writer.writeAll(out);
        try testing.expect(decoder.pending.items.len < 16);
    }
    try testing.expectEqualStrings("hello", result.written());

    const long = try codec.Decoder.create(testing.allocator, .gzip);
    defer long.destroy();
    try expectEmpty(long, &.{ 31, 139, 8, 8, 0, 0, 0, 0, 0, 3 });
    for (0..10000) |_| {
        try expectEmpty(long, "x");
        try testing.expectEqual(@as(usize, 0), long.pending.items.len);
    }
    try expectEmpty(long, &.{0});
    const data = try long.push(vectors[2].bytes[10..], true);
    defer testing.allocator.free(data);
    try testing.expectEqualStrings("hello", data);
}

fn expectEmpty(decoder: *codec.Decoder, bytes: []const u8) !void {
    const out = try decoder.push(bytes, false);
    defer testing.allocator.free(out);
    try testing.expectEqual(@as(usize, 0), out.len);
}

test "compression: stored blocks, invalid block types, and concatenated members" {
    const stored = [_]u8{ 1, 5, 0, 250, 255, 'h', 'e', 'l', 'l', 'o' };
    for (0..stored.len + 1) |split| {
        const decoder = try codec.Decoder.create(testing.allocator, .deflate_raw);
        defer decoder.destroy();
        const first = try decoder.push(stored[0..split], false);
        defer testing.allocator.free(first);
        const last = try decoder.push(stored[split..], true);
        defer testing.allocator.free(last);
        const all = try std.mem.concat(testing.allocator, u8, &.{ first, last });
        defer testing.allocator.free(all);
        try testing.expectEqualStrings("hello", all);
    }
    const invalid = try codec.Decoder.create(testing.allocator, .deflate_raw);
    defer invalid.destroy();
    try testing.expectError(error.InvalidData, invalid.push(&.{7}, true));
    const members = try std.mem.concat(testing.allocator, u8, &.{ vectors[2].bytes, vectors[2].bytes });
    defer testing.allocator.free(members);
    const multiple = try codec.Decoder.create(testing.allocator, .gzip);
    defer multiple.destroy();
    try testing.expectError(error.InvalidData, multiple.push(members, true));
}

// External raw-DEFLATE vector: a fixed block of 100 As followed by a
// stored block of 300 bytes (zlib Z_FIXED, Z_BLOCK, then Z_FINISH).
test "compression: compressed-to-stored block transition respects the output bound" {
    var encoded: [310]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, "7274a43d00042c01d3fec1bca085abe9066a604983ce8629ad4d57fce2f51780995d9ae3244a3f5fb82cfd9d1fc4b53884b4cec047b4ef96498a6d6650a92b213d476494331cc1d2e0ea2654e506271db83f920959620d09b0d071c113bf8eb4686bf2389c406a9e15dc470869805c6168cd1f6d43510e6ff9a365f0a8d8871d37af793af8f107ec69b9faa9ce66e2e9352314399affff6b1a8df8ddeb0f3f49cf23a12407d0bfe9a7ca00be14e0531552328f65a226ab83ffe11725a0b40d5169889989138fc35e42cd153187f4919a92af4437c335d8c7be54dd093b8addb89d1faaa4e8e18fd830b7a0a386a3cdaeb5115cb3274f0c6be0689107f514daa9dd81af2995f0d2f6d5db6b845e799c88e2a3813b0fffaad89599965d40249399bfae2c9eeccfd6dc9e68728c39d0d3ce8d81a87b83eb");
    var expected: [400]u8 = undefined;
    @memset(expected[0..100], 'A');
    @memcpy(expected[100..], encoded[10..]);
    const decoder = try codec.Decoder.create(testing.allocator, .deflate_raw);
    defer decoder.destroy();
    const actual = try decoder.push(&encoded, true);
    defer testing.allocator.free(actual);
    try testing.expectEqualSlices(u8, &expected, actual);
}
