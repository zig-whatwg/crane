//! Shared UTF-16 Decoder
//!
//! WHATWG Encoding Standard - §14.2 Common infrastructure for UTF-16BE/LE
//! https://encoding.spec.whatwg.org/#utf-16be-le
//!
//! This decoder is shared by both UTF-16BE and UTF-16LE.
//! The only difference is the byte order (controlled by is_utf16be_decoder flag).
//!
//! NOTE: UTF-16BE/LE have NO encoder per WHATWG spec.
//!
//! Decoder behavior:
//! - Reads 2 bytes at a time
//! - Handles surrogate pairs to produce code points U+10000 to U+10FFFF
//! - Returns error for invalid surrogate sequences

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");

// Use webidl.code_points for surrogate handling (per AGENTS.md: "Prefer WebIDL API over Infra")
const code_points = webidl.code_points;

pub const Decoder = struct {
    utf16_leading_byte: ?u8 = null,
    utf16_leading_surrogate: ?u16 = null,
    is_utf16be_decoder: bool,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        // 1. If byte is end-of-queue and either UTF-16 leading byte or
        //    UTF-16 leading surrogate is non-null, then set UTF-16 leading byte
        //    and UTF-16 leading surrogate to null, and return error.
        if (byte == null) {
            if (self.utf16_leading_byte != null or self.utf16_leading_surrogate != null) {
                self.utf16_leading_byte = null;
                self.utf16_leading_surrogate = null;
                return error.InvalidSequence;
            }
            return null;
        }

        const b = byte.?;

        // 3. If UTF-16 leading byte is null, then set UTF-16 leading byte to
        //    byte and return continue.
        if (self.utf16_leading_byte == null) {
            self.utf16_leading_byte = b;
            return null;
        }

        // 4. Let code unit be the result of:
        const code_unit: u16 = if (self.is_utf16be_decoder)
            // is UTF-16BE decoder is true: (UTF-16 leading byte << 8) + byte
            (@as(u16, self.utf16_leading_byte.?) << 8) + @as(u16, b)
        else
            // is UTF-16BE decoder is false: (byte << 8) + UTF-16 leading byte
            (@as(u16, b) << 8) + @as(u16, self.utf16_leading_byte.?);

        // 5. Set UTF-16 leading byte to null.
        self.utf16_leading_byte = null;

        // 6. If UTF-16 leading surrogate is non-null:
        if (self.utf16_leading_surrogate) |leading_surrogate| {
            // 6.1. Let leading surrogate be UTF-16 leading surrogate.
            // 6.2. Set UTF-16 leading surrogate to null.
            self.utf16_leading_surrogate = null;

            // 6.3. If code unit is a trailing surrogate, then return a scalar value
            //      from surrogates given leading surrogate and code unit.
            if (code_points.isTrailSurrogate(code_unit)) {
                // Obtain scalar value from surrogates (WHATWG Infra §4.5)
                const code_point = try code_points.decodeSurrogatePair(leading_surrogate, code_unit);
                return code_point;
            }

            // 6.4-6.7: Restore bytes and return error
            // (In a byte-by-byte decoder, we can't easily restore, so just error)
            return error.InvalidSequence;
        }

        // 7. If code unit is a leading surrogate, then set UTF-16 leading surrogate
        //    to code unit and return continue.
        if (code_points.isLeadSurrogate(code_unit)) {
            self.utf16_leading_surrogate = code_unit;
            return null;
        }

        // 8. If code unit is a trailing surrogate, then return error.
        if (code_points.isTrailSurrogate(code_unit)) {
            return error.InvalidSequence;
        }

        // 9. Return code point code unit.
        return @as(u21, code_unit);
    }
};
