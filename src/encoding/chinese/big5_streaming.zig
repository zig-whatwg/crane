//! Big5 Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte Big5 decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const big5_impl = @import("big5.zig");
const Decoder = @import("../encoding.zig").Decoder;
const Encoder = @import("../encoding.zig").Encoder;

pub const Big5DecoderState = struct {
    big5_lead: u8 = 0x00,
    pending_code_point: ?u21 = null,
};

pub const Big5EncoderState = struct {
    pending_high_surrogate: ?u16 = null,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .big5 or decoder.state == .neutral);
    if (decoder.state == .neutral) {
        decoder.state = .{ .big5 = .{ .big5_lead = 0, .pending_code_point = null } };
    }
    const state = &decoder.state.big5;
    var byte_decoder = big5_impl.Decoder{
        .big5_lead = state.big5_lead,
        .pending_code_point = state.pending_code_point,
    };
    defer {
        state.big5_lead = byte_decoder.big5_lead;
        state.pending_code_point = byte_decoder.pending_code_point;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    while (in_pos < input.len or byte_decoder.pending_code_point != null) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        // §11.1.1 step 3.6: the second scalar precedes the next input item,
        // including EOF. Keep it pending until its entire output fits.
        if (byte_decoder.pending_code_point) |point| {
            output[out_pos] = @intCast(point);
            out_pos += 1;
            byte_decoder.pending_code_point = null;
            continue;
        }
        const byte = input[in_pos];
        const before = byte_decoder;
        const point_or_continue = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely);
            // §11.1.1 step 3.9 restores an ASCII trail, even when the pair's
            // pointer exists but is unmapped. The handler cleared its lead.
            return .{ .status = .malformed, .bytes_consumed = in_pos, .code_units_written = out_pos, .error_length = if (before.big5_lead != 0 and byte < 0x80) 0 else 1 };
        };
        if (point_or_continue) |point| {
            if (point <= 0xffff) {
                output[out_pos] = @intCast(point);
                out_pos += 1;
            } else {
                if (output.len - out_pos < 2) {
                    byte_decoder = before;
                    return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
                }
                const adjusted = point - 0x10000;
                output[out_pos] = @intCast(0xd800 + (adjusted >> 10));
                output[out_pos + 1] = @intCast(0xdc00 + (adjusted & 0x3ff));
                out_pos += 2;
            }
        }
        in_pos += 1;
    }
    if (is_last and byte_decoder.big5_lead != 0) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        // §11.1.1 step 1: clear the pending lead and report one EOF error.
        _ = byte_decoder.decode(null) catch return .{ .status = .malformed, .bytes_consumed = in_pos, .code_units_written = out_pos, .error_length = 0 };
    }
    return .{ .status = .input_empty, .bytes_consumed = in_pos, .code_units_written = out_pos };
}

/// Direct UTF-8 decode for Big5 - optimization path
///
/// WHATWG Encoding Standard § 11.1
/// https://encoding.spec.whatwg.org/#big5
///
/// This function outputs UTF-8 directly, eliminating the UTF-16 intermediate buffer.
/// Handles special HKSCS multi-code-point mappings (pointers 1133, 1135, 1164, 1166).
pub fn decodeToUtf8(
    decoder: *Decoder,
    input: []const u8,
    output: []u8,
    is_last: bool,
) streaming.DecodeToUtf8Result {
    std.debug.assert(decoder.state == .big5 or decoder.state == .neutral);
    if (decoder.state == .neutral) {
        decoder.state = .{ .big5 = .{ .big5_lead = 0, .pending_code_point = null } };
    }
    const state = &decoder.state.big5;
    var byte_decoder = big5_impl.Decoder{
        .big5_lead = state.big5_lead,
        .pending_code_point = state.pending_code_point,
    };
    defer {
        state.big5_lead = byte_decoder.big5_lead;
        state.pending_code_point = byte_decoder.pending_code_point;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    while (in_pos < input.len or byte_decoder.pending_code_point != null) {
        // §11.1.1 step 3.6: the second scalar precedes the next input item,
        // including EOF. Keep it pending until its entire output fits.
        if (byte_decoder.pending_code_point) |point| {
            const written = writeUtf8CodePoint(point, output[out_pos..]);
            if (written == 0) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
            out_pos += written;
            byte_decoder.pending_code_point = null;
            continue;
        }
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        const byte = input[in_pos];
        const before = byte_decoder;
        const point_or_continue = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely);
            // §11.1.1 step 3.9 restores an ASCII trail, even when the pair's
            // pointer exists but is unmapped. The handler cleared its lead.
            return .{ .status = .malformed, .bytes_consumed = in_pos, .bytes_written = out_pos, .error_length = if (before.big5_lead != 0 and byte < 0x80) 0 else 1 };
        };
        if (point_or_continue) |point| {
            const written = writeUtf8CodePoint(point, output[out_pos..]);
            if (written == 0) {
                byte_decoder = before;
                return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
            }
            out_pos += written;
        }
        in_pos += 1;
    }
    if (is_last and byte_decoder.big5_lead != 0) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        // §11.1.1 step 1: clear the pending lead and report one EOF error.
        _ = byte_decoder.decode(null) catch return .{ .status = .malformed, .bytes_consumed = in_pos, .bytes_written = out_pos, .error_length = 0 };
    }
    return .{ .status = .input_empty, .bytes_consumed = in_pos, .bytes_written = out_pos };
}

/// Write a code point as UTF-8. Returns number of bytes written (0 if buffer too small).
fn writeUtf8CodePoint(code_point: u21, output: []u8) usize {
    if (code_point < 0x80) {
        if (output.len < 1) return 0;
        output[0] = @intCast(code_point);
        return 1;
    } else if (code_point < 0x800) {
        if (output.len < 2) return 0;
        output[0] = @intCast(0xC0 | (code_point >> 6));
        output[1] = @intCast(0x80 | (code_point & 0x3F));
        return 2;
    } else if (code_point < 0x10000) {
        if (output.len < 3) return 0;
        output[0] = @intCast(0xE0 | (code_point >> 12));
        output[1] = @intCast(0x80 | ((code_point >> 6) & 0x3F));
        output[2] = @intCast(0x80 | (code_point & 0x3F));
        return 3;
    } else {
        if (output.len < 4) return 0;
        output[0] = @intCast(0xF0 | (code_point >> 18));
        output[1] = @intCast(0x80 | ((code_point >> 12) & 0x3F));
        output[2] = @intCast(0x80 | ((code_point >> 6) & 0x3F));
        output[3] = @intCast(0x80 | (code_point & 0x3F));
        return 4;
    }
}

pub fn encode(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    std.debug.assert(encoder.state == .big5 or encoder.state == .neutral);

    if (encoder.state == .neutral) {
        encoder.state = .{ .big5 = .{ .pending_high_surrogate = null } };
    }

    var state = &encoder.state.big5;
    var byte_encoder = big5_impl.Encoder{};

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        // A scalar may start in the previous call. Retry from this call's
        // cursor and carried high surrogate, never by indexing before input.
        const input_before = in_pos;
        const pending_before = state.pending_high_surrogate;
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
                    .code_units_consumed = input_before,
                    .bytes_written = out_pos,
                    .error_code_point = code_point,
                };
            }
            return .{
                .status = .unmappable,
                .code_units_consumed = input_before,
                .bytes_written = out_pos,
                .error_code_point = code_point,
            };
        };

        const encoded_len: usize = if (encoded.?[1] == 0) 1 else 2;

        if (out_pos + encoded_len > output.len) {
            state.pending_high_surrogate = pending_before;
            return .{
                .status = .output_full,
                .code_units_consumed = input_before,
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
            // The final surrogate error consumes its pending input once.
            state.pending_high_surrogate = null;
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
