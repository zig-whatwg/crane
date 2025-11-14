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





