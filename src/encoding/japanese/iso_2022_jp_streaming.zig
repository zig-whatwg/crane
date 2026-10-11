//! ISO-2022-JP Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte ISO-2022-JP decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const iso_2022_jp_impl = @import("iso_2022_jp.zig");
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

pub const Iso2022JpDecoderState = struct {
    prepended_bytes: [2]u8 = .{ 0, 0 },
    prepended_len: u2 = 0,
    state: iso_2022_jp_impl.DecoderState = .ascii,
    output_state: iso_2022_jp_impl.DecoderState = .ascii,
    iso2022jp_lead: u8 = 0x00,
    iso2022jp_output_flag: bool = false,
};

pub const Iso2022JpEncoderState = struct {
    state: iso_2022_jp_impl.EncoderState = .ascii,
    pending_high_surrogate: ?u16 = null,
};

pub fn decode(decoder: *Decoder, input: []const u8, output: []u16, is_last: bool) streaming.DecodeResult {
    return decodeUnits(u16, decoder, input, output, is_last);
}

fn decodeUnits(comptime Unit: type, decoder: *Decoder, input: []const u8, output: []Unit, is_last: bool) if (Unit == u16) streaming.DecodeResult else streaming.DecodeToUtf8Result {
    std.debug.assert(decoder.state == .iso_2022_jp or decoder.state == .neutral);
    if (decoder.state == .neutral) decoder.state = .{ .iso_2022_jp = .{
        .state = .ascii,
        .output_state = .ascii,
        .iso2022jp_lead = 0,
        .iso2022jp_output_flag = false,
    } };
    const state = &decoder.state.iso_2022_jp;
    var byte_decoder: iso_2022_jp_impl.Decoder = .{
        .state = state.state,
        .output_state = state.output_state,
        .iso2022jp_lead = state.iso2022jp_lead,
        .iso2022jp_output_flag = state.iso2022jp_output_flag,
        .prepended_bytes = state.prepended_bytes,
        .prepended_len = state.prepended_len,
    };
    defer {
        state.state = byte_decoder.state;
        state.output_state = byte_decoder.output_state;
        state.iso2022jp_lead = byte_decoder.iso2022jp_lead;
        state.iso2022jp_output_flag = byte_decoder.iso2022jp_output_flag;
        state.prepended_bytes = byte_decoder.prepended_bytes;
        state.prepended_len = byte_decoder.prepended_len;
    }
    const Result = if (Unit == u16) streaming.DecodeResult else streaming.DecodeToUtf8Result;
    var result: Result = if (Unit == u16)
        .{ .status = .input_empty, .bytes_consumed = 0, .code_units_written = 0 }
    else
        .{ .status = .input_empty, .bytes_consumed = 0, .bytes_written = 0 };
    const written = &@field(result, if (Unit == u16) "code_units_written" else "bytes_written");
    var checkpoint: iso_2022_jp_impl.Decoder = undefined;
    while (true) {
        if (byte_decoder.prepended_len == 0 and result.bytes_consumed == input.len and !is_last) return result;
        if (written.* == output.len) {
            result.status = .output_full;
            return result;
        }
        // Every ISO-2022-JP scalar is in the BMP: three free UTF-8 bytes
        // suffice. Save the replay queue and state only when output can fail.
        const can_fill_output = Unit == u8 and output.len - written.* < 3;
        if (can_fill_output) checkpoint = byte_decoder;
        const input_before = result.bytes_consumed;
        const byte: ?u8 = if (byte_decoder.takePrepended()) |restored| restored else if (result.bytes_consumed < input.len) blk: {
            const b = input[result.bytes_consumed];
            result.bytes_consumed += 1;
            break :blk b;
        } else null;
        const point = byte_decoder.decode(byte) catch {
            // The handler has consumed this item; any restored bytes are in
            // its two-byte queue. There are no external bytes to skip.
            result.status = .malformed;
            return result;
        };
        if (point) |value| {
            if (Unit == u16) {
                // ASCII/Roman/katakana and every jis0208 entry are in the BMP.
                output[written.*] = @intCast(value);
                written.* += 1;
            } else {
                const count = writeUtf8CodePoint(output, written.*, value) orelse {
                    // Restore both the input cursor and the prepended queue.
                    std.debug.assert(can_fill_output);
                    byte_decoder = checkpoint;
                    result.bytes_consumed = input_before;
                    result.status = .output_full;
                    return result;
                };
                written.* += count;
            }
        }
        if (byte == null) return result;
    }
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
        const input_before = in_pos;
        const pending_before = state_wrapper.pending_high_surrogate;
        const encoder_before = byte_encoder.state;
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
        const state_before = byte_encoder.state;
        const encoded = byte_encoder.encode(allocator, code_point) catch {
            // Steps 6 and 11.1: in JIS X 0208 state the handler returns to
            // ASCII - emitting ESC ( B - before the code point errors, so
            // whatever the caller writes for the error is read as ASCII.
            if (state_before == .jis0208) {
                const escape = [_]u8{ 0x1B, 0x28, 0x42 };
                if (out_pos + escape.len > output.len) {
                    state_wrapper.pending_high_surrogate = pending_before;
                    state_wrapper.state = encoder_before;
                    return .{
                        .status = .output_full,
                        .code_units_consumed = input_before,
                        .bytes_written = out_pos,
                    };
                }
                @memcpy(output[out_pos..][0..escape.len], &escape);
                out_pos += escape.len;
                byte_encoder.state = .ascii;
            }
            // The state this call reached is the encoder's from here on.
            state_wrapper.state = byte_encoder.state;
            return .{
                .status = .unmappable,
                .code_units_consumed = in_pos - 1,
                .bytes_written = out_pos,
                // Step 3 reports U+000E, U+000F and U+001B as U+FFFD, so an
                // escape sequence cannot be smuggled through as a reference.
                .error_code_point = if (code_point == 0x0E or code_point == 0x0F or code_point == 0x1B) 0xFFFD else code_point,
            };
        };

        if (out_pos + encoded.len > output.len) {
            // A designation changes state only when its bytes fit. Restore
            // the input item too, including a carried leading surrogate.
            state_wrapper.pending_high_surrogate = pending_before;
            state_wrapper.state = encoder_before;
            return .{
                .status = .output_full,
                .code_units_consumed = input_before,
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

/// Direct UTF-8 decode for ISO-2022-JP (optimization path).
///
/// Decodes ISO-2022-JP input bytes directly to UTF-8 output without
/// going through a UTF-16 intermediate buffer. This encoding uses escape
/// sequences to switch between character sets, making it stateful.
pub fn decodeToUtf8(decoder: *Decoder, input: []const u8, output: []u8, is_last: bool) streaming.DecodeToUtf8Result {
    return decodeUnits(u8, decoder, input, output, is_last);
}
