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

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        if (out_pos >= output.len) {
            state.utf16_leading_byte = byte_decoder.utf16_leading_byte;
            state.utf16_leading_surrogate = byte_decoder.utf16_leading_surrogate;
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
                    state.utf16_leading_byte = byte_decoder.utf16_leading_byte;
                    state.utf16_leading_surrogate = byte_decoder.utf16_leading_surrogate;
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

    state.utf16_leading_byte = byte_decoder.utf16_leading_byte;
    state.utf16_leading_surrogate = byte_decoder.utf16_leading_surrogate;

    if (is_last and (state.utf16_leading_byte != null or state.utf16_leading_surrogate != null)) {
        if (out_pos < output.len) {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            state.utf16_leading_byte = null;
            state.utf16_leading_surrogate = null;
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

test "utf-16le streaming decode - BMP character" {
    // U+4E00 (一) = 0x00 0x4E in UTF-16LE
    const input = [_]u8{ 0x00, 0x4E };
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .utf16le = .{
            .utf16_leading_byte = null,
            .utf16_leading_surrogate = null,
        } },
    };

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x4E00), output[0]);
}

test "utf-16le streaming decode - surrogate pair" {
    // U+10000 = D800 DC00 in UTF-16 = 0x00 0xD8 0x00 0xDC in UTF-16LE
    const input = [_]u8{ 0x00, 0xD8, 0x00, 0xDC };
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .utf16le = .{
            .utf16_leading_byte = null,
            .utf16_leading_surrogate = null,
        } },
    };

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0xD800), output[0]);
    try std.testing.expectEqual(@as(u16, 0xDC00), output[1]);
}

test "utf-16le streaming decode - ASCII" {
    // 'A' = U+0041 = 0x41 0x00 in UTF-16LE
    const input = [_]u8{ 0x41, 0x00 };
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .utf16le = .{
            .utf16_leading_byte = null,
            .utf16_leading_surrogate = null,
        } },
    };

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x0041), output[0]);
}
