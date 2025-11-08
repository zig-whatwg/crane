//! Big5 Encoding
//!
//! WHATWG Encoding Standard - §11.1 Big5
//! https://encoding.spec.whatwg.org/#big5
//!
//! Big5 is a traditional Chinese encoding widely used in Taiwan and Hong Kong.
//! It uses 2-byte variable-length sequences and includes the Hong Kong
//! Supplementary Character Set (HKSCS) and other common extensions.
//!
//! Decoder states:
//! - big5_lead: waiting for first byte or processing ASCII
//!
//! Encoding structure:
//! - Single-byte: 0x00-0x7F (ASCII)
//! - 2-byte sequences: 0x81-0xFE + (0x40-0x7E | 0xA1-0xFE)
//!
//! Special handling:
//! - Certain pointers (1133, 1135, 1164, 1166) return TWO code points
//! - The encoder uses index Big5 pointer algorithm for compatibility

const std = @import("std");
const big5_index = @import("big5_index.zig");

pub const Decoder = struct {
    big5_lead: u8 = 0x00,
    pending_code_point: ?u21 = null,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        // If we have a pending code point from a two-code-point sequence, return it first
        if (self.pending_code_point) |code_point| {
            self.pending_code_point = null;
            return code_point;
        }

        // 1. If byte is end-of-queue and Big5 leading is not 0x00,
        //    then set Big5 leading to 0x00 and return error.
        if (byte == null) {
            if (self.big5_lead != 0x00) {
                self.big5_lead = 0x00;
                return error.InvalidSequence;
            }
            return null;
        }

        const b = byte.?;

        // 3. If Big5 leading is not 0x00:
        if (self.big5_lead != 0x00) {
            const leading = self.big5_lead;
            self.big5_lead = 0x00;

            var pointer: ?u32 = null;
            const offset: u8 = if (b < 0x7F) 0x40 else 0x62;

            // If byte is in the range 0x40 to 0x7E, inclusive, or 0xA1 to 0xFE, inclusive,
            // then set pointer to (leading − 0x81) × 157 + (byte − offset).
            if ((b >= 0x40 and b <= 0x7E) or (b >= 0xA1 and b <= 0xFE)) {
                pointer = @as(u32, leading - 0x81) * 157 + (b - offset);
            }

            // WHATWG spec §11.1.1: Certain pointers return TWO code points
            // Pointer 1133 → U+00CA U+0304 (Ê̄)
            // Pointer 1135 → U+00CA U+030C (Ê̌)
            // Pointer 1164 → U+00EA U+0304 (ê̄)
            // Pointer 1166 → U+00EA U+030C (ê̌)
            if (pointer) |p| {
                switch (p) {
                    1133 => {
                        self.pending_code_point = 0x0304; // COMBINING MACRON
                        return 0x00CA; // LATIN CAPITAL LETTER E WITH CIRCUMFLEX
                    },
                    1135 => {
                        self.pending_code_point = 0x030C; // COMBINING CARON
                        return 0x00CA; // LATIN CAPITAL LETTER E WITH CIRCUMFLEX
                    },
                    1164 => {
                        self.pending_code_point = 0x0304; // COMBINING MACRON
                        return 0x00EA; // LATIN SMALL LETTER E WITH CIRCUMFLEX
                    },
                    1166 => {
                        self.pending_code_point = 0x030C; // COMBINING CARON
                        return 0x00EA; // LATIN SMALL LETTER E WITH CIRCUMFLEX
                    },
                    else => {},
                }
            }

            // Let codePoint be null if pointer is null;
            // otherwise the index code point for pointer in index Big5.
            if (pointer) |p| {
                if (p < big5_index.INDEX.len) {
                    const code_point = big5_index.INDEX[p];
                    if (code_point != 0) {
                        return code_point;
                    }
                }
            }

            // If byte is an ASCII byte, restore byte to ioQueue.
            // (We return error and let the caller handle re-processing)

            return error.InvalidSequence;
        }

        // 4. If byte is an ASCII byte, then return a code point whose value is byte.
        if (b < 0x80) {
            return @as(u21, b);
        }

        // 5. If byte is in the range 0x81 to 0xFE, inclusive,
        //    then set Big5 leading to byte and return continue.
        if (b >= 0x81 and b <= 0xFE) {
            self.big5_lead = b;
            return null;
        }

        // 6. Return error.
        return error.InvalidSequence;
    }
};

pub const Encoder = struct {
    fn findPointer(code_point: u21) ?u32 {
        // For ASCII, return null (handled separately)
        if (code_point < 0x80) return null;

        // The spec defines index Big5 pointer to exclude entries whose pointer
        // is less than (0xA1 - 0x81) × 157 = 0x20 × 157 = 5024
        // to avoid returning Hong Kong Supplementary Character Set extensions literally.

        const exclude_below: u32 = (0xA1 - 0x81) * 157; // 5024

        // For certain code points, return the last pointer (not the first)
        if (code_point == 0x2550 or // ═
            code_point == 0x255E or // ╞
            code_point == 0x2561 or // ╡
            code_point == 0x256A or // ╪
            code_point == 0x5341 or // 十
            code_point == 0x5345) // 卅
        {
            // Find the last occurrence
            var last_pointer: ?u32 = null;
            for (big5_index.INDEX, 0..) |cp, i| {
                if (cp == code_point and i >= exclude_below) {
                    last_pointer = @intCast(i);
                }
            }
            return last_pointer;
        }

        // For other code points, find the first occurrence >= exclude_below
        for (big5_index.INDEX[exclude_below..], 0..) |cp, i| {
            if (cp == code_point) {
                return @intCast(exclude_below + i);
            }
        }

        return null;
    }

    pub fn encode(_: *Encoder, code_point: u21) !?[2]u8 {
        // 1. If code point is end-of-queue, then return finished.
        // (handled by caller)

        // 2. If code point is an ASCII code point, then return a byte whose value is code point.
        if (code_point < 0x80) {
            return .{ @intCast(code_point), 0 };
        }

        // 3. Let pointer be the index Big5 pointer for code point.
        const pointer = findPointer(code_point) orelse {
            // 4. If pointer is null, then return error with code point.
            return error.InvalidCodePoint;
        };

        // 5. Let leading be pointer / 157 + 0x81.
        const leading: u8 = @intCast(pointer / 157 + 0x81);

        // 6. Let trailing be pointer % 157.
        const trailing_val = pointer % 157;

        // 7. Let offset be 0x40 if trailing is less than 0x3F; otherwise 0x62.
        const offset: u8 = if (trailing_val < 0x3F) 0x40 else 0x62;

        // 8. Return two bytes whose values are leading and trailing + offset.
        const trailing: u8 = @intCast(trailing_val + offset);

        return .{ leading, trailing };
    }
};
