//! x-user-defined Encoding
//!
//! WHATWG Encoding Standard - §14.5 x-user-defined
//! https://encoding.spec.whatwg.org/#x-user-defined
//!
//! x-user-defined is a simple single-byte encoding with algorithmic mapping:
//! - ASCII bytes (0x00-0x7F) map directly to Unicode
//! - Non-ASCII bytes (0x80-0xFF) map to Private Use Area: U+F780 + byte - 0x80
//!
//! This encoding is algorithmically defined and requires no index table.

const std = @import("std");

pub const Decoder = struct {
    pub fn decode(_: *Decoder, byte: ?u8) !?u21 {
        // 1. If byte is end-of-queue, return finished.
        if (byte == null) {
            return null;
        }

        const b = byte.?;

        // 2. If byte is an ASCII byte, return a code point whose value is byte.
        if (b < 0x80) {
            return @as(u21, b);
        }

        // 3. Return a code point whose value is 0xF780 + byte − 0x80.
        return @as(u21, 0xF780) + @as(u21, b) - 0x80;
    }
};

pub const Encoder = struct {
    pub fn encode(_: *Encoder, code_point: u21) !?[1]u8 {
        // 1. If code point is end-of-queue, return finished.
        // (handled by caller passing code_point)

        // 2. If code point is an ASCII code point, return a byte whose value is code point.
        if (code_point < 0x80) {
            return .{@intCast(code_point)};
        }

        // 3. If code point is in the range U+F780 to U+F7FF, inclusive,
        //    return a byte whose value is code point − 0xF780 + 0x80.
        if (code_point >= 0xF780 and code_point <= 0xF7FF) {
            const byte = code_point - 0xF780 + 0x80;
            return .{@intCast(byte)};
        }

        // 4. Return error.
        return error.InvalidCodePoint;
    }
};
