//! gb18030 Streaming Decoder/Encoder
//!
//! Wraps the byte-by-byte gb18030 decoder/encoder for the slice-based streaming API.

const std = @import("std");
const streaming = @import("../streaming.zig");
const gb18030_impl = @import("gb18030.zig");
const Decoder = @import("../encoding.zig").Decoder;
const Encoder = @import("../encoding.zig").Encoder;

/// gb18030 decoder state for streaming
pub const Gb18030DecoderState = struct {
    gb18030_first: u8 = 0x00,
    gb18030_second: u8 = 0x00,
    gb18030_third: u8 = 0x00,
    is_gbk: bool = false,
    pending_ascii: ?u8 = null,
};

/// gb18030 encoder state for streaming
pub const Gb18030EncoderState = struct {
    is_gbk: bool = false,
    pending_high_surrogate: ?u16 = null,
};

/// gb18030 streaming decode implementation
///
/// WHATWG spec §10.2.1 - gb18030 decoder
pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .gb18030 or decoder.state == .neutral);
    if (decoder.state == .neutral) {
        decoder.state = .{ .gb18030 = .{
            .gb18030_first = 0,
            .gb18030_second = 0,
            .gb18030_third = 0,
            .is_gbk = false,
        } };
    }
    const state = &decoder.state.gb18030;
    var byte_decoder = gb18030_impl.Decoder{
        .gb18030_first = state.gb18030_first,
        .gb18030_second = state.gb18030_second,
        .gb18030_third = state.gb18030_third,
        .is_gbk = state.is_gbk,
    };
    defer {
        state.gb18030_first = byte_decoder.gb18030_first;
        state.gb18030_second = byte_decoder.gb18030_second;
        state.gb18030_third = byte_decoder.gb18030_third;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    // A failed four-byte sequence restores its ASCII second byte before its
    // third byte (already retained as a lead) and the unread current byte.
    if (state.pending_ascii) |byte| {
        if (output.len == 0) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        output[out_pos] = byte;
        out_pos += 1;
        state.pending_ascii = null;
    }
    while (in_pos < input.len) {
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        const byte = input[in_pos];
        const before = byte_decoder;
        const point_or_continue = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely);
            const error_length = restoreAfterError(&state.pending_ascii, &byte_decoder, before, byte);
            return .{ .status = .malformed, .bytes_consumed = in_pos, .code_units_written = out_pos, .error_length = error_length };
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
    if (is_last and byte_decoder.gb18030_first != 0) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        // §10.2.1 step 2 consumes the entire unfinished sequence at EOF.
        _ = byte_decoder.decode(null) catch return .{ .status = .malformed, .bytes_consumed = in_pos, .code_units_written = out_pos, .error_length = 0 };
    }
    return .{ .status = .input_empty, .bytes_consumed = in_pos, .code_units_written = out_pos };
}

/// Preserve the bytes restored by §10.2.1 without retaining the input slice.
/// The second byte is ASCII; the restored third byte is necessarily a lead.
/// See encoding_rs/src/gb18030.rs: pending_ascii with Pending::One.
fn restoreAfterError(
    pending_ascii: *?u8,
    decoder: *gb18030_impl.Decoder,
    before: gb18030_impl.Decoder,
    byte: u8,
) u8 {
    if (before.gb18030_third != 0) {
        if (byte < 0x30 or byte > 0x39) {
            // Step 3.1: restore second, third, and current byte, in that order.
            pending_ascii.* = before.gb18030_second;
            decoder.gb18030_first = before.gb18030_third;
            return 0;
        }
        // Step 3.4: an unmapped four-byte pointer consumes all four bytes.
        return 1;
    }
    if (before.gb18030_second != 0) {
        // Step 4.2: restore the second and current byte.
        pending_ascii.* = before.gb18030_second;
        return 0;
    }
    // Step 5.9: a malformed two-byte sequence restores only an ASCII trail.
    return if (before.gb18030_first != 0 and byte < 0x80) 0 else 1;
}

/// Encoding §10.1.2: GBK's encoder is gb18030's with its is GBK flag set.
/// Select the mode at the entry point, without relying on Encoding addresses
/// (equal constants can share an address in optimized builds).
pub fn encodeGbk(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    if (encoder.state == .neutral) {
        encoder.state = .{ .gb18030 = .{
            .is_gbk = true,
            .pending_high_surrogate = null,
        } };
    }
    return encode(encoder, input, output, is_last);
}

/// gb18030 streaming encode implementation
///
/// WHATWG spec §10.2.2 - gb18030 encoder
pub fn encode(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    std.debug.assert(encoder.state == .gb18030 or encoder.state == .neutral);

    // Initialize state if needed
    if (encoder.state == .neutral) {
        encoder.state = .{ .gb18030 = .{
            .is_gbk = false,
            .pending_high_surrogate = null,
        } };
    }

    var state = &encoder.state.gb18030;
    const byte_encoder = gb18030_impl.Encoder{ .is_gbk = state.is_gbk };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    // Use a fixed buffer allocator for temporary allocations
    var buf: [4]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    while (in_pos < input.len) {
        const code_unit = input[in_pos];

        // Handle surrogate pairs
        var code_point: u21 = undefined;

        if (state.pending_high_surrogate) |high| {
            // Have pending high surrogate - expect low surrogate
            if (code_unit >= 0xDC00 and code_unit <= 0xDFFF) {
                // Valid surrogate pair
                const high_val: u32 = high - 0xD800;
                const low_val: u32 = code_unit - 0xDC00;
                code_point = @intCast(0x10000 + (high_val << 10) + low_val);
                state.pending_high_surrogate = null;
                in_pos += 1;
            } else {
                // Invalid low surrogate - emit replacement for high
                code_point = 0xFFFD;
                state.pending_high_surrogate = null;
                // Don't advance in_pos - reprocess this code unit
            }
        } else if (code_unit >= 0xD800 and code_unit <= 0xDBFF) {
            // High surrogate - save and continue
            state.pending_high_surrogate = code_unit;
            in_pos += 1;
            continue;
        } else if (code_unit >= 0xDC00 and code_unit <= 0xDFFF) {
            // Unpaired low surrogate - error
            code_point = 0xFFFD;
            in_pos += 1;
        } else {
            // BMP code point
            code_point = code_unit;
            in_pos += 1;
        }

        // Encode the code point
        fba.reset();
        const encoded = byte_encoder.encode(allocator, code_point) catch |err| {
            if (err == error.Unencodable) {
                // Can't encode this code point
                return .{
                    .status = .unmappable,
                    .code_units_consumed = in_pos - 1,
                    .bytes_written = out_pos,
                    .error_code_point = code_point,
                };
            }
            // Other error (OutOfMemory shouldn't happen with fixed buffer)
            return .{
                .status = .unmappable,
                .code_units_consumed = in_pos - 1,
                .bytes_written = out_pos,
                .error_code_point = code_point,
            };
        };

        // Check if we have room in output
        if (out_pos + encoded.len > output.len) {
            // Not enough space - back up
            in_pos -= 1;
            if (code_point >= 0x10000) {
                // Was a surrogate pair - restore high surrogate
                state.pending_high_surrogate = input[in_pos - 1];
            }
            return .{
                .status = .output_full,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }

        // Copy encoded bytes to output
        @memcpy(output[out_pos..][0..encoded.len], encoded);
        out_pos += encoded.len;
    }

    // Check for pending high surrogate at end
    if (is_last and state.pending_high_surrogate != null) {
        // Unpaired high surrogate at end - emit replacement
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

/// Direct UTF-8 decode for GB18030 - optimization path
///
/// WHATWG Encoding Standard § 10.2.1
/// https://encoding.spec.whatwg.org/#gb18030
///
/// This function outputs UTF-8 directly, eliminating the UTF-16 intermediate buffer.
/// Handles both 2-byte index-based and 4-byte range-based decoding.
pub fn decodeToUtf8(
    decoder: *Decoder,
    input: []const u8,
    output: []u8,
    is_last: bool,
) streaming.DecodeToUtf8Result {
    std.debug.assert(decoder.state == .gb18030 or decoder.state == .neutral);
    if (decoder.state == .neutral) {
        decoder.state = .{ .gb18030 = .{
            .gb18030_first = 0,
            .gb18030_second = 0,
            .gb18030_third = 0,
            .is_gbk = false,
        } };
    }
    const state = &decoder.state.gb18030;
    var byte_decoder = gb18030_impl.Decoder{
        .gb18030_first = state.gb18030_first,
        .gb18030_second = state.gb18030_second,
        .gb18030_third = state.gb18030_third,
        .is_gbk = state.is_gbk,
    };
    defer {
        state.gb18030_first = byte_decoder.gb18030_first;
        state.gb18030_second = byte_decoder.gb18030_second;
        state.gb18030_third = byte_decoder.gb18030_third;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    // A failed four-byte sequence restores its ASCII second byte before its
    // third byte (already retained as a lead) and the unread current byte.
    if (state.pending_ascii) |byte| {
        if (output.len == 0) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        output[out_pos] = byte;
        out_pos += 1;
        state.pending_ascii = null;
    }
    while (in_pos < input.len) {
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        const byte = input[in_pos];
        const before = byte_decoder;
        const point_or_continue = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely);
            const error_length = restoreAfterError(&state.pending_ascii, &byte_decoder, before, byte);
            return .{ .status = .malformed, .bytes_consumed = in_pos, .bytes_written = out_pos, .error_length = error_length };
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
    if (is_last and byte_decoder.gb18030_first != 0) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .bytes_written = out_pos };
        // §10.2.1 step 2 consumes the entire unfinished sequence at EOF.
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

// Tests
