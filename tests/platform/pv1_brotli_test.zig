//! Brotli's incremental protocol and allocator contract.
const std = @import("std");
const platform = @import("platform");
const testing = std.testing;
const foo = [_]u8{ 0x21, 0x08, 0x00, 0x04, 0x66, 0x6f, 0x6f, 0x03 };

test "Brotli capability follows the compile-time gate" {
    if (platform.capabilities.brotli == .unsupported) return;
    const decoder = try platform.createBrotliDecoder(testing.allocator);
    defer platform.destroyBrotliDecoder(decoder);
    var output: [32]u8 = undefined;
    const result = try platform.decompressBrotli(decoder, .from(&foo), &output);
    try testing.expectEqual(platform.CodecStatus.finished, result.status);
    try testing.expectEqual(foo.len, result.consumed);
    try testing.expectEqualStrings("foo", output[0..result.produced]);
}

test "Brotli consumes one byte at a time with bounded output" {
    if (platform.capabilities.brotli == .unsupported) return;
    const decoder = try platform.createBrotliDecoder(testing.allocator);
    defer platform.destroyBrotliDecoder(decoder);
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    var offset: usize = 0;
    for (0..100) |_| {
        var byte: [1]u8 = undefined;
        const end = @min(foo.len, offset + 1);
        const result = try platform.decompressBrotli(decoder, .from(foo[offset..end]), &byte);
        offset += result.consumed;
        try out.writer.writeAll(byte[0..result.produced]);
        if (result.status == .finished) break;
    } else return error.TestUnexpectedResult;
    try testing.expectEqualStrings("foo", out.written());
}

test "Brotli stream creation and decoding clean up on every allocation failure" {
    if (platform.capabilities.brotli == .unsupported) return;
    try testing.checkAllAllocationFailures(testing.allocator, decodeWithAllocator, .{});
}

test "Brotli encoding cleans up on every allocation failure" {
    if (platform.capabilities.brotli == .unsupported) return;
    try testing.checkAllAllocationFailures(testing.allocator, encodeWithAllocator, .{});
}

fn encodeWithAllocator(allocator: std.mem.Allocator) !void {
    const encoder = try platform.createBrotliEncoder(allocator);
    defer platform.destroyBrotliEncoder(encoder);
    var output: [128]u8 = undefined;
    const result = try platform.compressBrotli(encoder, .from("allocator failure test"), &output, true);
    try testing.expectEqual(platform.CodecStatus.finished, result.status);
}

fn decodeWithAllocator(allocator: std.mem.Allocator) !void {
    const decoder = try platform.createBrotliDecoder(allocator);
    defer platform.destroyBrotliDecoder(decoder);
    var output: [32]u8 = undefined;
    _ = try platform.decompressBrotli(decoder, .from(&foo), &output);
}

test "Brotli encoder round trips with repeated finish and tiny buffers" {
    if (platform.capabilities.brotli == .unsupported) return;
    const encoder = try platform.createBrotliEncoder(testing.allocator);
    defer platform.destroyBrotliEncoder(encoder);
    var encoded: std.Io.Writer.Allocating = .init(testing.allocator);
    defer encoded.deinit();
    var input: []const u8 = "Brotli in Crane";
    for (0..100) |_| {
        var buffer: [1]u8 = undefined;
        const result = try platform.compressBrotli(encoder, .from(input), &buffer, true);
        input = input[result.consumed..];
        try encoded.writer.writeAll(buffer[0..result.produced]);
        if (result.status == .finished) break;
    } else return error.TestUnexpectedResult;
    const decoder = try platform.createBrotliDecoder(testing.allocator);
    defer platform.destroyBrotliDecoder(decoder);
    var buffer: [64]u8 = undefined;
    const decoded = try platform.decompressBrotli(decoder, .from(encoded.written()), &buffer);
    try testing.expectEqual(platform.CodecStatus.finished, decoded.status);
    try testing.expectEqualStrings("Brotli in Crane", buffer[0..decoded.produced]);
}

test "Brotli leaves trailing input and rejects invalid data and large windows" {
    if (platform.capabilities.brotli == .unsupported) return;
    var output: [32]u8 = undefined;
    const decoder = try platform.createBrotliDecoder(testing.allocator);
    defer platform.destroyBrotliDecoder(decoder);
    const trailing = foo ++ "trailing".*;
    const result = try platform.decompressBrotli(decoder, .from(&trailing), &output);
    try testing.expectEqual(foo.len, result.consumed);
    try testing.expectEqual(platform.CodecStatus.finished, result.status);
    const large_window = [_]u8{ 17, 25, 20, 0, 2, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 3 };
    for ([_][]const u8{ &.{255}, &large_window }) |invalid| {
        const fresh = try platform.createBrotliDecoder(testing.allocator);
        defer platform.destroyBrotliDecoder(fresh);
        try testing.expectError(error.InvalidData, platform.decompressBrotli(fresh, .from(invalid), &output));
    }
}
