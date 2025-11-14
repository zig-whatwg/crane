// ! gb18030 Encoding
//!
//! WHATWG Encoding Standard - §10.2 gb18030
//! https://encoding.spec.whatwg.org/#gb18030
//!
//! gb18030 is a Chinese encoding that supports both 2-byte and 4-byte sequences.
//! It is a superset of GBK, which only uses 2-byte sequences.
//!
//! Decoder states:
//! - gb18030_first: waiting for first byte of sequence
//! - gb18030_second: have first byte, waiting for second
//! - gb18030_third: have first two bytes, waiting for third (4-byte mode)
//!
//! 2-byte sequences: 0x81-0xFE + 0x40-0x7E/0x80-0xFE
//! 4-byte sequences: 0x81-0xFE + 0x30-0x39 + 0x81-0xFE + 0x30-0x39

const std = @import("std");
const gb18030_index = @import("gb18030_index.zig");
const gb18030_ranges = @import("gb18030_ranges.zig");

/// gb18030 decoder state
pub const Decoder = struct {
    gb18030_first: u8 = 0x00,
    gb18030_second: u8 = 0x00,
    gb18030_third: u8 = 0x00,
    is_gbk: bool = false,

    /// Get code point from gb18030 ranges
    /// WHATWG spec §10.2.1 - index gb18030 ranges code point
    fn getRangesCodePoint(pointer: u32) ?u21 {
        // Step 1: If pointer is > 39419 and < 189000, or > 1237575, return null
        if ((pointer > 39419 and pointer < 189000) or pointer > 1237575) {
            return null;
        }

        // Step 2: If pointer is 7457, return U+E7C7
        if (pointer == 7457) {
            return 0xE7C7;
        }

        // Step 3-4: Find last range entry <= pointer and calculate code point
        var code_point_offset: u32 = 0;
        var pointer_offset: u32 = 0;

        for (gb18030_ranges.RANGES) |range| {
            if (range.pointer <= pointer) {
                pointer_offset = range.pointer;
                code_point_offset = range.code_point;
            } else {
                break;
            }
        }

        const code_point = code_point_offset + (pointer - pointer_offset);
        return @intCast(code_point);
    }

    /// Decode one byte
    /// WHATWG spec §10.2.1 - gb18030 decoder
    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        // Step 1-2: Handle end-of-stream
        if (byte == null) {
            if (self.gb18030_first != 0x00 or self.gb18030_second != 0x00 or self.gb18030_third != 0x00) {
                self.gb18030_first = 0x00;
                self.gb18030_second = 0x00;
                self.gb18030_third = 0x00;
                return error.InvalidSequence;
            }
            return null; // Finished
        }

        const b = byte.?;

        // Step 3: Handle 4-byte sequence (third byte present)
        if (self.gb18030_third != 0x00) {
            // Step 3.1: Check if byte is in range 0x30-0x39
            if (b < 0x30 or b > 0x39) {
                // Invalid sequence - reset and return error
                // Note: In spec, we would restore bytes, but we signal error instead
                self.gb18030_first = 0x00;
                self.gb18030_second = 0x00;
                self.gb18030_third = 0x00;
                return error.InvalidSequence;
            }

            // Step 3.2: Calculate pointer for 4-byte sequence
            const pointer = (@as(u32, self.gb18030_first - 0x81) * (10 * 126 * 10)) +
                (@as(u32, self.gb18030_second - 0x30) * (10 * 126)) +
                (@as(u32, self.gb18030_third - 0x81) * 10) +
                (b - 0x30);

            // Step 3.3-5: Reset state and get code point from ranges
            self.gb18030_first = 0x00;
            self.gb18030_second = 0x00;
            self.gb18030_third = 0x00;

            if (getRangesCodePoint(pointer)) |code_point| {
                return code_point;
            } else {
                return error.InvalidSequence;
            }
        }

        // Step 4: Handle second byte of 2-byte or start of 4-byte sequence
        if (self.gb18030_second != 0x00) {
            // Step 4.1: Check if entering 4-byte mode
            if (b >= 0x81 and b <= 0xFE) {
                self.gb18030_third = b;
                return null; // Continue
            }

            // Invalid sequence - reset and return error
            self.gb18030_first = 0x00;
            self.gb18030_second = 0x00;
            return error.InvalidSequence;
        }

        // Step 5: Handle first byte of sequence (leading byte present)
        if (self.gb18030_first != 0x00) {
            // Step 5.1: Check if starting 4-byte sequence
            if (b >= 0x30 and b <= 0x39) {
                self.gb18030_second = b;
                return null; // Continue
            }

            // Step 5.2-5.3: Save leading byte and reset
            const leading = self.gb18030_first;
            self.gb18030_first = 0x00;

            // Step 5.5-5.6: Calculate offset and pointer for 2-byte sequence
            const offset: u16 = if (b < 0x7F) 0x40 else 0x41;
            const pointer: ?u32 = if ((b >= 0x40 and b <= 0x7E) or (b >= 0x80 and b <= 0xFE))
                (@as(u32, leading - 0x81) * 190 + (b - offset))
            else
                null;

            // Step 5.7: Look up code point in index
            if (pointer) |p| {
                if (p < gb18030_index.INDEX.len) {
                    const code_point = gb18030_index.INDEX[p];
                    if (code_point != 0) {
                        return code_point;
                    }
                }
            }

            // Step 5.9-5.10: Error - would restore byte in spec
            return error.InvalidSequence;
        }

        // Step 6: ASCII byte
        if (b <= 0x7F) {
            return b;
        }

        // Step 7: U+20AC for byte 0x80
        if (b == 0x80) {
            return 0x20AC; // €
        }

        // Step 8: Start of 2-byte sequence
        if (b >= 0x81 and b <= 0xFE) {
            self.gb18030_first = b;
            return null; // Continue
        }

        // Step 9: Error
        return error.InvalidSequence;
    }
};

/// gb18030 encoder
pub const Encoder = struct {
    is_gbk: bool = false,

    /// Get pointer from gb18030 ranges
    /// WHATWG spec §10.2.1 - index gb18030 ranges pointer
    fn getRangesPointer(code_point: u21) u32 {
        // Step 1: If code_point is U+E7C7, return pointer 7457
        if (code_point == 0xE7C7) {
            return 7457;
        }

        // Step 2-3: Find last range entry <= code_point and calculate pointer
        var code_point_offset: u32 = 0;
        var pointer_offset: u32 = 0;

        for (gb18030_ranges.RANGES) |range| {
            if (range.code_point <= code_point) {
                pointer_offset = range.pointer;
                code_point_offset = range.code_point;
            } else {
                break;
            }
        }

        return pointer_offset + (code_point - code_point_offset);
    }

    /// Encode one code point
    /// WHATWG spec §10.2.2 - gb18030 encoder
    pub fn encode(self: Encoder, allocator: std.mem.Allocator, code_point: u21) ![]const u8 {
        // Step 1: ASCII code points
        if (code_point <= 0x7F) {
            var result = try allocator.alloc(u8, 1);
            result[0] = @intCast(code_point);
            return result;
        }

        // Step 2: U+E5E5 cannot be encoded (maps to 0xA3 0xA0 which is U+3000)
        if (code_point == 0xE5E5) {
            return error.Unencodable;
        }

        // Step 3: If GBK mode and code_point is U+20AC, return 0x80
        if (self.is_gbk and code_point == 0x20AC) {
            var result = try allocator.alloc(u8, 1);
            result[0] = 0x80;
            return result;
        }

        // Step 4: Special asymmetric mappings (GB18030-2022 compatibility)
        const special_mappings = [_]struct { cp: u21, b1: u8, b2: u8 }{
            .{ .cp = 0xE78D, .b1 = 0xA6, .b2 = 0xD9 },
            .{ .cp = 0xE78E, .b1 = 0xA6, .b2 = 0xDA },
            .{ .cp = 0xE78F, .b1 = 0xA6, .b2 = 0xDB },
            .{ .cp = 0xE790, .b1 = 0xA6, .b2 = 0xDC },
            .{ .cp = 0xE791, .b1 = 0xA6, .b2 = 0xDD },
            .{ .cp = 0xE792, .b1 = 0xA6, .b2 = 0xDE },
            .{ .cp = 0xE793, .b1 = 0xA6, .b2 = 0xDF },
            .{ .cp = 0xE794, .b1 = 0xA6, .b2 = 0xEC },
            .{ .cp = 0xE795, .b1 = 0xA6, .b2 = 0xED },
            .{ .cp = 0xE796, .b1 = 0xA6, .b2 = 0xF3 },
            .{ .cp = 0xE81E, .b1 = 0xFE, .b2 = 0x59 },
            .{ .cp = 0xE826, .b1 = 0xFE, .b2 = 0x61 },
            .{ .cp = 0xE82B, .b1 = 0xFE, .b2 = 0x66 },
            .{ .cp = 0xE82C, .b1 = 0xFE, .b2 = 0x67 },
            .{ .cp = 0xE832, .b1 = 0xFE, .b2 = 0x6D },
            .{ .cp = 0xE843, .b1 = 0xFE, .b2 = 0x7E },
            .{ .cp = 0xE854, .b1 = 0xFE, .b2 = 0x90 },
            .{ .cp = 0xE864, .b1 = 0xFE, .b2 = 0xA0 },
        };

        for (special_mappings) |mapping| {
            if (code_point == mapping.cp) {
                var result = try allocator.alloc(u8, 2);
                result[0] = mapping.b1;
                result[1] = mapping.b2;
                return result;
            }
        }

        // Step 5-6: Search index for 2-byte encoding
        for (gb18030_index.INDEX, 0..) |indexed_cp, pointer| {
            if (indexed_cp == code_point) {
                // Step 7: Calculate leading and trailing bytes
                const ptr: u32 = @intCast(pointer);
                const leading: u8 = @intCast(ptr / 190 + 0x81);
                const trailing_val: u32 = ptr % 190;
                const offset: u8 = if (trailing_val < 0x3F) 0x40 else 0x41;
                const trailing: u8 = @intCast(trailing_val + offset);

                var result = try allocator.alloc(u8, 2);
                result[0] = leading;
                result[1] = trailing;
                return result;
            }
        }

        // Step 7: If GBK mode, cannot use 4-byte sequences
        if (self.is_gbk) {
            return error.Unencodable;
        }

        // Step 8-15: Encode as 4-byte sequence using ranges
        const pointer = getRangesPointer(code_point);

        const byte1: u8 = @intCast(pointer / (10 * 126 * 10) + 0x81);
        const rem1: u32 = pointer % (10 * 126 * 10);
        const byte2: u8 = @intCast(rem1 / (10 * 126) + 0x30);
        const rem2: u32 = rem1 % (10 * 126);
        const byte3: u8 = @intCast(rem2 / 10 + 0x81);
        const byte4: u8 = @intCast(rem2 % 10 + 0x30);

        var result = try allocator.alloc(u8, 4);
        result[0] = byte1;
        result[1] = byte2;
        result[2] = byte3;
        result[3] = byte4;
        return result;
    }
};

// Tests



