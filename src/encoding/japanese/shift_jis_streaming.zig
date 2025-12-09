//! Shift_JIS Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte Shift_JIS decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const shift_jis_impl = @import("shift_jis.zig");
const Decoder = @import("../encoding.zig").Decoder;
const Encoder = @import("../encoding.zig").Encoder;

/// Helper to write a Unicode code point as UTF-8 bytes.
/// Returns the number of bytes written (1-4), or null if output buffer is too small.
fn writeUtf8CodePoint(output: []u8, out_pos: usize, code_point: u21) ?usize {
    if (code_point < 0x80) {
        // 1-byte sequence (ASCII)
        if (out_pos >= output.len) return null;
        output[out_pos] = @intCast(code_point);
        return 1;
    } else if (code_point < 0x800) {
        // 2-byte sequence
        if (out_pos + 1 >= output.len) return null;
        output[out_pos] = @intCast(0xC0 | (code_point >> 6));
        output[out_pos + 1] = @intCast(0x80 | (code_point & 0x3F));
        return 2;
    } else if (code_point < 0x10000) {
        // 3-byte sequence
        if (out_pos + 2 >= output.len) return null;
        output[out_pos] = @intCast(0xE0 | (code_point >> 12));
        output[out_pos + 1] = @intCast(0x80 | ((code_point >> 6) & 0x3F));
        output[out_pos + 2] = @intCast(0x80 | (code_point & 0x3F));
        return 3;
    } else {
        // 4-byte sequence (supplementary characters)
        if (out_pos + 3 >= output.len) return null;
        output[out_pos] = @intCast(0xF0 | (code_point >> 18));
        output[out_pos + 1] = @intCast(0x80 | ((code_point >> 12) & 0x3F));
        output[out_pos + 2] = @intCast(0x80 | ((code_point >> 6) & 0x3F));
        output[out_pos + 3] = @intCast(0x80 | (code_point & 0x3F));
        return 4;
    }
}

pub const ShiftJisDecoderState = struct {
    shift_jis_lead: u8 = 0x00,
};

pub const ShiftJisEncoderState = struct {
    pending_high_surrogate: ?u16 = null,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .shift_jis or decoder.state == .neutral);

    if (decoder.state == .neutral) {
        decoder.state = .{ .shift_jis = .{ .shift_jis_lead = 0x00 } };
    }

    var state = &decoder.state.shift_jis;
    var byte_decoder = shift_jis_impl.Decoder{
        .shift_jis_lead = state.shift_jis_lead,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        // Prefetch next cache line for large buffers (64-byte cache lines)
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }

        if (out_pos >= output.len) {
            state.shift_jis_lead = byte_decoder.shift_jis_lead;
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }

        const byte = input[in_pos];

        const result = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely); // Decode errors are rare in valid Shift_JIS
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            in_pos += 1;

            byte_decoder.shift_jis_lead = 0x00;
            continue;
        };

        in_pos += 1;

        if (result) |code_point| {
            if (code_point <= 0xFFFF) {
                output[out_pos] = @intCast(code_point);
                out_pos += 1;
            } else {
                if (out_pos + 1 >= output.len) {
                    in_pos -= 1;
                    state.shift_jis_lead = byte_decoder.shift_jis_lead;
                    return .{
                        .status = .output_full,
                        .bytes_consumed = in_pos,
                        .code_units_written = out_pos,
                    };
                }

                const adjusted = code_point - 0x10000;
                const high: u16 = @intCast(0xD800 + (adjusted >> 10));
                const low: u16 = @intCast(0xDC00 + (adjusted & 0x3FF));
                output[out_pos] = high;
                output[out_pos + 1] = low;
                out_pos += 2;
            }
        }
    }

    state.shift_jis_lead = byte_decoder.shift_jis_lead;

    if (is_last and state.shift_jis_lead != 0x00) {
        @branchHint(.unlikely); // Incomplete sequences at EOF are rare
        if (out_pos < output.len) {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            state.shift_jis_lead = 0x00;
        } else {
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }
    }

    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .code_units_written = out_pos,
    };
}

pub fn encode(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    std.debug.assert(encoder.state == .shift_jis or encoder.state == .neutral);

    if (encoder.state == .neutral) {
        encoder.state = .{ .shift_jis = .{ .pending_high_surrogate = null } };
    }

    var state = &encoder.state.shift_jis;
    var byte_encoder = shift_jis_impl.Encoder{};

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        const code_unit = input[in_pos];

        var code_point: u21 = undefined;

        if (state.pending_high_surrogate) |high| {
            if (code_unit >= 0xDC00 and code_unit <= 0xDFFF) {
                const high_val: u32 = high - 0xD800;
                const low_val: u32 = code_unit - 0xDC00;
                code_point = @intCast(0x10000 + (high_val << 10) + low_val);
                state.pending_high_surrogate = null;
                in_pos += 1;
            } else {
                code_point = 0xFFFD;
                state.pending_high_surrogate = null;
            }
        } else if (code_unit >= 0xD800 and code_unit <= 0xDBFF) {
            state.pending_high_surrogate = code_unit;
            in_pos += 1;
            continue;
        } else if (code_unit >= 0xDC00 and code_unit <= 0xDFFF) {
            code_point = 0xFFFD;
            in_pos += 1;
        } else {
            code_point = code_unit;
            in_pos += 1;
        }

        const encoded = byte_encoder.encode(code_point) catch |err| {
            if (err == error.InvalidCodePoint) {
                return .{
                    .status = .unmappable,
                    .code_units_consumed = in_pos - 1,
                    .bytes_written = out_pos,
                    .error_code_point = code_point,
                };
            }
            return .{
                .status = .unmappable,
                .code_units_consumed = in_pos - 1,
                .bytes_written = out_pos,
                .error_code_point = code_point,
            };
        };

        const encoded_len: usize = if (encoded.?[1] == 0) 1 else 2;

        if (out_pos + encoded_len > output.len) {
            in_pos -= 1;
            if (code_point >= 0x10000) {
                state.pending_high_surrogate = input[in_pos - 1];
            }
            return .{
                .status = .output_full,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }

        output[out_pos] = encoded.?[0];
        out_pos += 1;
        if (encoded_len == 2) {
            output[out_pos] = encoded.?[1];
            out_pos += 1;
        }
    }

    if (is_last and state.pending_high_surrogate != null) {
        const encoded = byte_encoder.encode(0xFFFD) catch {
            return .{
                .status = .unmappable,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
                .error_code_point = 0xFFFD,
            };
        };

        const encoded_len: usize = if (encoded.?[1] == 0) 1 else 2;
        if (out_pos + encoded_len <= output.len) {
            output[out_pos] = encoded.?[0];
            out_pos += 1;
            if (encoded_len == 2) {
                output[out_pos] = encoded.?[1];
                out_pos += 1;
            }
            state.pending_high_surrogate = null;
        } else {
            return .{
                .status = .output_full,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }
    }

    return .{
        .status = .input_empty,
        .code_units_consumed = in_pos,
        .bytes_written = out_pos,
    };
}

/// Direct UTF-8 decode for Shift_JIS (optimization path).
///
/// Decodes Shift_JIS input bytes directly to UTF-8 output without
/// going through a UTF-16 intermediate buffer.
pub fn decodeToUtf8(
    decoder: *Decoder,
    input: []const u8,
    output: []u8,
    is_last: bool,
) streaming.DecodeToUtf8Result {
    std.debug.assert(decoder.state == .shift_jis or decoder.state == .neutral);

    if (decoder.state == .neutral) {
        decoder.state = .{ .shift_jis = .{ .shift_jis_lead = 0x00 } };
    }

    var state = &decoder.state.shift_jis;
    var byte_decoder = shift_jis_impl.Decoder{
        .shift_jis_lead = state.shift_jis_lead,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        // Prefetch next cache line for large buffers (64-byte cache lines)
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }

        const byte = input[in_pos];

        const result = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely); // Decode errors are rare in valid Shift_JIS
            // Write replacement character (U+FFFD = 0xEF 0xBF 0xBD in UTF-8)
            if (out_pos + 2 >= output.len) {
                state.shift_jis_lead = byte_decoder.shift_jis_lead;
                return .{
                    .status = .output_full,
                    .bytes_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }
            output[out_pos] = 0xEF;
            output[out_pos + 1] = 0xBF;
            output[out_pos + 2] = 0xBD;
            out_pos += 3;
            in_pos += 1;
            byte_decoder.shift_jis_lead = 0x00;
            continue;
        };

        in_pos += 1;

        if (result) |code_point| {
            if (writeUtf8CodePoint(output, out_pos, code_point)) |bytes_written| {
                out_pos += bytes_written;
            } else {
                // Output buffer full - back up
                in_pos -= 1;
                state.shift_jis_lead = byte_decoder.shift_jis_lead;
                return .{
                    .status = .output_full,
                    .bytes_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }
        }
    }

    state.shift_jis_lead = byte_decoder.shift_jis_lead;

    if (is_last and state.shift_jis_lead != 0x00) {
        @branchHint(.unlikely); // Incomplete sequences at EOF are rare
        // Write replacement character for incomplete sequence
        if (out_pos + 2 < output.len) {
            output[out_pos] = 0xEF;
            output[out_pos + 1] = 0xBF;
            output[out_pos + 2] = 0xBD;
            out_pos += 3;
            state.shift_jis_lead = 0x00;
        } else {
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }
    }

    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .bytes_written = out_pos,
    };
}
