//! ISO-2022-JP Encoding
//!
//! WHATWG Encoding Standard - §12.2 ISO-2022-JP
//! https://encoding.spec.whatwg.org/#iso-2022-jp
//!
//! ISO-2022-JP is a stateful Japanese encoding with mode switching via escape sequences.
//!
//! Decoder states:
//! - ASCII: default mode, 7-bit ASCII
//! - Roman: ISO-646-JP mode (¥ and ~ differ from ASCII)
//! - Katakana: JIS X 0201 halfwidth katakana mode
//! - LeadByte: first byte of 2-byte jis0208 sequence
//! - TrailByte: second byte of 2-byte jis0208 sequence
//! - EscapeStart: escape sequence started (0x1B)
//! - Escape: processing escape sequence
//!
//! Escape sequences:
//! - 0x1B 0x28 0x42: ASCII mode
//! - 0x1B 0x28 0x4A: Roman mode
//! - 0x1B 0x28 0x49: Katakana mode
//! - 0x1B 0x24 0x40: jis0208 mode
//! - 0x1B 0x24 0x42: jis0208 mode (alternate)

const std = @import("std");
const jis0208_index = @import("jis0208_index.zig");
const katakana_index = @import("iso2022jp_katakana_index.zig");

pub const DecoderState = enum {
    ascii,
    roman,
    katakana,
    lead_byte,
    trail_byte,
    escape_start,
    escape,
};

pub const Decoder = struct {
    state: DecoderState = .ascii,
    output_state: DecoderState = .ascii,
    iso2022jp_lead: u8 = 0x00,
    iso2022jp_output_flag: bool = false,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        if (byte == null) {
            if (self.state != .ascii and self.state != .roman and self.state != .katakana) {
                return error.InvalidSequence;
            }
            return null;
        }

        const b = byte.?;

        switch (self.state) {
            .ascii, .roman => {
                if (b == 0x1B) {
                    self.state = .escape_start;
                    return null;
                }

                if (b == 0x0E or b == 0x0F or b == 0x1B) {
                    return error.InvalidSequence;
                }

                if (b <= 0x7F and self.state == .ascii) {
                    return @as(u21, b);
                }

                if (b <= 0x7F and self.state == .roman) {
                    if (b == 0x5C) {
                        return 0x00A5;
                    }
                    if (b == 0x7E) {
                        return 0x203E;
                    }
                    return @as(u21, b);
                }

                return error.InvalidSequence;
            },

            .katakana => {
                if (b == 0x1B) {
                    self.state = .escape_start;
                    return null;
                }

                if (b >= 0x21 and b <= 0x5F) {
                    return 0xFF61 + @as(u21, b - 0x21);
                }

                return error.InvalidSequence;
            },

            .lead_byte => {
                if (b == 0x1B) {
                    self.state = .escape_start;
                    return error.InvalidSequence;
                }

                if (b >= 0x21 and b <= 0x7E) {
                    self.iso2022jp_lead = b;
                    self.state = .trail_byte;
                    return null;
                }

                return error.InvalidSequence;
            },

            .trail_byte => {
                if (b == 0x1B) {
                    self.state = .escape_start;
                    return error.InvalidSequence;
                }

                self.state = .lead_byte;

                if (b >= 0x21 and b <= 0x7E) {
                    const pointer: u32 = (@as(u32, self.iso2022jp_lead - 0x21) * 94) + (b - 0x21);

                    if (pointer < jis0208_index.INDEX.len) {
                        const code_point = jis0208_index.INDEX[pointer];
                        if (code_point != 0) {
                            return code_point;
                        }
                    }

                    return error.InvalidSequence;
                }

                return error.InvalidSequence;
            },

            .escape_start => {
                if (b == 0x24 or b == 0x28) {
                    self.iso2022jp_lead = b;
                    self.state = .escape;
                    return null;
                }

                self.state = self.output_state;
                return error.InvalidSequence;
            },

            .escape => {
                const lead = self.iso2022jp_lead;
                self.iso2022jp_lead = 0x00;

                if (lead == 0x28) {
                    if (b == 0x42) {
                        self.state = .ascii;
                        self.output_state = .ascii;
                        return null;
                    }
                    if (b == 0x4A) {
                        self.state = .roman;
                        self.output_state = .roman;
                        return null;
                    }
                    if (b == 0x49) {
                        self.state = .katakana;
                        self.output_state = .katakana;
                        return null;
                    }
                }

                if (lead == 0x24) {
                    if (b == 0x40 or b == 0x42) {
                        self.state = .lead_byte;
                        self.output_state = .lead_byte;
                        return null;
                    }
                }

                self.state = self.output_state;
                return error.InvalidSequence;
            },
        }
    }
};

pub const EncoderState = enum {
    ascii,
    roman,
    jis0208,
};

pub const Encoder = struct {
    state: EncoderState = .ascii,

    fn findPointer(code_point: u21) ?u32 {
        for (jis0208_index.INDEX, 0..) |cp, i| {
            if (cp == code_point) {
                return @intCast(i);
            }
        }
        return null;
    }

    fn findKatakanaPointer(code_point: u21) ?u8 {
        for (katakana_index.INDEX) |entry| {
            if (entry.code_point == code_point) {
                return entry.pointer;
            }
        }
        return null;
    }

    pub fn encode(self: *Encoder, allocator: std.mem.Allocator, code_point: u21) ![]const u8 {
        if (code_point < 0x80 and self.state != .ascii) {
            if (code_point == 0x000E or code_point == 0x000F or code_point == 0x001B) {
                return error.Unencodable;
            }

            self.state = .ascii;
            var result = try allocator.alloc(u8, 4);
            result[0] = 0x1B;
            result[1] = 0x28;
            result[2] = 0x42;
            result[3] = @intCast(code_point);
            return result;
        }

        if (code_point < 0x80) {
            if (code_point == 0x000E or code_point == 0x000F or code_point == 0x001B) {
                return error.Unencodable;
            }
            var result = try allocator.alloc(u8, 1);
            result[0] = @intCast(code_point);
            return result;
        }

        if (code_point == 0x00A5 or code_point == 0x203E) {
            if (self.state == .roman) {
                const byte: u8 = if (code_point == 0x00A5) 0x5C else 0x7E;
                var result = try allocator.alloc(u8, 1);
                result[0] = byte;
                return result;
            }

            if (self.state != .ascii) {
                self.state = .ascii;
                const byte: u8 = if (code_point == 0x00A5) 0x5C else 0x7E;
                var result = try allocator.alloc(u8, 4);
                result[0] = 0x1B;
                result[1] = 0x28;
                result[2] = 0x42;
                result[3] = byte;
                return result;
            }

            const byte: u8 = if (code_point == 0x00A5) 0x5C else 0x7E;
            var result = try allocator.alloc(u8, 1);
            result[0] = byte;
            return result;
        }

        if (code_point >= 0xFF61 and code_point <= 0xFF9F) {
            if (findKatakanaPointer(code_point)) |_| {
                if (findPointer(code_point)) |jis_pointer| {
                    if (self.state == .jis0208) {
                        const lead: u8 = @intCast(jis_pointer / 94 + 0x21);
                        const trail: u8 = @intCast(jis_pointer % 94 + 0x21);
                        var result = try allocator.alloc(u8, 2);
                        result[0] = lead;
                        result[1] = trail;
                        return result;
                    }

                    self.state = .jis0208;
                    const lead: u8 = @intCast(jis_pointer / 94 + 0x21);
                    const trail: u8 = @intCast(jis_pointer % 94 + 0x21);
                    var result = try allocator.alloc(u8, 5);
                    result[0] = 0x1B;
                    result[1] = 0x24;
                    result[2] = 0x42;
                    result[3] = lead;
                    result[4] = trail;
                    return result;
                }
            }
        }

        if (findPointer(code_point)) |pointer| {
            if (self.state == .jis0208) {
                const lead: u8 = @intCast(pointer / 94 + 0x21);
                const trail: u8 = @intCast(pointer % 94 + 0x21);
                var result = try allocator.alloc(u8, 2);
                result[0] = lead;
                result[1] = trail;
                return result;
            }

            self.state = .jis0208;
            const lead: u8 = @intCast(pointer / 94 + 0x21);
            const trail: u8 = @intCast(pointer % 94 + 0x21);
            var result = try allocator.alloc(u8, 5);
            result[0] = 0x1B;
            result[1] = 0x24;
            result[2] = 0x42;
            result[3] = lead;
            result[4] = trail;
            return result;
        }

        return error.Unencodable;
    }
};
