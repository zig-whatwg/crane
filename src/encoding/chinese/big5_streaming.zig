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
        decoder.state = .{ .big5 = .{ .big5_lead = 0x00, .pending_code_point = null } };
    }

    var state = &decoder.state.big5;
    var byte_decoder = big5_impl.Decoder{
        .big5_lead = state.big5_lead,
        .pending_code_point = state.pending_code_point,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len or byte_decoder.pending_code_point != null) {
        // Prefetch next cache line for large buffers (only when processing input)
        if (in_pos < input.len and in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }

        if (out_pos >= output.len) {
            state.big5_lead = byte_decoder.big5_lead;
            state.pending_code_point = byte_decoder.pending_code_point;
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }

        // If we have a pending code point, emit it without consuming input
        if (byte_decoder.pending_code_point != null) {
            const result = byte_decoder.decode(null) catch {
                @branchHint(.unlikely); // Decode errors are rare in valid Big5
                output[out_pos] = 0xFFFD;
                out_pos += 1;
                continue;
            };

            if (result) |code_point| {
                if (code_point <= 0xFFFF) {
                    output[out_pos] = @intCast(code_point);
                    out_pos += 1;
                } else {
                    if (out_pos + 1 >= output.len) {
                        state.big5_lead = byte_decoder.big5_lead;
                        state.pending_code_point = byte_decoder.pending_code_point;
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
            continue;
        }

        // Break if no more input
        if (in_pos >= input.len) break;

        const byte = input[in_pos];

        const result = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely); // Decode errors are rare in valid Big5
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            in_pos += 1;

            byte_decoder.big5_lead = 0x00;
            byte_decoder.pending_code_point = null;
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
                    state.big5_lead = byte_decoder.big5_lead;
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

    state.big5_lead = byte_decoder.big5_lead;
    state.pending_code_point = byte_decoder.pending_code_point;

    if (is_last and state.big5_lead != 0x00) {
        @branchHint(.unlikely); // Incomplete sequences at EOF are rare
        if (out_pos < output.len) {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            state.big5_lead = 0x00;
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
    std.debug.assert(encoder.state == .big5 or encoder.state == .neutral);

    if (encoder.state == .neutral) {
        encoder.state = .{ .big5 = .{ .pending_high_surrogate = null } };
    }

    var state = &encoder.state.big5;
    var byte_encoder = big5_impl.Encoder{};

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







