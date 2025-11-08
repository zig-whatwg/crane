//! Shift_JIS Encoding
//!
//! WHATWG Encoding Standard - §12.3 Shift_JIS
//! https://encoding.spec.whatwg.org/#shift_jis
//!
//! Shift_JIS is a Japanese encoding using 2-byte variable-length sequences.
//!
//! Decoder states:
//! - shift_jis_lead: waiting for first byte or processing ASCII
//!
//! Encoding structure:
//! - Single-byte: 0x00-0x7F (ASCII) and 0xA1-0xDF (halfwidth katakana)
//! - 2-byte sequences: (0x81-0x9F or 0xE0-0xFC) + (0x40-0x7E or 0x80-0xFC)

const std = @import("std");
const jis0208_index = @import("jis0208_index.zig");

pub const Decoder = struct {
    shift_jis_lead: u8 = 0x00,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        if (byte == null) {
            if (self.shift_jis_lead != 0x00) {
                self.shift_jis_lead = 0x00;
                return error.InvalidSequence;
            }
            return null;
        }

        const b = byte.?;

        if (self.shift_jis_lead != 0x00) {
            const lead = self.shift_jis_lead;
            self.shift_jis_lead = 0x00;

            const offset: u8 = if (b < 0x7F) 0x40 else 0x41;
            const lead_offset: u16 = if (lead < 0xA0) 0x81 else 0xC1;

            if ((b >= 0x40 and b <= 0x7E) or (b >= 0x80 and b <= 0xFC)) {
                const pointer: u32 = (@as(u32, lead - lead_offset) * 188) + (b - offset);

                if (pointer >= 8836 and pointer <= 10715) {
                    return @as(u21, @intCast(0xE000 + (pointer - 8836)));
                }

                if (pointer < jis0208_index.INDEX.len) {
                    const code_point = jis0208_index.INDEX[pointer];
                    if (code_point != 0) {
                        return code_point;
                    }
                }
            }

            return error.InvalidSequence;
        }

        if (b < 0x80) {
            return @as(u21, b);
        }

        if (b >= 0xA1 and b <= 0xDF) {
            return 0xFF61 + @as(u21, b - 0xA1);
        }

        if ((b >= 0x81 and b <= 0x9F) or (b >= 0xE0 and b <= 0xFC)) {
            self.shift_jis_lead = b;
            return null;
        }

        return error.InvalidSequence;
    }
};

pub const Encoder = struct {
    fn findPointer(code_point: u21) ?u32 {
        for (jis0208_index.INDEX, 0..) |cp, i| {
            if (cp == code_point) {
                return @intCast(i);
            }
        }
        return null;
    }

    pub fn encode(_: *Encoder, code_point: u21) !?[2]u8 {
        if (code_point < 0x80) {
            return .{ @intCast(code_point), 0 };
        }

        if (code_point == 0x00A5) {
            return .{ 0x5C, 0 };
        }

        if (code_point == 0x203E) {
            return .{ 0x7E, 0 };
        }

        if (code_point >= 0xFF61 and code_point <= 0xFF9F) {
            return .{ @intCast(code_point - 0xFF61 + 0xA1), 0 };
        }

        if (code_point == 0x2212) {
            if (findPointer(code_point)) |_| {} else {
                return .{ 0x81, 0x7C };
            }
        }

        if (findPointer(code_point)) |pointer| {
            const lead: u32 = pointer / 188;
            const lead_offset: u8 = if (lead < 0x1F) 0x81 else 0xC1;
            const trail: u8 = @intCast(pointer % 188);
            const offset: u8 = if (trail < 0x3F) 0x40 else 0x41;

            return .{
                @intCast(lead + lead_offset),
                @intCast(trail + offset),
            };
        }

        return error.InvalidCodePoint;
    }
};
