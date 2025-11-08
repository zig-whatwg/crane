//! ISO-2022-JP Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte ISO-2022-JP decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const iso_2022_jp_impl = @import("iso_2022_jp.zig");
const Decoder = @import("../encoding.zig").Decoder;
const Encoder = @import("../encoding.zig").Encoder;

pub const Iso2022JpDecoderState = struct {
    state: iso_2022_jp_impl.DecoderState = .ascii,
    output_state: iso_2022_jp_impl.DecoderState = .ascii,
    iso2022jp_lead: u8 = 0x00,
    iso2022jp_output_flag: bool = false,
};

pub const Iso2022JpEncoderState = struct {
    state: iso_2022_jp_impl.EncoderState = .ascii,
    pending_high_surrogate: ?u16 = null,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .iso_2022_jp or decoder.state == .neutral);

    if (decoder.state == .neutral) {
        decoder.state = .{ .iso_2022_jp = .{
            .state = .ascii,
            .output_state = .ascii,
            .iso2022jp_lead = 0x00,
            .iso2022jp_output_flag = false,
        } };
    }

    var state_wrapper = &decoder.state.iso_2022_jp;
    var byte_decoder = iso_2022_jp_impl.Decoder{
        .state = state_wrapper.state,
        .output_state = state_wrapper.output_state,
        .iso2022jp_lead = state_wrapper.iso2022jp_lead,
        .iso2022jp_output_flag = state_wrapper.iso2022jp_output_flag,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        if (out_pos >= output.len) {
            state_wrapper.state = byte_decoder.state;
            state_wrapper.output_state = byte_decoder.output_state;
            state_wrapper.iso2022jp_lead = byte_decoder.iso2022jp_lead;
            state_wrapper.iso2022jp_output_flag = byte_decoder.iso2022jp_output_flag;
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
                    state_wrapper.state = byte_decoder.state;
                    state_wrapper.output_state = byte_decoder.output_state;
                    state_wrapper.iso2022jp_lead = byte_decoder.iso2022jp_lead;
                    state_wrapper.iso2022jp_output_flag = byte_decoder.iso2022jp_output_flag;
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

    state_wrapper.state = byte_decoder.state;
    state_wrapper.output_state = byte_decoder.output_state;
    state_wrapper.iso2022jp_lead = byte_decoder.iso2022jp_lead;
    state_wrapper.iso2022jp_output_flag = byte_decoder.iso2022jp_output_flag;

    if (is_last and byte_decoder.state != .ascii and byte_decoder.state != .roman and byte_decoder.state != .katakana) {
        if (out_pos < output.len) {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            state_wrapper.state = .ascii;
            state_wrapper.output_state = .ascii;
            state_wrapper.iso2022jp_lead = 0x00;
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
    std.debug.assert(encoder.state == .iso_2022_jp or encoder.state == .neutral);

    if (encoder.state == .neutral) {
        encoder.state = .{ .iso_2022_jp = .{
            .state = .ascii,
            .pending_high_surrogate = null,
        } };
    }

    var state_wrapper = &encoder.state.iso_2022_jp;
    var byte_encoder = iso_2022_jp_impl.Encoder{
        .state = state_wrapper.state,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    var buf: [10]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    while (in_pos < input.len) {
        const code_unit = input[in_pos];

        var code_point: u21 = undefined;

        if (state_wrapper.pending_high_surrogate) |high| {
            if (code_unit >= 0xDC00 and code_unit <= 0xDFFF) {
                const high_val: u32 = high - 0xD800;
                const low_val: u32 = code_unit - 0xDC00;
                code_point = @intCast(0x10000 + (high_val << 10) + low_val);
                state_wrapper.pending_high_surrogate = null;
                in_pos += 1;
            } else {
                code_point = 0xFFFD;
                state_wrapper.pending_high_surrogate = null;
            }
        } else if (code_unit >= 0xD800 and code_unit <= 0xDBFF) {
            state_wrapper.pending_high_surrogate = code_unit;
            in_pos += 1;
            continue;
        } else if (code_unit >= 0xDC00 and code_unit <= 0xDFFF) {
            code_point = 0xFFFD;
            in_pos += 1;
        } else {
            code_point = code_unit;
            in_pos += 1;
        }

        fba.reset();
        const encoded = byte_encoder.encode(allocator, code_point) catch |err| {
            if (err == error.Unencodable) {
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

        if (out_pos + encoded.len > output.len) {
            in_pos -= 1;
            if (code_point >= 0x10000) {
                state_wrapper.pending_high_surrogate = input[in_pos - 1];
            }
            state_wrapper.state = byte_encoder.state;
            return .{
                .status = .output_full,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }

        @memcpy(output[out_pos..][0..encoded.len], encoded);
        out_pos += encoded.len;
    }

    state_wrapper.state = byte_encoder.state;

    if (is_last) {
        if (state_wrapper.pending_high_surrogate != null) {
            fba.reset();
            const encoded = byte_encoder.encode(allocator, 0xFFFD) catch {
                return .{
                    .status = .unmappable,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                    .error_code_point = 0xFFFD,
                };
            };

            if (out_pos + encoded.len <= output.len) {
                @memcpy(output[out_pos..][0..encoded.len], encoded);
                out_pos += encoded.len;
                state_wrapper.pending_high_surrogate = null;
            } else {
                return .{
                    .status = .output_full,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }
        }

        if (state_wrapper.state != .ascii) {
            const escape = [_]u8{ 0x1B, 0x28, 0x42 };
            if (out_pos + escape.len <= output.len) {
                @memcpy(output[out_pos..][0..escape.len], &escape);
                out_pos += escape.len;
                state_wrapper.state = .ascii;
            } else {
                return .{
                    .status = .output_full,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }
        }
    }

    return .{
        .status = .input_empty,
        .code_units_consumed = in_pos,
        .bytes_written = out_pos,
    };
}
