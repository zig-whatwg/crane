//! Single-Byte Decoder (I/O Queue-based)
//!
//! WHATWG Encoding Standard § 9.1
//! https://encoding.spec.whatwg.org/#single-byte-decoder
//!
//! Generic decoder for all 28 single-byte encodings.
//!
//! Algorithm (from spec):
//! 1. If byte is end-of-queue, return finished.
//! 2. If byte is an ASCII byte, return a code point whose value is byte.
//! 3. Let code point be the index code point for byte − 0x80 in index single-byte.
//! 4. If code point is null, return error.
//! 5. Return a code point whose value is code point.

const std = @import("std");
const io_queue = @import("../io_queue.zig");
const ByteQueue = io_queue.ByteQueue;
const ScalarQueue = io_queue.ScalarQueue;
const streaming = @import("../streaming.zig");
const error_mode = @import("../error_mode.zig");
const ErrorMode = error_mode.ErrorMode;
const index_gen = @import("index_generator.zig");

pub const SingleByteIndex = index_gen.Index;

/// Single-byte decode using I/O queues
///
/// Spec: https://encoding.spec.whatwg.org/#single-byte-decoder
pub fn decode(
    index: *const SingleByteIndex,
    input: *ByteQueue,
    output: *ScalarQueue,
    mode: ErrorMode,
) !streaming.DecodeQueueResult {
    while (true) {
        // Step 1: Read next byte from input queue
        const item = input.read();

        if (item == null or (item != null and item.?.isEndOfQueue())) {
            // Step 1: end-of-queue, return finished
            return .{ .status = .finished };
        }

        const byte = item.?.value;

        // Step 2: ASCII byte (0x00-0x7F)
        if (byte < 0x80) {
            try output.push(byte);
            continue;
        }

        // Step 3: Look up in index (byte - 0x80)
        const pointer = byte - 0x80;
        const code_point = index_gen.getCodePoint(index, pointer);

        if (code_point) |cp| {
            // Step 5: Valid code point found
            try output.push(cp);
            continue;
        }

        // Step 4: Not in index - error
        switch (mode) {
            .replacement => {
                // Emit U+FFFD (replacement character)
                try output.push(0xFFFD);
            },
            .fatal => {
                return .{ .status = .error_ };
            },
            .html => {
                // Decoders don't use html mode
                try output.push(0xFFFD);
            },
        }
    }
}

// Tests

test "single-byte decoder queue - ASCII" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("0\t0x0410\n");

    var input = try ByteQueue.fromSlice(allocator, "ABC");
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    const result = try decode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 3), out_slice.len);
    try std.testing.expectEqual(@as(u21, 'A'), out_slice[0]);
    try std.testing.expectEqual(@as(u21, 'B'), out_slice[1]);
    try std.testing.expectEqual(@as(u21, 'C'), out_slice[2]);
}

test "single-byte decoder queue - index lookup" {
    const allocator = std.testing.allocator;

    // Index: pointer 0 → U+0410 (Cyrillic А)
    const test_index = index_gen.parseIndex("0\t0x0410\n1\t0x0411\n");

    const input_bytes = [_]u8{ 0x80, 0x81 }; // pointer 0, pointer 1
    var input = try ByteQueue.fromSlice(allocator, &input_bytes);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    const result = try decode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 2), out_slice.len);
    try std.testing.expectEqual(@as(u21, 0x0410), out_slice[0]);
    try std.testing.expectEqual(@as(u21, 0x0411), out_slice[1]);
}

test "single-byte decoder queue - unmapped byte (replacement mode)" {
    const allocator = std.testing.allocator;

    // Empty index - all non-ASCII bytes unmapped
    const test_index = index_gen.parseIndex("");

    const input_bytes = [_]u8{0x80}; // Unmapped
    var input = try ByteQueue.fromSlice(allocator, &input_bytes);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    const result = try decode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 1), out_slice.len);
    try std.testing.expectEqual(@as(u21, 0xFFFD), out_slice[0]); // Replacement character
}

test "single-byte decoder queue - unmapped byte (fatal mode)" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("");

    const input_bytes = [_]u8{0x80}; // Unmapped
    var input = try ByteQueue.fromSlice(allocator, &input_bytes);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    const result = try decode(&test_index, &input, &output, .fatal);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.error_, result.status);
}

test "single-byte decoder queue - mixed ASCII and non-ASCII" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("0\t0x0410\n");

    const input_bytes = [_]u8{ 'A', 0x80, 'B' }; // A, Cyrillic А, B
    var input = try ByteQueue.fromSlice(allocator, &input_bytes);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    const result = try decode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 3), out_slice.len);
    try std.testing.expectEqual(@as(u21, 'A'), out_slice[0]);
    try std.testing.expectEqual(@as(u21, 0x0410), out_slice[1]);
    try std.testing.expectEqual(@as(u21, 'B'), out_slice[2]);
}
