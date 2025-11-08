//! EUC-KR Encoding
//!
//! WHATWG Encoding Standard - §13.1 EUC-KR
//! https://encoding.spec.whatwg.org/#euc-kr
//!
//! EUC-KR is a Korean encoding using 2-byte variable-length sequences.
//!
//! Decoder states:
//! - euc_kr_lead: waiting for first byte or processing ASCII
//!
//! Encoding structure:
//! - Single-byte: 0x00-0x7F (ASCII)
//! - 2-byte sequences: 0x81-0xFE + 0x41-0xFE

const std = @import("std");
const euc_kr_index = @import("euc_kr_index.zig");

pub const Decoder = struct {
    euc_kr_lead: u8 = 0x00,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        if (byte == null) {
            if (self.euc_kr_lead != 0x00) {
                self.euc_kr_lead = 0x00;
                return error.InvalidSequence;
            }
            return null;
        }

        const b = byte.?;

        if (self.euc_kr_lead != 0x00) {
            const lead = self.euc_kr_lead;
            self.euc_kr_lead = 0x00;

            if (b < 0x41 or b == 0xFF) {
                return error.InvalidSequence;
            }

            const pointer: u32 = (@as(u32, lead - 0x81) * 190) + (b - 0x41);

            if (pointer < euc_kr_index.INDEX.len) {
                const code_point = euc_kr_index.INDEX[pointer];
                if (code_point != 0) {
                    return code_point;
                }
            }

            return error.InvalidSequence;
        }

        if (b < 0x80) {
            return @as(u21, b);
        }

        if (b >= 0x81 and b <= 0xFE) {
            self.euc_kr_lead = b;
            return null;
        }

        return error.InvalidSequence;
    }
};

pub const Encoder = struct {
    fn findPointer(code_point: u21) ?u32 {
        if (code_point < 0x80) return null;

        for (euc_kr_index.INDEX, 0..) |cp, i| {
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

        if (findPointer(code_point)) |pointer| {
            const lead: u8 = @intCast(pointer / 190 + 0x81);
            const trail: u8 = @intCast(pointer % 190 + 0x41);
            return .{ lead, trail };
        }

        return error.InvalidCodePoint;
    }
};
