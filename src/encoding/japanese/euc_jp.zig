//! EUC-JP Encoding
//!
//! WHATWG Encoding Standard - §12.1 EUC-JP
//! https://encoding.spec.whatwg.org/#euc-jp
//!
//! EUC-JP is a Japanese encoding using 2-byte and 3-byte variable-length sequences.
//!
//! Decoder states:
//! - euc_jp_lead: waiting for first byte or processing ASCII
//! - euc_jp_jis0212_flag: set when 0x8F prefix seen (3-byte mode)
//!
//! Encoding structure:
//! - Single-byte: 0x00-0x7F (ASCII)
//! - 2-byte sequences: 0x8E + 0xA1-0xDF (halfwidth katakana)
//!                     0xA1-0xFE + 0xA1-0xFE (jis0208)
//! - 3-byte sequences: 0x8F + 0xA1-0xFE + 0xA1-0xFE (jis0212)

const std = @import("std");
const jis0208_index = @import("jis0208_index.zig");
const jis0212_index = @import("jis0212_index.zig");

pub const Decoder = struct {
    euc_jp_lead: u8 = 0x00,
    euc_jp_jis0212_flag: bool = false,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        if (byte == null) {
            if (self.euc_jp_lead != 0x00 or self.euc_jp_jis0212_flag) {
                self.euc_jp_lead = 0x00;
                self.euc_jp_jis0212_flag = false;
                return error.InvalidSequence;
            }
            return null;
        }

        const b = byte.?;

        if (self.euc_jp_lead == 0x8E and b >= 0xA1 and b <= 0xDF) {
            self.euc_jp_lead = 0x00;
            return 0xFF61 + @as(u21, b - 0xA1);
        }

        if (self.euc_jp_lead == 0x8F and b >= 0xA1 and b <= 0xFE) {
            self.euc_jp_jis0212_flag = true;
            self.euc_jp_lead = b;
            return null;
        }

        if (self.euc_jp_lead != 0x00) {
            const lead = self.euc_jp_lead;
            self.euc_jp_lead = 0x00;

            const code_point: ?u21 = if (b >= 0xA1 and b <= 0xFE) blk: {
                const pointer: u32 = (@as(u32, lead - 0xA1) * 94) + (b - 0xA1);

                if (self.euc_jp_jis0212_flag) {
                    self.euc_jp_jis0212_flag = false;

                    if (pointer < jis0212_index.INDEX.len) {
                        const cp = jis0212_index.INDEX[pointer];
                        if (cp != 0) {
                            break :blk cp;
                        }
                    }
                } else {
                    if (pointer < jis0208_index.INDEX.len) {
                        const cp = jis0208_index.INDEX[pointer];
                        if (cp != 0) {
                            break :blk cp;
                        }
                    }
                }

                break :blk null;
            } else null;

            if (self.euc_jp_jis0212_flag) {
                self.euc_jp_jis0212_flag = false;
            }

            if (code_point) |cp| {
                return cp;
            }

            return error.InvalidSequence;
        }

        if (b < 0x80) {
            return @as(u21, b);
        }

        if (b == 0x8E or b == 0x8F or (b >= 0xA1 and b <= 0xFE)) {
            self.euc_jp_lead = b;
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

    pub fn encode(_: *Encoder, code_point: u21) !?[3]u8 {
        if (code_point < 0x80) {
            return .{ @intCast(code_point), 0, 0 };
        }

        if (code_point == 0x00A5) {
            return .{ 0x5C, 0, 0 };
        }

        if (code_point == 0x203E) {
            return .{ 0x7E, 0, 0 };
        }

        if (code_point >= 0xFF61 and code_point <= 0xFF9F) {
            return .{ 0x8E, @intCast(code_point - 0xFF61 + 0xA1), 0 };
        }

        if (code_point == 0x2212) {
            if (findPointer(code_point)) |_| {} else {
                return .{ 0xA1, 0xDD, 0 };
            }
        }

        if (findPointer(code_point)) |pointer| {
            const lead: u8 = @intCast(pointer / 94 + 0xA1);
            const trail: u8 = @intCast(pointer % 94 + 0xA1);
            return .{ lead, trail, 0 };
        }

        return error.InvalidCodePoint;
    }
};
