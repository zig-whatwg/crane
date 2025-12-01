//! UTF-8 Validation for WebSocket Text Frames
//!
//! Implements UTF-8 validation per RFC 6455 Section 8.1:
//!
//! > When an endpoint is to interpret a byte stream as UTF-8 but finds that
//! > the byte stream is not, in fact, a valid UTF-8 stream, that endpoint
//! > MUST Fail the WebSocket Connection.
//!
//! Invalid UTF-8 in text frames must cause the connection to fail with
//! close code 1007 (Invalid frame payload data).
//!
//! ## Streaming Validation
//!
//! For fragmented messages, validation must happen incrementally as chunks
//! arrive. The Utf8Validator handles partial multi-byte sequences that span
//! fragment boundaries.
//!
//! ## References
//!
//! - RFC 6455 Section 8.1: Handling Errors in UTF-8-Encoded Data
//! - RFC 3629: UTF-8, a transformation format of ISO 10646
//! - WHATWG Encoding: UTF-8 decoder

const std = @import("std");

/// Validate that a byte slice is valid UTF-8.
/// Per RFC 6455 Section 8.1.
///
/// Returns true if the data is valid UTF-8, false otherwise.
pub fn isValidUtf8(data: []const u8) bool {
    return std.unicode.utf8ValidateSlice(data);
}

/// Streaming UTF-8 validator for fragmented messages.
///
/// Handles multi-byte UTF-8 sequences that may span fragment boundaries.
/// Call validate() for each fragment, then finalize() when the message
/// is complete.
pub const Utf8Validator = struct {
    /// Pending bytes of incomplete sequence from previous chunk
    pending: [4]u8 = undefined,
    /// Number of pending bytes (0-3)
    pending_len: u3 = 0,
    /// Whether validation has failed
    failed: bool = false,

    const Self = @This();

    /// Validate a chunk of UTF-8 data.
    ///
    /// Returns true if the data is valid so far (may have incomplete
    /// sequence at the end). Returns false if invalid UTF-8 is detected.
    pub fn validate(self: *Self, data: []const u8) bool {
        if (self.failed) return false;
        if (data.len == 0) return true;

        var i: usize = 0;

        // First, try to complete any pending sequence
        if (self.pending_len > 0) {
            const first_byte = self.pending[0];
            const expected_len = utf8SequenceLength(first_byte);

            if (expected_len == 0) {
                // Invalid start byte
                self.failed = true;
                return false;
            }

            const needed: usize = expected_len - self.pending_len;
            if (data.len < needed) {
                // Still not enough bytes - append to pending
                const end_idx = self.pending_len + @as(u3, @intCast(data.len));
                @memcpy(self.pending[self.pending_len..end_idx], data);
                self.pending_len = end_idx;
                return true;
            }

            // Complete the sequence
            const end_idx = self.pending_len + @as(u3, @intCast(needed));
            @memcpy(self.pending[self.pending_len..end_idx], data[0..needed]);

            // Validate completed sequence
            if (!isValidUtf8Sequence(self.pending[0..expected_len])) {
                self.failed = true;
                return false;
            }

            self.pending_len = 0;
            i = needed;
        }

        // Validate complete sequences in the chunk
        while (i < data.len) {
            const first_byte = data[i];
            const seq_len = utf8SequenceLength(first_byte);

            if (seq_len == 0) {
                // Invalid start byte
                self.failed = true;
                return false;
            }

            if (i + seq_len > data.len) {
                // Incomplete sequence at end - save for next chunk
                const remaining = data.len - i;
                @memcpy(self.pending[0..remaining], data[i..]);
                self.pending_len = @intCast(remaining);
                return true;
            }

            // Validate the sequence
            if (!isValidUtf8Sequence(data[i..][0..seq_len])) {
                self.failed = true;
                return false;
            }

            i += seq_len;
        }

        return true;
    }

    /// Finalize validation - checks for incomplete sequences at end of stream.
    ///
    /// Call this after all fragments have been validated.
    /// Returns false if there's an incomplete UTF-8 sequence.
    pub fn finalize(self: *Self) bool {
        if (self.failed) return false;
        if (self.pending_len > 0) {
            // Incomplete sequence at end of stream
            self.failed = true;
            return false;
        }
        return true;
    }

    /// Reset the validator for reuse.
    pub fn reset(self: *Self) void {
        self.pending_len = 0;
        self.failed = false;
    }

    /// Check if the validator has failed.
    pub fn hasFailed(self: *const Self) bool {
        return self.failed;
    }
};

/// Get the expected length of a UTF-8 sequence from its first byte.
/// Returns 0 for invalid start bytes.
fn utf8SequenceLength(first_byte: u8) u3 {
    // ASCII: 0xxxxxxx
    if (first_byte < 0x80) return 1;
    // Invalid continuation byte as start: 10xxxxxx
    if (first_byte < 0xC0) return 0;
    // Two-byte: 110xxxxx
    if (first_byte < 0xE0) return 2;
    // Three-byte: 1110xxxx
    if (first_byte < 0xF0) return 3;
    // Four-byte: 11110xxx
    if (first_byte < 0xF8) return 4;
    // Invalid: 11111xxx
    return 0;
}

/// Validate a complete UTF-8 sequence.
fn isValidUtf8Sequence(seq: []const u8) bool {
    if (seq.len == 0) return false;

    // Use Zig's standard library for validation
    var view = std.unicode.Utf8View.init(seq) catch return false;
    var it = view.iterator();

    // Try to decode one codepoint
    _ = it.nextCodepoint() orelse return false;

    // Ensure we consumed all bytes (no extra bytes)
    return it.i == seq.len;
}

/// Get the UTF-8 byte length of a string.
/// Per WHATWG spec: "increase bufferedAmount by the number of bytes
/// needed to express the argument as UTF-8"
///
/// Since we already have UTF-8 encoded data, this is just the byte length.
pub fn utf8ByteLength(text: []const u8) usize {
    return text.len;
}

/// Count the number of Unicode code points in a UTF-8 string.
/// Returns null if the string contains invalid UTF-8.
pub fn countCodePoints(data: []const u8) ?usize {
    var view = std.unicode.Utf8View.init(data) catch return null;
    var it = view.iterator();
    var count: usize = 0;
    while (it.nextCodepoint()) |_| {
        count += 1;
    }
    return count;
}

// =============================================================================
// Tests
// =============================================================================

test "isValidUtf8 - valid ASCII" {
    try std.testing.expect(isValidUtf8("Hello, World!"));
    try std.testing.expect(isValidUtf8(""));
    try std.testing.expect(isValidUtf8("123456789"));
    try std.testing.expect(isValidUtf8("!@#$%^&*()"));
}

test "isValidUtf8 - valid multi-byte" {
    // Japanese
    try std.testing.expect(isValidUtf8("こんにちは"));
    // Chinese
    try std.testing.expect(isValidUtf8("你好世界"));
    // Emoji
    try std.testing.expect(isValidUtf8("🎉🚀💯"));
    // Mixed
    try std.testing.expect(isValidUtf8("Hello こんにちは 🎉"));
}

test "isValidUtf8 - valid edge cases" {
    // Single two-byte character (©)
    try std.testing.expect(isValidUtf8("\xC2\xA9"));
    // Single three-byte character (€)
    try std.testing.expect(isValidUtf8("\xE2\x82\xAC"));
    // Single four-byte character (𐍈)
    try std.testing.expect(isValidUtf8("\xF0\x90\x8D\x88"));
}

test "isValidUtf8 - invalid sequences" {
    // Invalid continuation byte as start
    try std.testing.expect(!isValidUtf8(&[_]u8{0x80}));
    try std.testing.expect(!isValidUtf8(&[_]u8{0xBF}));

    // Truncated two-byte sequence
    try std.testing.expect(!isValidUtf8(&[_]u8{0xC2}));

    // Truncated three-byte sequence
    try std.testing.expect(!isValidUtf8(&[_]u8{0xE2}));
    try std.testing.expect(!isValidUtf8(&[_]u8{ 0xE2, 0x82 }));

    // Truncated four-byte sequence
    try std.testing.expect(!isValidUtf8(&[_]u8{0xF0}));
    try std.testing.expect(!isValidUtf8(&[_]u8{ 0xF0, 0x90 }));
    try std.testing.expect(!isValidUtf8(&[_]u8{ 0xF0, 0x90, 0x8D }));

    // Invalid start byte
    try std.testing.expect(!isValidUtf8(&[_]u8{0xFF}));
    try std.testing.expect(!isValidUtf8(&[_]u8{0xFE}));

    // Overlong encoding (2-byte encoding of ASCII)
    try std.testing.expect(!isValidUtf8(&[_]u8{ 0xC0, 0x80 }));
    try std.testing.expect(!isValidUtf8(&[_]u8{ 0xC1, 0xBF }));
}

test "Utf8Validator - simple valid" {
    var validator = Utf8Validator{};

    try std.testing.expect(validator.validate("Hello, World!"));
    try std.testing.expect(validator.finalize());
}

test "Utf8Validator - empty" {
    var validator = Utf8Validator{};

    try std.testing.expect(validator.validate(""));
    try std.testing.expect(validator.finalize());
}

test "Utf8Validator - multi-byte" {
    var validator = Utf8Validator{};

    try std.testing.expect(validator.validate("こんにちは"));
    try std.testing.expect(validator.finalize());
}

test "Utf8Validator - split ASCII" {
    var validator = Utf8Validator{};

    try std.testing.expect(validator.validate("Hel"));
    try std.testing.expect(validator.validate("lo"));
    try std.testing.expect(validator.finalize());
}

test "Utf8Validator - split multi-byte" {
    var validator = Utf8Validator{};

    // "こ" = E3 81 93
    // Split: [E3] + [81, 93]
    try std.testing.expect(validator.validate(&[_]u8{0xE3}));
    try std.testing.expect(validator.validate(&[_]u8{ 0x81, 0x93 }));
    try std.testing.expect(validator.finalize());
}

test "Utf8Validator - split at different boundaries" {
    // Split 3-byte character into 1+2
    {
        var v = Utf8Validator{};
        try std.testing.expect(v.validate(&[_]u8{0xE3}));
        try std.testing.expect(v.validate(&[_]u8{ 0x81, 0x93 }));
        try std.testing.expect(v.finalize());
    }

    // Split 3-byte character into 2+1
    {
        var v = Utf8Validator{};
        try std.testing.expect(v.validate(&[_]u8{ 0xE3, 0x81 }));
        try std.testing.expect(v.validate(&[_]u8{0x93}));
        try std.testing.expect(v.finalize());
    }

    // Split 4-byte character
    {
        var v = Utf8Validator{};
        // 𐍈 = F0 90 8D 88
        try std.testing.expect(v.validate(&[_]u8{0xF0}));
        try std.testing.expect(v.validate(&[_]u8{ 0x90, 0x8D }));
        try std.testing.expect(v.validate(&[_]u8{0x88}));
        try std.testing.expect(v.finalize());
    }
}

test "Utf8Validator - incomplete at end" {
    var validator = Utf8Validator{};

    // Incomplete 3-byte sequence
    try std.testing.expect(validator.validate(&[_]u8{ 0xE3, 0x81 }));
    try std.testing.expect(!validator.finalize());
}

test "Utf8Validator - invalid sequence" {
    var validator = Utf8Validator{};

    // Invalid continuation byte
    try std.testing.expect(!validator.validate(&[_]u8{ 0x80, 0x81 }));
    try std.testing.expect(validator.hasFailed());
}

test "Utf8Validator - valid then invalid" {
    var validator = Utf8Validator{};

    try std.testing.expect(validator.validate("Hello"));
    try std.testing.expect(!validator.validate(&[_]u8{0x80}));
    try std.testing.expect(validator.hasFailed());
}

test "Utf8Validator - reset" {
    var validator = Utf8Validator{};

    // Fail first
    _ = validator.validate(&[_]u8{0x80});
    try std.testing.expect(validator.hasFailed());

    // Reset and try again
    validator.reset();
    try std.testing.expect(!validator.hasFailed());
    try std.testing.expect(validator.validate("Hello"));
    try std.testing.expect(validator.finalize());
}

test "utf8ByteLength" {
    try std.testing.expectEqual(@as(usize, 5), utf8ByteLength("Hello"));
    try std.testing.expectEqual(@as(usize, 15), utf8ByteLength("こんにちは")); // 5 chars * 3 bytes
    try std.testing.expectEqual(@as(usize, 4), utf8ByteLength("🎉")); // 4-byte emoji
}

test "countCodePoints" {
    try std.testing.expectEqual(@as(?usize, 5), countCodePoints("Hello"));
    try std.testing.expectEqual(@as(?usize, 5), countCodePoints("こんにちは"));
    try std.testing.expectEqual(@as(?usize, 1), countCodePoints("🎉"));
    try std.testing.expectEqual(@as(?usize, 0), countCodePoints(""));

    // Invalid UTF-8
    try std.testing.expectEqual(@as(?usize, null), countCodePoints(&[_]u8{0x80}));
}

test "utf8SequenceLength" {
    // ASCII
    try std.testing.expectEqual(@as(u3, 1), utf8SequenceLength('A'));
    try std.testing.expectEqual(@as(u3, 1), utf8SequenceLength(0x00));
    try std.testing.expectEqual(@as(u3, 1), utf8SequenceLength(0x7F));

    // Two-byte
    try std.testing.expectEqual(@as(u3, 2), utf8SequenceLength(0xC2));
    try std.testing.expectEqual(@as(u3, 2), utf8SequenceLength(0xDF));

    // Three-byte
    try std.testing.expectEqual(@as(u3, 3), utf8SequenceLength(0xE0));
    try std.testing.expectEqual(@as(u3, 3), utf8SequenceLength(0xEF));

    // Four-byte
    try std.testing.expectEqual(@as(u3, 4), utf8SequenceLength(0xF0));
    try std.testing.expectEqual(@as(u3, 4), utf8SequenceLength(0xF7));

    // Invalid (continuation bytes or invalid start)
    try std.testing.expectEqual(@as(u3, 0), utf8SequenceLength(0x80));
    try std.testing.expectEqual(@as(u3, 0), utf8SequenceLength(0xBF));
    try std.testing.expectEqual(@as(u3, 0), utf8SequenceLength(0xF8));
    try std.testing.expectEqual(@as(u3, 0), utf8SequenceLength(0xFF));
}
