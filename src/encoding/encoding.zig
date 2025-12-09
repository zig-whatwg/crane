//! Static Encoding instances following the Firefox encoding_rs pattern
//!
//! Spec: https://encoding.spec.whatwg.org/#encodings

const std = @import("std");
const streaming = @import("streaming.zig");
const utf8 = @import("utf8.zig");
const utf16 = @import("utf16.zig");
const index_gen = @import("single_byte/index_generator.zig");
const single_byte = @import("single_byte.zig");
const chinese = @import("chinese.zig");
const japanese = @import("japanese.zig");
const korean = @import("korean.zig");
const miscellaneous = @import("miscellaneous.zig");

/// Function pointer type for decoding (to UTF-16)
pub const DecodeFn = *const fn (
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult;

/// Function pointer type for direct UTF-8 decoding (optimization path)
///
/// This allows decoders to output UTF-8 directly without going through
/// a UTF-16 intermediate buffer. This eliminates one memory allocation
/// and conversion step for legacy encodings.
///
/// If null, the decoder will fall back to decode() + UTF-16 to UTF-8 conversion.
pub const DecodeToUtf8Fn = *const fn (
    decoder: *Decoder,
    input: []const u8,
    output: []u8,
    is_last: bool,
) streaming.DecodeToUtf8Result;

/// Function pointer type for encoding
pub const EncodeFn = *const fn (
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult;

/// Function pointer type for max UTF-8 length calculation
/// Used by encodings that need custom buffer size calculations
pub const MaxUtf8LengthFn = *const fn (input_byte_length: usize) usize;

/// Encoding-specific max UTF-8 length calculators
pub const MaxUtf8Length = struct {
    /// Single-byte encodings: each byte maps to 1 code point, max 3 UTF-8 bytes each
    /// Used by: IBM866, ISO-8859-*, Windows-*, KOI8-*, Macintosh, x-mac-cyrillic
    pub fn singleByte(input_len: usize) usize {
        return input_len * 3;
    }

    /// UTF-8: 1:1 ratio (already UTF-8)
    pub fn utf8(input_len: usize) usize {
        return input_len;
    }

    /// EUC-KR, Shift_JIS, EUC-JP: 2 bytes -> 1 character -> max 3 UTF-8 bytes
    /// Worst case is all ASCII (1:1), but for safety use 3x
    pub fn eastAsianDouble(input_len: usize) usize {
        return input_len * 3;
    }

    /// ISO-2022-JP: stateful encoding with escape sequences
    /// Escape sequences produce no output, data bytes -> max 3 UTF-8 bytes each
    pub fn iso2022jp(input_len: usize) usize {
        return input_len * 3;
    }

    /// Big5: some sequences can produce 2 characters (HKSCS extensions)
    /// Worst case: 2 input bytes -> 2 chars -> 6 UTF-8 bytes
    pub fn big5(input_len: usize) usize {
        return input_len * 3; // Conservative: most chars are single
    }

    /// GB18030: 4-byte sequences can produce supplementary chars (4 UTF-8 bytes)
    /// Worst case: 4 input bytes -> 1 supplementary char -> 4 UTF-8 bytes = 1:1
    /// But single-byte ASCII is 1:1, and 2-byte is max 3 UTF-8
    pub fn gb18030(input_len: usize) usize {
        return input_len * 3; // Covers all cases safely
    }

    /// x-user-defined: each byte 0x80-0xFF maps to U+F780-F7FF (3-byte UTF-8)
    pub fn xUserDefined(input_len: usize) usize {
        return input_len * 3;
    }

    /// UTF-16BE/LE: 2 bytes -> 1 code unit -> max 3 UTF-8 bytes
    /// Or 4 bytes (surrogate pair) -> 1 supplementary char -> 4 UTF-8 bytes
    pub fn utf16(input_len: usize) usize {
        // Worst case: all BMP non-ASCII chars = input_len/2 * 3 = input_len * 1.5
        // But surrogate pairs: 4 bytes -> 4 UTF-8 bytes = 1:1
        // Use 2x for safety (handles odd-length inputs too)
        return input_len * 2;
    }

    /// Replacement encoding: produces only U+FFFD (3 bytes) once
    pub fn replacement(input_len: usize) usize {
        _ = input_len;
        return 3; // At most one replacement character
    }
};

pub const Encoding = struct {
    name: []const u8,
    whatwg_name: []const u8,
    decode_fn: DecodeFn,
    encode_fn: ?EncodeFn,
    /// Optional direct UTF-8 decode function (optimization path)
    /// If null, decodeToUtf8 falls back to decode() + UTF-16→UTF-8 conversion
    decode_to_utf8_fn: ?DecodeToUtf8Fn = null,
    /// Function to calculate max UTF-8 output bytes for given input bytes
    /// If null, uses default of input_len * 3
    max_utf8_length_fn: ?MaxUtf8LengthFn = null,
    /// Index for single-byte encodings (null for multi-byte encodings like UTF-8)
    single_byte_index: ?index_gen.Index = null,

    pub fn newDecoder(self: *const Encoding) Decoder {
        // Initialize state based on encoding type
        const initial_state = if (self.single_byte_index) |index|
            DecoderState{ .single_byte = .{ .index = index } }
        else
            DecoderState.neutral;

        return Decoder{
            .encoding = self,
            .state = initial_state,
        };
    }

    pub fn newEncoder(self: *const Encoding) ?Encoder {
        if (self.encode_fn == null) return null;

        return Encoder{
            .encoding = self,
            .state = .neutral,
        };
    }

    pub fn maxUtf16Length(self: *const Encoding, byte_length: usize) usize {
        _ = self;
        return byte_length;
    }

    /// Calculate maximum UTF-8 bytes needed for decoding given number of input bytes.
    /// Used for buffer allocation when decoding directly to UTF-8.
    ///
    /// This uses the encoding-specific calculator if available, otherwise
    /// defaults to input_len * 3 (worst case for BMP characters).
    pub fn maxUtf8LengthForInput(self: *const Encoding, input_byte_length: usize) usize {
        if (self.max_utf8_length_fn) |calc_fn| {
            return calc_fn(input_byte_length);
        }
        // Default: worst case for BMP characters (3 bytes per input byte)
        return input_byte_length * 3;
    }

    /// Calculate maximum UTF-8 bytes needed for given UTF-16 code units.
    /// Used when converting from UTF-16 intermediate buffer.
    pub fn maxUtf8Length(self: *const Encoding, code_unit_length: usize) usize {
        _ = self;
        return code_unit_length * 3;
    }

    /// Check if this encoding supports direct UTF-8 decode optimization.
    pub fn supportsDirectUtf8Decode(self: *const Encoding) bool {
        return self.decode_to_utf8_fn != null;
    }
};

pub const Decoder = struct {
    encoding: *const Encoding,
    state: DecoderState,

    pub fn decode(
        self: *Decoder,
        input: []const u8,
        output: []u16,
        is_last: bool,
    ) streaming.DecodeResult {
        return self.encoding.decode_fn(self, input, output, is_last);
    }

    /// Decode input bytes directly to UTF-8 output.
    ///
    /// If the encoding has a native decodeToUtf8 implementation, it will be used.
    /// Otherwise, this falls back to decode() + UTF-16 to UTF-8 conversion.
    ///
    /// The direct path eliminates one memory allocation and conversion step,
    /// providing significant performance improvement for legacy encodings.
    pub fn decodeToUtf8(
        self: *Decoder,
        input: []const u8,
        output: []u8,
        is_last: bool,
    ) streaming.DecodeToUtf8Result {
        // Use optimized direct path if available
        if (self.encoding.decode_to_utf8_fn) |decode_to_utf8_fn| {
            return decode_to_utf8_fn(self, input, output, is_last);
        }

        // Fallback: decode to UTF-16 then convert to UTF-8
        return decodeToUtf8Fallback(self, input, output, is_last);
    }

    /// Fallback implementation: decode to UTF-16, then convert to UTF-8.
    /// Used when no native decodeToUtf8 implementation is available.
    fn decodeToUtf8Fallback(
        self: *Decoder,
        input: []const u8,
        output: []u8,
        is_last: bool,
    ) streaming.DecodeToUtf8Result {
        // Use stack buffer for intermediate UTF-16 output
        // 256 code units handles most practical cases without heap allocation
        var utf16_buf: [256]u16 = undefined;

        var total_bytes_consumed: usize = 0;
        var total_bytes_written: usize = 0;
        var remaining_input = input;
        var remaining_output = output;

        while (remaining_input.len > 0 and remaining_output.len > 0) {
            // Decode chunk to UTF-16
            const decode_result = self.encoding.decode_fn(
                self,
                remaining_input,
                &utf16_buf,
                is_last and remaining_input.len <= utf16_buf.len,
            );

            // Convert UTF-16 to UTF-8
            const utf16_slice = utf16_buf[0..decode_result.code_units_written];
            var utf8_written: usize = 0;

            for (utf16_slice) |code_unit| {
                const needed = utf8BytesNeeded(code_unit);
                if (utf8_written + needed > remaining_output.len) {
                    // Output buffer full - return what we have
                    return .{
                        .status = .output_full,
                        .bytes_consumed = total_bytes_consumed,
                        .bytes_written = total_bytes_written + utf8_written,
                    };
                }

                utf8_written += writeUtf8CodeUnit(code_unit, remaining_output[utf8_written..]);
            }

            total_bytes_consumed += decode_result.bytes_consumed;
            total_bytes_written += utf8_written;
            remaining_input = remaining_input[decode_result.bytes_consumed..];
            remaining_output = remaining_output[utf8_written..];

            // Handle decode status
            switch (decode_result.status) {
                .malformed => {
                    return .{
                        .status = .malformed,
                        .bytes_consumed = total_bytes_consumed,
                        .bytes_written = total_bytes_written,
                        .error_length = decode_result.error_length,
                    };
                },
                .output_full => {
                    // UTF-16 buffer was filled, continue with next chunk
                    continue;
                },
                .input_empty => {
                    // All input consumed
                    break;
                },
            }
        }

        return .{
            .status = .input_empty,
            .bytes_consumed = total_bytes_consumed,
            .bytes_written = total_bytes_written,
        };
    }
};

/// Calculate number of UTF-8 bytes needed for a UTF-16 code unit.
fn utf8BytesNeeded(code_unit: u16) usize {
    if (code_unit < 0x80) return 1;
    if (code_unit < 0x800) return 2;
    return 3;
}

/// Write a BMP code point (from UTF-16 code unit) as UTF-8.
/// Returns number of bytes written.
fn writeUtf8CodeUnit(code_unit: u16, output: []u8) usize {
    const cp: u21 = code_unit;

    if (cp < 0x80) {
        output[0] = @intCast(cp);
        return 1;
    } else if (cp < 0x800) {
        output[0] = @intCast(0xC0 | (cp >> 6));
        output[1] = @intCast(0x80 | (cp & 0x3F));
        return 2;
    } else {
        output[0] = @intCast(0xE0 | (cp >> 12));
        output[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        output[2] = @intCast(0x80 | (cp & 0x3F));
        return 3;
    }
}

pub const Encoder = struct {
    encoding: *const Encoding,
    state: EncoderState,

    pub fn encode(
        self: *Encoder,
        input: []const u16,
        output: []u8,
        is_last: bool,
    ) streaming.EncodeResult {
        if (self.encoding.encode_fn) |encode_fn| {
            return encode_fn(self, input, output, is_last);
        }
        return .{
            .status = .unmappable,
            .code_units_consumed = 0,
            .bytes_written = 0,
        };
    }
};

pub const DecoderState = union(enum) {
    neutral,
    utf8: struct {
        code_point: u21,
        bytes_seen: u8,
        bytes_needed: u8,
        lower_boundary: u8,
        upper_boundary: u8,
    },
    single_byte: struct {
        index: index_gen.Index,
    },
    gb18030: struct {
        gb18030_first: u8,
        gb18030_second: u8,
        gb18030_third: u8,
        is_gbk: bool,
    },
    euc_kr: struct {
        euc_kr_lead: u8,
    },
    shift_jis: struct {
        shift_jis_lead: u8,
    },
    euc_jp: struct {
        euc_jp_lead: u8,
        euc_jp_jis0212_flag: bool,
    },
    iso_2022_jp: struct {
        state: japanese.iso_2022_jp.DecoderState,
        output_state: japanese.iso_2022_jp.DecoderState,
        iso2022jp_lead: u8,
        iso2022jp_output_flag: bool,
    },
    x_user_defined: struct {},
    big5: struct {
        big5_lead: u8,
        pending_code_point: ?u21,
    },
    replacement: struct {
        replacement_error_returned: bool,
    },
    utf16be: struct {
        utf16_leading_byte: ?u8,
        utf16_leading_surrogate: ?u16,
    },
    utf16le: struct {
        utf16_leading_byte: ?u8,
        utf16_leading_surrogate: ?u16,
    },
};

pub const EncoderState = union(enum) {
    neutral,
    gb18030: struct {
        is_gbk: bool,
        pending_high_surrogate: ?u16,
    },
    euc_kr: struct {
        pending_high_surrogate: ?u16,
    },
    shift_jis: struct {
        pending_high_surrogate: ?u16,
    },
    euc_jp: struct {
        pending_high_surrogate: ?u16,
    },
    iso_2022_jp: struct {
        state: japanese.iso_2022_jp.EncoderState,
        pending_high_surrogate: ?u16,
    },
    x_user_defined: struct {
        pending_high_surrogate: ?u16,
    },
    big5: struct {
        pending_high_surrogate: ?u16,
    },
};

// Static Encoding Instances
pub const UTF_8: Encoding = .{
    .name = "UTF-8",
    .whatwg_name = "utf-8",
    .decode_fn = utf8.decode,
    .encode_fn = utf8.encode,
    .max_utf8_length_fn = MaxUtf8Length.utf8,
};

// Single-byte encoding instances
pub const IBM866: Encoding = .{
    .name = "ibm866",
    .whatwg_name = "ibm866",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.ibm866.INDEX,
};

pub const ISO_8859_2: Encoding = .{
    .name = "iso-8859-2",
    .whatwg_name = "iso-8859-2",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_2.INDEX,
};

pub const ISO_8859_3: Encoding = .{
    .name = "iso-8859-3",
    .whatwg_name = "iso-8859-3",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_3.INDEX,
};

pub const ISO_8859_4: Encoding = .{
    .name = "iso-8859-4",
    .whatwg_name = "iso-8859-4",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_4.INDEX,
};

pub const ISO_8859_5: Encoding = .{
    .name = "iso-8859-5",
    .whatwg_name = "iso-8859-5",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_5.INDEX,
};

pub const ISO_8859_6: Encoding = .{
    .name = "iso-8859-6",
    .whatwg_name = "iso-8859-6",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_6.INDEX,
};

pub const ISO_8859_7: Encoding = .{
    .name = "iso-8859-7",
    .whatwg_name = "iso-8859-7",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_7.INDEX,
};

pub const ISO_8859_8: Encoding = .{
    .name = "iso-8859-8",
    .whatwg_name = "iso-8859-8",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_8.INDEX,
};

pub const ISO_8859_8_I: Encoding = .{
    .name = "iso-8859-8-i",
    .whatwg_name = "iso-8859-8-i",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_8_i.INDEX,
};

pub const ISO_8859_10: Encoding = .{
    .name = "iso-8859-10",
    .whatwg_name = "iso-8859-10",
    .decode_fn = single_byte.decode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .encode_fn = single_byte.encode,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_10.INDEX,
};

pub const ISO_8859_13: Encoding = .{
    .name = "iso-8859-13",
    .whatwg_name = "iso-8859-13",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_13.INDEX,
};

pub const ISO_8859_14: Encoding = .{
    .name = "iso-8859-14",
    .whatwg_name = "iso-8859-14",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_14.INDEX,
};

pub const ISO_8859_15: Encoding = .{
    .name = "iso-8859-15",
    .whatwg_name = "iso-8859-15",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_15.INDEX,
};

pub const ISO_8859_16: Encoding = .{
    .name = "iso-8859-16",
    .whatwg_name = "iso-8859-16",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.iso_8859_16.INDEX,
};

pub const KOI8_R: Encoding = .{
    .name = "koi8-r",
    .whatwg_name = "koi8-r",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.koi8_r.INDEX,
};

pub const KOI8_U: Encoding = .{
    .name = "koi8-u",
    .whatwg_name = "koi8-u",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.koi8_u.INDEX,
};

pub const MACINTOSH: Encoding = .{
    .name = "macintosh",
    .whatwg_name = "macintosh",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.macintosh.INDEX,
};

pub const WINDOWS_874: Encoding = .{
    .name = "windows-874",
    .whatwg_name = "windows-874",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_874.INDEX,
};

pub const WINDOWS_1250: Encoding = .{
    .name = "windows-1250",
    .whatwg_name = "windows-1250",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1250.INDEX,
};

pub const WINDOWS_1251: Encoding = .{
    .name = "windows-1251",
    .whatwg_name = "windows-1251",
    .decode_fn = single_byte.decode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .encode_fn = single_byte.encode,
    .single_byte_index = single_byte.windows_1251.INDEX,
};

pub const WINDOWS_1252: Encoding = .{
    .name = "windows-1252",
    .whatwg_name = "windows-1252",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1252.INDEX,
};

pub const WINDOWS_1253: Encoding = .{
    .name = "windows-1253",
    .whatwg_name = "windows-1253",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1253.INDEX,
};

pub const WINDOWS_1254: Encoding = .{
    .name = "windows-1254",
    .whatwg_name = "windows-1254",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1254.INDEX,
};

pub const WINDOWS_1255: Encoding = .{
    .name = "windows-1255",
    .whatwg_name = "windows-1255",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1255.INDEX,
};

pub const WINDOWS_1256: Encoding = .{
    .name = "windows-1256",
    .whatwg_name = "windows-1256",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1256.INDEX,
};

pub const WINDOWS_1257: Encoding = .{
    .name = "windows-1257",
    .whatwg_name = "windows-1257",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1257.INDEX,
};

pub const WINDOWS_1258: Encoding = .{
    .name = "windows-1258",
    .whatwg_name = "windows-1258",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.windows_1258.INDEX,
};

pub const X_MAC_CYRILLIC: Encoding = .{
    .name = "x-mac-cyrillic",
    .whatwg_name = "x-mac-cyrillic",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .decode_to_utf8_fn = single_byte.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.singleByte,
    .single_byte_index = single_byte.x_mac_cyrillic.INDEX,
};

// Chinese encodings
pub const GB18030: Encoding = .{
    .name = "gb18030",
    .whatwg_name = "gb18030",
    .decode_fn = chinese.decode,
    .encode_fn = chinese.encode,
    .decode_to_utf8_fn = chinese.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.gb18030,
};

pub const GBK: Encoding = .{
    .name = "gbk",
    .whatwg_name = "gbk",
    .decode_fn = chinese.decode,
    .encode_fn = chinese.encode,
    .max_utf8_length_fn = MaxUtf8Length.gb18030, // GBK is subset of GB18030
};

pub const EUC_KR: Encoding = .{
    .name = "euc-kr",
    .whatwg_name = "euc-kr",
    .decode_fn = korean.euc_kr_streaming.decode,
    .encode_fn = korean.euc_kr_streaming.encode,
    .decode_to_utf8_fn = korean.euc_kr_streaming.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.eastAsianDouble,
};

pub const SHIFT_JIS: Encoding = .{
    .name = "shift_jis",
    .whatwg_name = "shift_jis",
    .decode_fn = japanese.shift_jis_streaming.decode,
    .encode_fn = japanese.shift_jis_streaming.encode,
    .decode_to_utf8_fn = japanese.shift_jis_streaming.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.eastAsianDouble,
};

pub const EUC_JP: Encoding = .{
    .name = "euc-jp",
    .whatwg_name = "euc-jp",
    .decode_fn = japanese.euc_jp_streaming.decode,
    .encode_fn = japanese.euc_jp_streaming.encode,
    .decode_to_utf8_fn = japanese.euc_jp_streaming.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.eastAsianDouble,
};

pub const ISO_2022_JP: Encoding = .{
    .name = "iso-2022-jp",
    .whatwg_name = "iso-2022-jp",
    .decode_fn = japanese.iso_2022_jp_streaming.decode,
    .encode_fn = japanese.iso_2022_jp_streaming.encode,
    .decode_to_utf8_fn = japanese.iso_2022_jp_streaming.decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.iso2022jp,
};

pub const X_USER_DEFINED: Encoding = .{
    .name = "x-user-defined",
    .whatwg_name = "x-user-defined",
    .decode_fn = miscellaneous.x_user_defined_streaming.decode,
    .encode_fn = miscellaneous.x_user_defined_streaming.encode,
    .max_utf8_length_fn = MaxUtf8Length.xUserDefined,
};

pub const BIG5: Encoding = .{
    .name = "Big5",
    .whatwg_name = "Big5",
    .decode_fn = chinese.big5_streaming_decode,
    .encode_fn = chinese.big5_streaming_encode,
    .decode_to_utf8_fn = chinese.big5_streaming_decodeToUtf8,
    .max_utf8_length_fn = MaxUtf8Length.big5,
};

pub const REPLACEMENT: Encoding = .{
    .name = "replacement",
    .whatwg_name = "replacement",
    .decode_fn = miscellaneous.replacement_streaming.decode,
    .encode_fn = null, // replacement has NO encoder per WHATWG spec
    .max_utf8_length_fn = MaxUtf8Length.replacement,
};

pub const UTF_16BE: Encoding = .{
    .name = "UTF-16BE",
    .whatwg_name = "UTF-16BE",
    .max_utf8_length_fn = MaxUtf8Length.utf16,
    .decode_fn = utf16.utf16be_streaming.decode,
    .encode_fn = null, // UTF-16BE has NO encoder per WHATWG spec
};

pub const UTF_16LE: Encoding = .{
    .name = "UTF-16LE",
    .whatwg_name = "UTF-16LE",
    .decode_fn = utf16.utf16le_streaming.decode,
    .encode_fn = null, // UTF-16LE has NO encoder per WHATWG spec
    .max_utf8_length_fn = MaxUtf8Length.utf16,
};

// ALL_ENCODINGS array
pub const ALL_ENCODINGS = [_]*const Encoding{
    &UTF_8,
    &IBM866,
    &ISO_8859_2,
    &ISO_8859_3,
    &ISO_8859_4,
    &ISO_8859_5,
    &ISO_8859_6,
    &ISO_8859_7,
    &ISO_8859_8,
    &ISO_8859_8_I,
    &ISO_8859_10,
    &ISO_8859_13,
    &ISO_8859_14,
    &ISO_8859_15,
    &ISO_8859_16,
    &KOI8_R,
    &KOI8_U,
    &MACINTOSH,
    &WINDOWS_874,
    &WINDOWS_1250,
    &WINDOWS_1251,
    &WINDOWS_1252,
    &WINDOWS_1253,
    &WINDOWS_1254,
    &WINDOWS_1255,
    &WINDOWS_1256,
    &WINDOWS_1257,
    &WINDOWS_1258,
    &X_MAC_CYRILLIC,
    &GB18030,
    &GBK,
    &EUC_KR,
    &SHIFT_JIS,
    &EUC_JP,
    &ISO_2022_JP,
    &X_USER_DEFINED,
    &BIG5,
    &REPLACEMENT,
    &UTF_16BE,
    &UTF_16LE,
};

/// Get encoding from a label (name).
///
/// WHATWG Encoding Standard §4.2.1 - "get an encoding"
/// https://encoding.spec.whatwg.org/#concept-encoding-get
///
/// Algorithm (from spec):
/// 1. Remove any leading and trailing ASCII whitespace from label.
/// 2. If label is an ASCII case-insensitive match for any of the labels
///    listed in the table below, then return the corresponding encoding;
///    otherwise return failure.
///
/// Implementation Note (Priority 1 - Spec Compliance):
/// The spec algorithm works on DOMString (UTF-16) using:
///   - infra.string.stripLeadingAndTrailingAsciiWhitespace(label)
///   - infra.string.isAsciiCaseInsensitiveMatch(trimmed, encoding_label)
///
/// This implementation uses byte-level operations for performance since
/// encoding labels are guaranteed to be ASCII-only. Byte-level operations
/// are equivalent to UTF-16 operations for ASCII and avoid conversion overhead.
///
/// For complete spec compliance with UTF-16 inputs, see text_decoder.zig which
/// converts DOMString → UTF-8 before calling this function.
/// Get an encoding from a label (WHATWG Encoding Standard §4.2)
///
/// https://encoding.spec.whatwg.org/#concept-encoding-get
///
/// Steps per spec:
/// 1. Remove leading/trailing ASCII whitespace from label
/// 2. ASCII case-insensitive match against encoding labels
/// 3. Return matching encoding or failure (null)
///
/// Note: Uses std.ascii.eqlIgnoreCase for ASCII case-insensitive comparison,
/// which is equivalent to WHATWG Infra's ASCII case-insensitive match without
/// requiring UTF-8 ↔ UTF-16 conversion (infra operates on UTF-16 strings).
pub fn getEncoding(label: []const u8) ?*const Encoding {
    // Step 1: Remove leading and trailing ASCII whitespace
    // ASCII whitespace per WHATWG Infra §2.3: U+0009 TAB, U+000A LF, U+000C FF, U+000D CR, U+0020 SPACE
    const whitespace = [_]u8{ 0x09, 0x0A, 0x0C, 0x0D, 0x20 };
    const trimmed = std.mem.trim(u8, label, &whitespace);

    // Step 2: ASCII case-insensitive match
    // Uses std.ascii.eqlIgnoreCase (operates on UTF-8/bytes) instead of
    // infra.string functions (operate on UTF-16) to avoid conversion overhead

    // utf-8 labels
    const utf_8_labels = [_][]const u8{ "unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8", "utf-8", "utf8", "x-unicode20utf8" };
    for (utf_8_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &UTF_8;
    }

    // ibm866 labels
    const ibm866_labels = [_][]const u8{ "866", "cp866", "csibm866", "ibm866" };
    for (ibm866_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &IBM866;
    }

    // iso-8859-2 labels
    const iso_8859_2_labels = [_][]const u8{ "csisolatin2", "iso-8859-2", "iso-ir-101", "iso8859-2", "iso88592", "iso_8859-2", "iso_8859-2:1987", "l2", "latin2" };
    for (iso_8859_2_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_2;
    }

    // iso-8859-3 labels
    const iso_8859_3_labels = [_][]const u8{ "csisolatin3", "iso-8859-3", "iso-ir-109", "iso8859-3", "iso88593", "iso_8859-3", "iso_8859-3:1988", "l3", "latin3" };
    for (iso_8859_3_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_3;
    }

    // iso-8859-4 labels
    const iso_8859_4_labels = [_][]const u8{ "csisolatin4", "iso-8859-4", "iso-ir-110", "iso8859-4", "iso88594", "iso_8859-4", "iso_8859-4:1988", "l4", "latin4" };
    for (iso_8859_4_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_4;
    }

    // iso-8859-5 labels
    const iso_8859_5_labels = [_][]const u8{ "csisolatincyrillic", "cyrillic", "iso-8859-5", "iso-ir-144", "iso8859-5", "iso88595", "iso_8859-5", "iso_8859-5:1988" };
    for (iso_8859_5_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_5;
    }

    // iso-8859-6 labels
    const iso_8859_6_labels = [_][]const u8{ "arabic", "asmo-708", "csiso88596e", "csiso88596i", "csisolatinarabic", "ecma-114", "iso-8859-6", "iso-8859-6-e", "iso-8859-6-i", "iso-ir-127", "iso8859-6", "iso88596", "iso_8859-6", "iso_8859-6:1987" };
    for (iso_8859_6_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_6;
    }

    // iso-8859-7 labels
    const iso_8859_7_labels = [_][]const u8{ "csisolatingreek", "ecma-118", "elot_928", "greek", "greek8", "iso-8859-7", "iso-ir-126", "iso8859-7", "iso88597", "iso_8859-7", "iso_8859-7:1987", "sun_eu_greek" };
    for (iso_8859_7_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_7;
    }

    // iso-8859-8 labels
    const iso_8859_8_labels = [_][]const u8{ "csiso88598e", "csisolatinhebrew", "hebrew", "iso-8859-8", "iso-8859-8-e", "iso-ir-138", "iso8859-8", "iso88598", "iso_8859-8", "iso_8859-8:1988", "visual" };
    for (iso_8859_8_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_8;
    }

    // iso-8859-8-i labels
    const iso_8859_8_i_labels = [_][]const u8{ "csiso88598i", "iso-8859-8-i", "logical" };
    for (iso_8859_8_i_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_8_I;
    }

    // iso-8859-10 labels
    const iso_8859_10_labels = [_][]const u8{ "csisolatin6", "iso-8859-10", "iso-ir-157", "iso8859-10", "iso885910", "l6", "latin6" };
    for (iso_8859_10_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_10;
    }

    // iso-8859-13 labels
    const iso_8859_13_labels = [_][]const u8{ "iso-8859-13", "iso8859-13", "iso885913" };
    for (iso_8859_13_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_13;
    }

    // iso-8859-14 labels
    const iso_8859_14_labels = [_][]const u8{ "iso-8859-14", "iso8859-14", "iso885914" };
    for (iso_8859_14_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_14;
    }

    // iso-8859-15 labels
    const iso_8859_15_labels = [_][]const u8{ "csisolatin9", "iso-8859-15", "iso8859-15", "iso885915", "iso_8859-15", "l9" };
    for (iso_8859_15_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_15;
    }

    // iso-8859-16 labels
    const iso_8859_16_labels = [_][]const u8{"iso-8859-16"};
    for (iso_8859_16_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_8859_16;
    }

    // koi8-r labels
    const koi8_r_labels = [_][]const u8{ "cskoi8r", "koi", "koi8", "koi8-r", "koi8_r" };
    for (koi8_r_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &KOI8_R;
    }

    // koi8-u labels
    const koi8_u_labels = [_][]const u8{ "koi8-ru", "koi8-u" };
    for (koi8_u_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &KOI8_U;
    }

    // macintosh labels
    const macintosh_labels = [_][]const u8{ "csmacintosh", "mac", "macintosh", "x-mac-roman" };
    for (macintosh_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &MACINTOSH;
    }

    // windows-874 labels
    const windows_874_labels = [_][]const u8{ "dos-874", "iso-8859-11", "iso8859-11", "iso885911", "tis-620", "windows-874" };
    for (windows_874_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_874;
    }

    // windows-1250 labels
    const windows_1250_labels = [_][]const u8{ "cp1250", "windows-1250", "x-cp1250" };
    for (windows_1250_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1250;
    }

    // windows-1251 labels
    const windows_1251_labels = [_][]const u8{ "cp1251", "windows-1251", "x-cp1251" };
    for (windows_1251_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1251;
    }

    // windows-1252 labels
    const windows_1252_labels = [_][]const u8{ "ansi_x3.4-1968", "ascii", "cp1252", "cp819", "csisolatin1", "ibm819", "iso-8859-1", "iso-ir-100", "iso8859-1", "iso88591", "iso_8859-1", "iso_8859-1:1987", "l1", "latin1", "us-ascii", "windows-1252", "x-cp1252" };
    for (windows_1252_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1252;
    }

    // windows-1253 labels
    const windows_1253_labels = [_][]const u8{ "cp1253", "windows-1253", "x-cp1253" };
    for (windows_1253_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1253;
    }

    // windows-1254 labels
    const windows_1254_labels = [_][]const u8{ "cp1254", "csisolatin5", "iso-8859-9", "iso-ir-148", "iso8859-9", "iso88599", "iso_8859-9", "iso_8859-9:1989", "l5", "latin5", "windows-1254", "x-cp1254" };
    for (windows_1254_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1254;
    }

    // windows-1255 labels
    const windows_1255_labels = [_][]const u8{ "cp1255", "windows-1255", "x-cp1255" };
    for (windows_1255_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1255;
    }

    // windows-1256 labels
    const windows_1256_labels = [_][]const u8{ "cp1256", "windows-1256", "x-cp1256" };
    for (windows_1256_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1256;
    }

    // windows-1257 labels
    const windows_1257_labels = [_][]const u8{ "cp1257", "windows-1257", "x-cp1257" };
    for (windows_1257_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1257;
    }

    // windows-1258 labels
    const windows_1258_labels = [_][]const u8{ "cp1258", "windows-1258", "x-cp1258" };
    for (windows_1258_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &WINDOWS_1258;
    }

    // x-mac-cyrillic labels
    const x_mac_cyrillic_labels = [_][]const u8{ "x-mac-cyrillic", "x-mac-ukrainian" };
    for (x_mac_cyrillic_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &X_MAC_CYRILLIC;
    }

    // gb18030 labels
    const gb18030_labels = [_][]const u8{"gb18030"};
    for (gb18030_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &GB18030;
    }

    // gbk labels
    const gbk_labels = [_][]const u8{ "chinese", "csgb2312", "csiso58gb231280", "gb2312", "gb_2312", "gb_2312-80", "gbk", "iso-ir-58", "x-gbk" };
    for (gbk_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &GBK;
    }

    const euc_kr_labels = [_][]const u8{ "cseuckr", "csksc56011987", "euc-kr", "iso-ir-149", "korean", "ks_c_5601-1987", "ks_c_5601-1989", "ksc5601", "ksc_5601", "windows-949" };
    for (euc_kr_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &EUC_KR;
    }

    const shift_jis_labels = [_][]const u8{ "csshiftjis", "ms932", "ms_kanji", "shift-jis", "shift_jis", "sjis", "windows-31j", "x-sjis" };
    for (shift_jis_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &SHIFT_JIS;
    }

    const euc_jp_labels = [_][]const u8{ "cseucpkdfmtjapanese", "euc-jp", "x-euc-jp" };
    for (euc_jp_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &EUC_JP;
    }

    const iso_2022_jp_labels = [_][]const u8{ "csiso2022jp", "iso-2022-jp" };
    for (iso_2022_jp_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &ISO_2022_JP;
    }

    const x_user_defined_labels = [_][]const u8{"x-user-defined"};
    for (x_user_defined_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &X_USER_DEFINED;
    }

    const big5_labels = [_][]const u8{ "big5", "big5-hkscs", "cn-big5", "csbig5", "x-x-big5" };
    for (big5_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &BIG5;
    }

    const replacement_labels = [_][]const u8{ "csiso2022kr", "hz-gb-2312", "iso-2022-cn", "iso-2022-cn-ext", "iso-2022-kr", "replacement" };
    for (replacement_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &REPLACEMENT;
    }

    const utf16be_labels = [_][]const u8{ "unicodefffe", "utf-16be" };
    for (utf16be_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &UTF_16BE;
    }

    const utf16le_labels = [_][]const u8{ "csunicode", "iso-10646-ucs-2", "ucs-2", "unicode", "unicodefeff", "utf-16", "utf-16le" };
    for (utf16le_labels) |lbl| {
        if (std.ascii.eqlIgnoreCase(trimmed, lbl)) return &UTF_16LE;
    }

    return null;
}

/// get an output encoding - maps encoding to suitable output encoding.
///
/// WHATWG Encoding Standard § 4.3
/// https://encoding.spec.whatwg.org/#get-an-output-encoding
///
/// Steps:
/// 1. If encoding is replacement or UTF-16BE/LE, then return UTF-8
/// 2. Return encoding
///
/// This algorithm is used by URL parsing and HTML form submission.
/// It ensures that replacement and UTF-16 encodings (which have no encoder)
/// are mapped to UTF-8 for output.
pub fn getOutputEncoding(encoding: *const Encoding) *const Encoding {
    // Step 1: Map replacement/UTF-16BE/LE to UTF-8
    if (encoding == &REPLACEMENT or encoding == &UTF_16BE or encoding == &UTF_16LE) {
        return &UTF_8;
    }

    // Step 2: Return encoding unchanged
    return encoding;
}

// Tests

test "decodeToUtf8 fallback - ASCII" {
    // Test that ASCII decodes correctly through the fallback path
    var decoder = WINDOWS_1252.newDecoder();
    const input = "Hello, World!";
    var output: [64]u8 = undefined;

    const result = decoder.decodeToUtf8(input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(input.len, result.bytes_consumed);
    try std.testing.expectEqual(input.len, result.bytes_written);
    try std.testing.expectEqualStrings(input, output[0..result.bytes_written]);
}

test "decodeToUtf8 fallback - non-ASCII single-byte" {
    // Test Windows-1252 with € (0x80 -> U+20AC)
    var decoder = WINDOWS_1252.newDecoder();
    const input = [_]u8{ 0x80, 0x41 }; // € followed by 'A'
    var output: [64]u8 = undefined;

    const result = decoder.decodeToUtf8(&input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    // € is U+20AC which encodes to 3 bytes in UTF-8: E2 82 AC
    // 'A' is 1 byte
    try std.testing.expectEqual(@as(usize, 4), result.bytes_written);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xE2, 0x82, 0xAC, 0x41 }, output[0..result.bytes_written]);
}

test "decodeToUtf8 fallback - output buffer too small" {
    var decoder = WINDOWS_1252.newDecoder();
    const input = "Hello";
    var output: [3]u8 = undefined; // Too small for full output

    const result = decoder.decodeToUtf8(input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.output_full, result.status);
    // Should have written as much as fits
    try std.testing.expect(result.bytes_written <= output.len);
}

test "Encoding.supportsDirectUtf8Decode" {
    // Encodings with native decodeToUtf8 implementation
    try std.testing.expect(EUC_KR.supportsDirectUtf8Decode());
    try std.testing.expect(BIG5.supportsDirectUtf8Decode());
    try std.testing.expect(GB18030.supportsDirectUtf8Decode());

    // Single-byte encodings now support direct UTF-8 decode
    try std.testing.expect(WINDOWS_1252.supportsDirectUtf8Decode());
    try std.testing.expect(ISO_8859_2.supportsDirectUtf8Decode());
    try std.testing.expect(IBM866.supportsDirectUtf8Decode());
    try std.testing.expect(KOI8_R.supportsDirectUtf8Decode());

    // UTF-8 doesn't need native decodeToUtf8 (it's already UTF-8)
    try std.testing.expect(!UTF_8.supportsDirectUtf8Decode());
}

test "decodeToUtf8 direct - GB18030 ASCII passthrough" {
    // ASCII bytes should pass through directly (same as UTF-8)
    var decoder = GB18030.newDecoder();
    const input = "Hello, World!";
    var output: [64]u8 = undefined;

    const result = decoder.decodeToUtf8(input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(input.len, result.bytes_consumed);
    try std.testing.expectEqual(input.len, result.bytes_written);
    try std.testing.expectEqualStrings(input, output[0..result.bytes_written]);
}

test "decodeToUtf8 direct - GB18030 2-byte sequence" {
    // GB18030 2-byte: 0xA1 0xA1 maps to U+3000 (ideographic space)
    // U+3000 in UTF-8 is 0xE3 0x80 0x80
    var decoder = GB18030.newDecoder();
    const input = [_]u8{ 0xA1, 0xA1 };
    var output: [64]u8 = undefined;

    const result = decoder.decodeToUtf8(&input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    // Should produce 3-byte UTF-8 for a CJK character
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
}

test "decodeToUtf8 direct - GB18030 streaming incomplete sequence" {
    // Test that incomplete GB18030 sequence is handled correctly when not is_last
    var decoder = GB18030.newDecoder();
    const input = [_]u8{0xA1}; // First byte only
    var output: [64]u8 = undefined;

    // First chunk with is_last=false - incomplete sequence should wait
    const result1 = decoder.decodeToUtf8(&input, &output, false);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result1.status);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result1.bytes_written);

    // Continue with second byte
    const input2 = [_]u8{0xA1};
    const result2 = decoder.decodeToUtf8(&input2, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result2.status);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result2.bytes_written); // CJK char = 3 UTF-8 bytes
}

test "decodeToUtf8 direct - Big5 ASCII passthrough" {
    // ASCII bytes should pass through directly (same as UTF-8)
    var decoder = BIG5.newDecoder();
    const input = "Hello, World!";
    var output: [64]u8 = undefined;

    const result = decoder.decodeToUtf8(input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(input.len, result.bytes_consumed);
    try std.testing.expectEqual(input.len, result.bytes_written);
    try std.testing.expectEqualStrings(input, output[0..result.bytes_written]);
}

test "decodeToUtf8 direct - Big5 Chinese character" {
    // Big5 encoding for "中" (U+4E2D) is 0xA4 0xA4
    // But actually "中" is 0xA4 0xA4 in Big5 - need to verify
    // Let's use a known Big5 sequence: 0xA4 0x40 maps to U+4E00 (一)
    // Actually, let's test with 0xA4 0x40 -> U+4E00 (first CJK unified ideograph)
    // U+4E00 in UTF-8 is 0xE4 0xB8 0x80
    var decoder = BIG5.newDecoder();
    // Big5: 0xA4 0x40 -> U+4E00 based on Big5 index
    const input = [_]u8{ 0xA4, 0x40 };
    var output: [64]u8 = undefined;

    const result = decoder.decodeToUtf8(&input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    // Should produce 3-byte UTF-8 for a CJK character
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
}

test "decodeToUtf8 direct - Big5 streaming incomplete sequence" {
    // Test that incomplete Big5 sequence is handled correctly when not is_last
    var decoder = BIG5.newDecoder();
    const input = [_]u8{0xA4}; // Lead byte only, no trail byte
    var output: [64]u8 = undefined;

    // First chunk with is_last=false - incomplete sequence should wait
    const result1 = decoder.decodeToUtf8(&input, &output, false);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result1.status);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result1.bytes_written);

    // Continue with trail byte
    const input2 = [_]u8{0x40};
    const result2 = decoder.decodeToUtf8(&input2, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result2.status);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result2.bytes_written); // CJK char = 3 UTF-8 bytes
}

// Tests for maxUtf8LengthForInput

test "maxUtf8LengthForInput - UTF-8 is 1:1" {
    // UTF-8 input produces same size output (already UTF-8)
    try std.testing.expectEqual(@as(usize, 100), UTF_8.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 0), UTF_8.maxUtf8LengthForInput(0));
    try std.testing.expectEqual(@as(usize, 1), UTF_8.maxUtf8LengthForInput(1));
}

test "maxUtf8LengthForInput - single-byte encodings use 3x" {
    // Each byte in single-byte encoding can produce up to 3 UTF-8 bytes
    try std.testing.expectEqual(@as(usize, 300), WINDOWS_1252.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 300), ISO_8859_2.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 300), KOI8_R.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 0), IBM866.maxUtf8LengthForInput(0));
}

test "maxUtf8LengthForInput - East Asian double-byte encodings use 3x" {
    // EUC-KR, Shift_JIS, EUC-JP: worst case is 3x
    try std.testing.expectEqual(@as(usize, 300), EUC_KR.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 300), SHIFT_JIS.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 300), EUC_JP.maxUtf8LengthForInput(100));
}

test "maxUtf8LengthForInput - UTF-16 uses 2x" {
    // UTF-16 has 2x expansion (worst case: all BMP chars)
    try std.testing.expectEqual(@as(usize, 200), UTF_16BE.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 200), UTF_16LE.maxUtf8LengthForInput(100));
}

test "maxUtf8LengthForInput - replacement produces at most 3 bytes" {
    // Replacement encoding only emits U+FFFD once (3 bytes)
    try std.testing.expectEqual(@as(usize, 3), REPLACEMENT.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 3), REPLACEMENT.maxUtf8LengthForInput(1));
    try std.testing.expectEqual(@as(usize, 3), REPLACEMENT.maxUtf8LengthForInput(0));
}

test "maxUtf8LengthForInput - GB18030 uses 3x" {
    // GB18030 uses 3x (covers 4-byte sequences safely)
    try std.testing.expectEqual(@as(usize, 300), GB18030.maxUtf8LengthForInput(100));
    try std.testing.expectEqual(@as(usize, 300), GBK.maxUtf8LengthForInput(100));
}

test "maxUtf8LengthForInput - Big5 uses 3x" {
    try std.testing.expectEqual(@as(usize, 300), BIG5.maxUtf8LengthForInput(100));
}

test "maxUtf8LengthForInput - x-user-defined uses 3x" {
    try std.testing.expectEqual(@as(usize, 300), X_USER_DEFINED.maxUtf8LengthForInput(100));
}

test "maxUtf8LengthForInput - ISO-2022-JP uses 3x" {
    try std.testing.expectEqual(@as(usize, 300), ISO_2022_JP.maxUtf8LengthForInput(100));
}
