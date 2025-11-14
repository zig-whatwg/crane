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






