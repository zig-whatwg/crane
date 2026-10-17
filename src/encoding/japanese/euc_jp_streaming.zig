//! EUC-JP Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte EUC-JP decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const euc_jp_impl = @import("euc_jp.zig");
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

pub const EucJpDecoderState = struct {
    euc_jp_lead: u8 = 0x00,
    euc_jp_jis0212_flag: bool = false,
};

pub const EucJpEncoderState = struct {
    pending_high_surrogate: ?u16 = null,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .euc_jp or decoder.state == .neutral);
    if (decoder.state == .neutral) {
        decoder.state = .{ .euc_jp = .{ .euc_jp_lead = 0, .euc_jp_jis0212_flag = false } };
    }
    const state = &decoder.state.euc_jp;
    var byte_decoder = euc_jp_impl.Decoder{
        .euc_jp_lead = state.euc_jp_lead,
        .euc_jp_jis0212_flag = state.euc_jp_jis0212_flag,
    };
    defer {
        state.euc_jp_lead = byte_decoder.euc_jp_lead;
        state.euc_jp_jis0212_flag = byte_decoder.euc_jp_jis0212_flag;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    while (in_pos < input.len) {
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        const byte = input[in_pos];
        const before = byte_decoder;
        const point_or_continue = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely);
            // §12.1.1 step 5.7: restore an ASCII trail. The handler's
            // resulting state belongs to it; replacement mode must retain it.
            return .{ .status = .malformed, .bytes_consumed = in_pos, .code_units_written = out_pos, .error_length = if (before.euc_jp_lead != 0 and byte < 0x80) 0 else 1 };
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
    if (is_last and byte_decoder.euc_jp_lead != 0) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        // §12.1.1 step 1: clear the pending lead and report one EOF error.
        _ = byte_decoder.decode(null) catch return .{ .status = .malformed, .bytes_consumed = in_pos, .code_units_written = out_pos, .error_length = 0 };
    }
    return .{ .status = .input_empty, .bytes_consumed = in_pos, .code_units_written = out_pos };
}

pub fn encode(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    std.debug.assert(encoder.state == .euc_jp or encoder.state == .neutral);

    if (encoder.state == .neutral) {
        encoder.state = .{ .euc_jp = .{ .pending_high_surrogate = null } };
    }

    var state = &encoder.state.euc_jp;
    var byte_encoder = euc_jp_impl.Encoder{};

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

        var encoded_len: usize = 1;
        if (encoded.?[1] != 0) encoded_len = 2;
        if (encoded.?[2] != 0) encoded_len = 3;

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
        if (encoded_len >= 2) {
            output[out_pos] = encoded.?[1];
            out_pos += 1;
        }
        if (encoded_len == 3) {
            output[out_pos] = encoded.?[2];
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

        var encoded_len: usize = 1;
        if (encoded.?[1] != 0) encoded_len = 2;
        if (encoded.?[2] != 0) encoded_len = 3;

        if (out_pos + encoded_len <= output.len) {
            output[out_pos] = encoded.?[0];
            out_pos += 1;
            if (encoded_len >= 2) {
                output[out_pos] = encoded.?[1];
                out_pos += 1;
            }
            if (encoded_len == 3) {
                output[out_pos] = encoded.?[2];
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

/// Direct UTF-8 decode for EUC-JP (optimization path).
///
/// Decodes EUC-JP input bytes directly to UTF-8 output without
/// going through a UTF-16 intermediate buffer.
pub fn decodeToUtf8(
    decoder: *Decoder,
    input: []const u8,
    output: []u8,
    is_last: bool,
) streaming.DecodeToUtf8Result {
    std.debug.assert(decoder.state == .euc_jp or decoder.state == .neutral);
    if (decoder.state == .neutral) {
        decoder.state = .{ .euc_jp = .{ .euc_jp_lead = 0, .euc_jp_jis0212_flag = false } };
    }
    const state = &decoder.state.euc_jp;
    var byte_decoder = euc_jp_impl.Decoder{
        .euc_jp_lead = state.euc_jp_lead,
        .euc_jp_jis0212_flag = state.euc_jp_jis0212_flag,
    };
    defer {
        state.euc_jp_lead = byte_decoder.euc_jp_lead;
        state.euc_jp_jis0212_flag = byte_decoder.euc_jp_jis0212_flag;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    while (in_pos < input.len) {
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        const byte = input[in_pos];
        const before = byte_decoder;
        const point_or_continue = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely);
            // §12.1.1 step 5.7: restore an ASCII trail. The handler's
            // resulting state belongs to it; replacement mode must retain it.
            return .{ .status = .malformed, .bytes_consumed = in_pos, .bytes_written = out_pos, .error_length = if (before.euc_jp_lead != 0 and byte < 0x80) 0 else 1 };
        };
        if (point_or_continue) |point| {
            if (writeUtf8CodePoint(output, out_pos, point)) |written| {
                out_pos += written;
            } else {
                byte_decoder = before;
                return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
            }
        }
        in_pos += 1;
    }
    if (is_last and byte_decoder.euc_jp_lead != 0) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        // §12.1.1 step 1: clear the pending lead and report one EOF error.
        _ = byte_decoder.decode(null) catch return .{ .status = .malformed, .bytes_consumed = in_pos, .bytes_written = out_pos, .error_length = 0 };
    }
    return .{ .status = .input_empty, .bytes_consumed = in_pos, .bytes_written = out_pos };
}
