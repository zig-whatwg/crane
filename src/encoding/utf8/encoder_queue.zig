//! UTF-8 Encoder (I/O Queue-based)
//!
//! WHATWG Encoding Standard § 4.4 UTF-8 encoder
//! https://encoding.spec.whatwg.org/#utf-8-encoder
//!
//! This is the spec-compliant implementation using I/O queues,
//! with support for HTML error mode.
//!
//! Algorithm (from spec):
//! 1. If code point is end-of-queue, return finished.
//! 2. If code point is an ASCII code point, return a byte whose value is code point.
//! 3. Set count and offset based on the code point's range.
//! 4. Let bytes be a byte sequence whose count items have value 0x00.
//! 5. Set bytes[0] to the formula result for the first byte.
//! 6. For each additional byte, apply the continuation byte formula.
//! 7. Return bytes.

const std = @import("std");
const io_queue = @import("../io_queue.zig");
const ByteQueue = io_queue.ByteQueue;
const ScalarQueue = io_queue.ScalarQueue;
const streaming = @import("../streaming.zig");
const error_mode = @import("../error_mode.zig");
const ErrorMode = error_mode.ErrorMode;
const html_encoding = @import("../html_encoding.zig");

/// UTF-8 encoder state (handles surrogate pairs)
pub const Utf8EncoderState = struct {
    /// Pending high surrogate (if expecting low surrogate)
    pending_high_surrogate: ?u16 = null,
};

/// UTF-8 encode using I/O queues
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-encoder
pub fn encode(
    state: *Utf8EncoderState,
    input: *ScalarQueue,
    output: *ByteQueue,
    mode: ErrorMode,
) !streaming.EncodeQueueResult {
    _ = state; // UTF-8 encoder is stateless (no pending surrogates in scalar queue)

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

        // Step 3-7: Multi-byte sequence

        // 2-byte sequence (U+0080 to U+07FF)
        if (code_point <= 0x07FF) {
            try output.push(@intCast(0xC0 | (code_point >> 6)));
            try output.push(@intCast(0x80 | (code_point & 0x3F)));
            continue;
        }

        // 3-byte sequence (U+0800 to U+FFFF)
        if (code_point <= 0xFFFF) {
            try output.push(@intCast(0xE0 | (code_point >> 12)));
            try output.push(@intCast(0x80 | ((code_point >> 6) & 0x3F)));
            try output.push(@intCast(0x80 | (code_point & 0x3F)));
            continue;
        }

        // 4-byte sequence (U+10000 to U+10FFFF)
        if (code_point <= 0x10FFFF) {
            try output.push(@intCast(0xF0 | (code_point >> 18)));
            try output.push(@intCast(0x80 | ((code_point >> 12) & 0x3F)));
            try output.push(@intCast(0x80 | ((code_point >> 6) & 0x3F)));
            try output.push(@intCast(0x80 | (code_point & 0x3F)));
            continue;
        }

        // Invalid code point (> U+10FFFF) - error
        switch (mode) {
            .replacement => {
                // Emit U+FFFD in UTF-8: 0xEF 0xBF 0xBD
                try output.push(0xEF);
                try output.push(0xBF);
                try output.push(0xBD);
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





