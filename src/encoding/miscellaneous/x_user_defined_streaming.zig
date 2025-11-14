//! x-user-defined Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte x-user-defined decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const x_user_defined_impl = @import("x_user_defined.zig");
const Decoder = @import("../encoding.zig").Decoder;
const Encoder = @import("../encoding.zig").Encoder;

pub const XUserDefinedDecoderState = struct {};

pub const XUserDefinedEncoderState = struct {
    pending_high_surrogate: ?u16 = null,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    _ = is_last;
    std.debug.assert(decoder.state == .x_user_defined or decoder.state == .neutral);

    if (decoder.state == .neutral) {
        decoder.state = .{ .x_user_defined = .{} };
    }

    var byte_decoder = x_user_defined_impl.Decoder{};

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        if (out_pos >= output.len) {
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }

        const byte = input[in_pos];

        const result = byte_decoder.decode(byte) catch {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            in_pos += 1;
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
    std.debug.assert(encoder.state == .x_user_defined or encoder.state == .neutral);

    if (encoder.state == .neutral) {
        encoder.state = .{ .x_user_defined = .{ .pending_high_surrogate = null } };
    }

    var state = &encoder.state.x_user_defined;
    var byte_encoder = x_user_defined_impl.Encoder{};

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

        if (out_pos + 1 > output.len) {
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

        if (out_pos + 1 <= output.len) {
            output[out_pos] = encoded.?[0];
            out_pos += 1;
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




