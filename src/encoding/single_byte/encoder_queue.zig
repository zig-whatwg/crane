//! Single-Byte Encoder (I/O Queue-based)
//!
//! WHATWG Encoding Standard § 9.2
//! https://encoding.spec.whatwg.org/#single-byte-encoder
//!
//! Generic encoder for all 28 single-byte encodings with HTML error mode support.
//!
//! Algorithm (from spec):
//! 1. If code point is end-of-queue, return finished.
//! 2. If code point is an ASCII code point, return a byte whose value is code point.
//! 3. Let pointer be the index pointer for code point in index single-byte.
//! 4. If pointer is null, return error with code point.
//! 5. Return a byte whose value is pointer + 0x80.

const std = @import("std");
const io_queue = @import("../io_queue.zig");
const ByteQueue = io_queue.ByteQueue;
const ScalarQueue = io_queue.ScalarQueue;
const streaming = @import("../streaming.zig");
const error_mode = @import("../error_mode.zig");
const ErrorMode = error_mode.ErrorMode;
const html_encoding = @import("../html_encoding.zig");
const index_gen = @import("index_generator.zig");

pub const SingleByteIndex = index_gen.Index;

/// Single-byte encode using I/O queues
///
/// Spec: https://encoding.spec.whatwg.org/#single-byte-encoder
pub fn encode(
    index: *const SingleByteIndex,
    input: *ScalarQueue,
    output: *ByteQueue,
    mode: ErrorMode,
) !streaming.EncodeQueueResult {
    while (true) {
        // Step 1: Read next code point from input queue
        const item = input.read();

        if (item == null or (item != null and item.?.isEndOfQueue())) {
            // Step 1: end-of-queue, return finished
            return .{ .status = .finished };
        }

        const code_point = item.?.value;

        // Step 2: ASCII code point (U+0000 to U+007F)
        if (code_point <= 0x7F) {
            try output.push(@intCast(code_point));
            continue;
        }

        // Step 3: Look up in index
        const pointer = index_gen.getPointer(index, @intCast(code_point));

        if (pointer) |ptr| {
            // Step 5: Valid pointer found - return ptr + 0x80
            try output.push(ptr + 0x80);
            continue;
        }

        // Step 4: Not in index - error
        switch (mode) {
            .replacement => {
                // Emit '?' (0x3F) as replacement
                try output.push(0x3F);
            },
            .fatal => {
                return .{ .status = .error_, .error_code_point = code_point };
            },
            .html => {
                // Encode as HTML entity: &#NNNN;
                try html_encoding.encodeAsHtmlEntity(code_point, output);
            },
        }
    }
}

// Tests

test "single-byte encoder queue - ASCII" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("0\t0x0410\n");

    var input = ScalarQueue.init(allocator);
    defer input.deinit();

    try input.push('A');
    try input.push('B');
    try input.push('C');
    try input.markEnd();

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    const result = try encode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.EncodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqualStrings("ABC", out_slice);
}

test "single-byte encoder queue - index lookup" {
    const allocator = std.testing.allocator;

    // Index: U+0410 → pointer 0, U+0411 → pointer 1
    const test_index = index_gen.parseIndex("0\t0x0410\n1\t0x0411\n");

    var input = ScalarQueue.init(allocator);
    defer input.deinit();

    try input.push(0x0410); // Cyrillic А
    try input.push(0x0411); // Cyrillic Б
    try input.markEnd();

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    const result = try encode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.EncodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    const expected = [_]u8{ 0x80, 0x81 }; // pointer 0 + 0x80, pointer 1 + 0x80
    try std.testing.expectEqualSlices(u8, &expected, out_slice);
}

test "single-byte encoder queue - unmapped code point (replacement mode)" {
    const allocator = std.testing.allocator;

    // Empty index - no non-ASCII mappings
    const test_index = index_gen.parseIndex("");

    var input = ScalarQueue.init(allocator);
    defer input.deinit();

    try input.push(0x0410); // Unmapped
    try input.markEnd();

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    const result = try encode(&test_index, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.EncodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    const expected = [_]u8{0x3F}; // '?'
    try std.testing.expectEqualSlices(u8, &expected, out_slice);
}

test "single-byte encoder queue - unmapped code point (fatal mode)" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("");

    var input = ScalarQueue.init(allocator);
    defer input.deinit();

    try input.push(0x0410); // Unmapped
    try input.markEnd();

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    const result = try encode(&test_index, &input, &output, .fatal);
    try std.testing.expectEqual(streaming.EncodeQueueResult.Status.error_, result.status);
    try std.testing.expectEqual(@as(u21, 0x0410), result.error_code_point);
}

test "single-byte encoder queue - unmapped code point (html mode)" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("");

    var input = ScalarQueue.init(allocator);
    defer input.deinit();

    try input.push(0x0410); // Cyrillic А - unmapped in empty index
    try input.markEnd();

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    const result = try encode(&test_index, &input, &output, .html);
    try std.testing.expectEqual(streaming.EncodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    // Should be &#1040; (U+0410 = 1040 decimal)
    const expected = "&#1040;";
    try std.testing.expectEqualStrings(expected, out_slice);
}

test "single-byte encoder queue - mixed ASCII and non-ASCII (html mode)" {
    const allocator = std.testing.allocator;

    const test_index = index_gen.parseIndex("0\t0x0410\n"); // Maps U+0410 to 0x80

    var input = ScalarQueue.init(allocator);
    defer input.deinit();

    try input.push('A');
    try input.push(0x0410); // Mapped
    try input.push(0x06DE); // Arabic letter - unmapped
    try input.push('B');
    try input.markEnd();

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    const result = try encode(&test_index, &input, &output, .html);
    try std.testing.expectEqual(streaming.EncodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    // Expected: 'A' + 0x80 + "&#1758;" + 'B'
    const expected = "A\x80&#1758;B";
    try std.testing.expectEqualStrings(expected, out_slice);
}
