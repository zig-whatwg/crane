//! UTF-16LE Streaming Decoder
//!
//! WHATWG Encoding Standard - §14.4 UTF-16LE
//! https://encoding.spec.whatwg.org/#utf-16le
//!
//! UTF-16LE is little-endian UTF-16.
//! "utf-16" is a label for UTF-16LE to deal with deployed content.
//! It has NO encoder per WHATWG spec (decode-only).

const std = @import("std");
const streaming = @import("../streaming.zig");
const shared_decoder = @import("shared_decoder.zig");
const Decoder = @import("../encoding.zig").Decoder;

pub const Utf16LeDecoderState = struct {
    utf16_leading_byte: ?u8 = null,
    utf16_leading_surrogate: ?u16 = null,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .utf16le or decoder.state == .neutral);

    if (decoder.state == .neutral) {
        decoder.state = .{ .utf16le = .{
            .utf16_leading_byte = null,
            .utf16_leading_surrogate = null,
        } };
    }

    var state = &decoder.state.utf16le;
    var byte_decoder = shared_decoder.Decoder{
        .utf16_leading_byte = state.utf16_leading_byte,
        .utf16_leading_surrogate = state.utf16_leading_surrogate,
        .is_utf16be_decoder = false, // Little-endian
    };

    // The byte handler owns its state after an error. In particular, an
    // unpaired leading surrogate restores the following code unit (§14.2).
    defer {
        state.utf16_leading_byte = byte_decoder.utf16_leading_byte;
        state.utf16_leading_surrogate = byte_decoder.utf16_leading_surrogate;
    }
    var in_pos: usize = 0;
    var out_pos: usize = 0;
    while (in_pos < input.len) {
        if (out_pos >= output.len) return .{
            .status = .output_full,
            .bytes_consumed = in_pos,
            .code_units_written = out_pos,
        };
        const before = byte_decoder;
        const result = byte_decoder.decode(input[in_pos]) catch {
            const restored = before.utf16_leading_byte != null and before.utf16_leading_surrogate != null;
            // Keep the first byte of the restored code unit in the existing
            // leading-byte slot; the caller replays its second byte.
            if (restored) byte_decoder.utf16_leading_byte = before.utf16_leading_byte;
            return .{
                .status = .malformed,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
                .error_length = if (restored) 0 else 1,
            };
        };
        if (result) |point| {
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
    if (is_last and (byte_decoder.utf16_leading_byte != null or byte_decoder.utf16_leading_surrogate != null)) {
        if (out_pos == output.len) return .{ .status = .output_full, .bytes_consumed = in_pos, .code_units_written = out_pos };
        _ = byte_decoder.decode(null) catch return .{
            .status = .malformed,
            .bytes_consumed = in_pos,
            .code_units_written = out_pos,
            .error_length = 0,
        };
    }
    return .{ .status = .input_empty, .bytes_consumed = in_pos, .code_units_written = out_pos };
}
