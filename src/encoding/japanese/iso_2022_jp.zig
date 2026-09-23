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
const reverse_index = @import("../reverse_index.zig");

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

    /// Find pointer using O(log n) binary search instead of O(n) linear scan.
    /// This provides ~500x speedup for encoding operations.
    /// Falls back to linear scan if reverse index not initialized.
    fn findPointer(code_point: u21) ?u32 {
        if (reverse_index.findJis0208Pointer(code_point)) |ptr| {
            return @intCast(ptr);
        }
        return null;
    }

    /// The iso-2022-jp encoder's handler (Encoding § 12.2.2) for one code
    /// point. "Restore code point to ioQueue" is folded into the same call:
    /// the escape sequence and the code point's own bytes come back together.
    ///
    /// On `error.Unencodable` the state is left as it was. Two of the spec's
    /// error paths first return to ASCII (step 6 for U+000E, U+000F and U+001B
    /// in JIS X 0208 state; step 11.1 for anything else unencodable there), and
    /// the escape that does so is output - the streaming encoder emits it,
    /// since an error return cannot carry bytes.
    pub fn encode(self: *Encoder, allocator: std.mem.Allocator, code_point_in: u21) ![]const u8 {
        var code_point = code_point_in;

        // Step 3: in ASCII or Roman state, U+000E, U+000F and U+001B are
        // errors (reported as U+FFFD by the caller).
        if ((self.state == .ascii or self.state == .roman) and isShiftOrEscape(code_point)) {
            return error.Unencodable;
        }

        // Step 4: ASCII in ASCII state is itself.
        if (self.state == .ascii and code_point < 0x80) {
            return bytes(allocator, &.{@intCast(code_point)});
        }

        // Step 5: Roman state keeps ASCII except U+005C and U+007E, and maps
        // U+00A5 and U+203E onto them.
        if (self.state == .roman) {
            if (code_point < 0x80 and code_point != 0x5C and code_point != 0x7E) {
                return bytes(allocator, &.{@intCast(code_point)});
            }
            if (code_point == 0x00A5) return bytes(allocator, &.{0x5C});
            if (code_point == 0x203E) return bytes(allocator, &.{0x7E});
        }

        // Step 6: other ASCII outside ASCII state: back to ASCII, then the
        // code point again - which step 3 rejects for the three controls.
        if (code_point < 0x80) {
            if (isShiftOrEscape(code_point)) return error.Unencodable;
            self.state = .ascii;
            return bytes(allocator, &.{ 0x1B, 0x28, 0x42, @intCast(code_point) });
        }

        // Step 7: U+00A5 and U+203E switch to Roman, then step 5 maps them.
        if (code_point == 0x00A5 or code_point == 0x203E) {
            self.state = .roman;
            return bytes(allocator, &.{ 0x1B, 0x28, 0x4A, if (code_point == 0x00A5) 0x5C else 0x7E });
        }

        // Step 8: U+2212 MINUS SIGN is encoded as U+FF0D FULLWIDTH HYPHEN-MINUS.
        if (code_point == 0x2212) code_point = 0xFF0D;

        // Step 9: halfwidth katakana become their fullwidth forms.
        if (code_point >= 0xFF61 and code_point <= 0xFF9F) {
            code_point = katakanaCodePoint(@intCast(code_point - 0xFF61)) orelse return error.Unencodable;
        }

        // Steps 10-11: the index pointer, or an error.
        const pointer = findPointer(code_point) orelse return error.Unencodable;

        // Steps 13-14.
        const lead: u8 = @intCast(pointer / 94 + 0x21);
        const trail: u8 = @intCast(pointer % 94 + 0x21);

        // Step 12: into JIS X 0208 first, if not already there.
        if (self.state != .jis0208) {
            self.state = .jis0208;
            return bytes(allocator, &.{ 0x1B, 0x24, 0x42, lead, trail });
        }

        // Step 15.
        return bytes(allocator, &.{ lead, trail });
    }

    fn isShiftOrEscape(code_point: u21) bool {
        return code_point == 0x000E or code_point == 0x000F or code_point == 0x001B;
    }

    /// The index code point for `pointer` in index ISO-2022-JP katakana.
    fn katakanaCodePoint(pointer: u8) ?u21 {
        for (katakana_index.INDEX) |entry| {
            if (entry.pointer == pointer) return entry.code_point;
        }
        return null;
    }

    fn bytes(allocator: std.mem.Allocator, data: []const u8) ![]const u8 {
        const result = try allocator.alloc(u8, data.len);
        @memcpy(result, data);
        return result;
    }
};
