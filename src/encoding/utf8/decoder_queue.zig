//! UTF-8 Decoder (I/O Queue-based)
//!
//! WHATWG Encoding Standard § 4.3 UTF-8 decoder
//! https://encoding.spec.whatwg.org/#utf-8-decoder
//!
//! This is the spec-compliant implementation using I/O queues.
//!
//! Algorithm (from spec):
//! 1. If byte is end-of-queue and utf-8 bytes needed ≠ 0, set utf-8 bytes needed
//!    to 0 and return error.
//! 2. If byte is end-of-queue and utf-8 bytes needed = 0, return finished.
//! 3. If utf-8 bytes needed = 0:
//!    a. If byte is an ASCII byte, return a code point whose value is byte.
//!    b. Otherwise: set up multi-byte sequence state
//! 4. If byte is a continuation byte (0x80-0xBF):
//!    a. Validate and accumulate code point
//!    b. If sequence complete, return code point
//! 5. Otherwise, return error and restore byte.

const std = @import("std");
const io_queue = @import("../io_queue.zig");
const ByteQueue = io_queue.ByteQueue;
const ScalarQueue = io_queue.ScalarQueue;
const streaming = @import("../streaming.zig");
const error_mode = @import("../error_mode.zig");
const ErrorMode = error_mode.ErrorMode;

/// UTF-8 decoder state
pub const Utf8DecoderState = struct {
    /// Code point being accumulated
    utf8_code_point: u21 = 0,

    /// Number of continuation bytes seen so far
    utf8_bytes_seen: u8 = 0,

    /// Number of continuation bytes needed for current sequence
    utf8_bytes_needed: u8 = 0,

    /// Lower boundary for valid continuation bytes (security)
    utf8_lower_boundary: u8 = 0x80,

    /// Upper boundary for valid continuation bytes (security)
    utf8_upper_boundary: u8 = 0xBF,
};

/// UTF-8 decode using I/O queues
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-decoder
pub fn decode(
    state: *Utf8DecoderState,
    input: *ByteQueue,
    output: *ScalarQueue,
    mode: ErrorMode,
) !streaming.DecodeQueueResult {
    while (true) {
        // Read next byte from input queue
        const item = input.read();

        // Step 1-2: Handle end-of-queue
        if (item == null or (item != null and item.?.isEndOfQueue())) {
            if (state.utf8_bytes_needed != 0) {
                // Step 1: Incomplete sequence
                state.utf8_bytes_needed = 0;
                state.utf8_bytes_seen = 0;
                state.utf8_lower_boundary = 0x80;
                state.utf8_upper_boundary = 0xBF;

                // Emit error
                switch (mode) {
                    .replacement => {
                        try output.push(0xFFFD); // U+FFFD REPLACEMENT CHARACTER
                        return .{ .status = .finished };
                    },
                    .fatal => {
                        return .{ .status = .error_ };
                    },
                    .html => {
                        // Decoders don't use html mode
                        try output.push(0xFFFD);
                        return .{ .status = .finished };
                    },
                }
            }

            // Step 2: Finished normally
            return .{ .status = .finished };
        }

        const byte = item.?.value;

        // Step 3: If utf-8 bytes needed = 0
        if (state.utf8_bytes_needed == 0) {
            // Step 3a: ASCII byte
            if (byte <= 0x7F) {
                try output.push(byte);
                continue;
            }

            // Step 3b: 2-byte sequence (0xC2-0xDF)
            if (byte >= 0xC2 and byte <= 0xDF) {
                state.utf8_bytes_needed = 1;
                state.utf8_code_point = byte & 0x1F;
                continue;
            }

            // Step 3c: 3-byte sequence (0xE0-0xEF)
            if (byte >= 0xE0 and byte <= 0xEF) {
                // Set boundaries to prevent overlong encodings and surrogates
                if (byte == 0xE0) {
                    state.utf8_lower_boundary = 0xA0;
                } else if (byte == 0xED) {
                    state.utf8_upper_boundary = 0x9F;
                } else {
                    state.utf8_lower_boundary = 0x80;
                    state.utf8_upper_boundary = 0xBF;
                }

                state.utf8_bytes_needed = 2;
                state.utf8_code_point = byte & 0x0F;
                continue;
            }

            // Step 3d: 4-byte sequence (0xF0-0xF4)
            if (byte >= 0xF0 and byte <= 0xF4) {
                // Set boundaries
                if (byte == 0xF0) {
                    state.utf8_lower_boundary = 0x90;
                } else if (byte == 0xF4) {
                    state.utf8_upper_boundary = 0x8F;
                } else {
                    state.utf8_lower_boundary = 0x80;
                    state.utf8_upper_boundary = 0xBF;
                }

                state.utf8_bytes_needed = 3;
                state.utf8_code_point = byte & 0x07;
                continue;
            }

            // Invalid lead byte - error
            switch (mode) {
                .replacement => try output.push(0xFFFD),
                .fatal => return .{ .status = .error_ },
                .html => try output.push(0xFFFD),
            }
            continue;
        }

        // Step 4: Processing continuation bytes

        // Validate continuation byte range
        if (byte < state.utf8_lower_boundary or byte > state.utf8_upper_boundary) {
            // Invalid continuation byte - error and restore

            // Reset state
            state.utf8_code_point = 0;
            state.utf8_bytes_seen = 0;
            state.utf8_bytes_needed = 0;
            state.utf8_lower_boundary = 0x80;
            state.utf8_upper_boundary = 0xBF;

            // Restore byte (prepend back to input queue)
            try input.restore(byte);

            // Emit error
            switch (mode) {
                .replacement => try output.push(0xFFFD),
                .fatal => return .{ .status = .error_ },
                .html => try output.push(0xFFFD),
            }
            continue;
        }

        // Reset boundaries after first continuation byte
        if (state.utf8_bytes_seen == 0) {
            state.utf8_lower_boundary = 0x80;
            state.utf8_upper_boundary = 0xBF;
        }

        // Accumulate code point
        state.utf8_code_point = (state.utf8_code_point << 6) | (byte & 0x3F);
        state.utf8_bytes_seen += 1;

        // Check if sequence complete
        if (state.utf8_bytes_seen == state.utf8_bytes_needed) {
            const code_point = state.utf8_code_point;

            // Reset state
            state.utf8_code_point = 0;
            state.utf8_bytes_seen = 0;
            state.utf8_bytes_needed = 0;

            // Emit code point
            try output.push(code_point);
        }
    }
}

// Tests

test "UTF-8 decoder queue - ASCII" {
    const allocator = std.testing.allocator;

    var input = try ByteQueue.fromSlice(allocator, "Hello");
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    var state = Utf8DecoderState{};

    const result = try decode(&state, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 5), out_slice.len);
    try std.testing.expectEqual(@as(u21, 'H'), out_slice[0]);
    try std.testing.expectEqual(@as(u21, 'e'), out_slice[1]);
}

test "UTF-8 decoder queue - multi-byte" {
    const allocator = std.testing.allocator;

    // "€" = U+20AC = 0xE2 0x82 0xAC
    const euro = [_]u8{ 0xE2, 0x82, 0xAC };
    var input = try ByteQueue.fromSlice(allocator, &euro);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    var state = Utf8DecoderState{};

    const result = try decode(&state, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 1), out_slice.len);
    try std.testing.expectEqual(@as(u21, 0x20AC), out_slice[0]);
}

test "UTF-8 decoder queue - invalid sequence" {
    const allocator = std.testing.allocator;

    // Invalid UTF-8: 0xFF
    const invalid = [_]u8{0xFF};
    var input = try ByteQueue.fromSlice(allocator, &invalid);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    var state = Utf8DecoderState{};

    const result = try decode(&state, &input, &output, .replacement);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.finished, result.status);

    const out_slice = try output.toSlice(allocator);
    defer allocator.free(out_slice);

    try std.testing.expectEqual(@as(usize, 1), out_slice.len);
    try std.testing.expectEqual(@as(u21, 0xFFFD), out_slice[0]); // Replacement character
}

test "UTF-8 decoder queue - fatal mode" {
    const allocator = std.testing.allocator;

    const invalid = [_]u8{0xFF};
    var input = try ByteQueue.fromSlice(allocator, &invalid);
    defer input.deinit();
    try input.markEnd();

    var output = ScalarQueue.init(allocator);
    defer output.deinit();

    var state = Utf8DecoderState{};

    const result = try decode(&state, &input, &output, .fatal);
    try std.testing.expectEqual(streaming.DecodeQueueResult.Status.error_, result.status);
}
