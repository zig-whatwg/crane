//! replacement Streaming Decoder
//!
//! Wraps the byte-by-byte replacement decoder for the slice-based streaming API.
//!
//! NOTE: replacement has NO encoder per WHATWG spec.

const std = @import("std");
const streaming = @import("../streaming.zig");
const replacement_impl = @import("replacement.zig");
const Decoder = @import("../encoding.zig").Decoder;

pub const ReplacementDecoderState = struct {
    replacement_error_returned: bool = false,
};

pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    _ = is_last;
    std.debug.assert(decoder.state == .replacement or decoder.state == .neutral);

    if (decoder.state == .neutral) {
        decoder.state = .{ .replacement = .{ .replacement_error_returned = false } };
    }

    var state = &decoder.state.replacement;
    var byte_decoder = replacement_impl.Decoder{
        .replacement_error_returned = state.replacement_error_returned,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        if (out_pos >= output.len) {
            state.replacement_error_returned = byte_decoder.replacement_error_returned;
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }

        const byte = input[in_pos];

        const result = byte_decoder.decode(byte) catch {
            // The replacement encoding returns error once, then replaces with U+FFFD
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            in_pos += 1;

            state.replacement_error_returned = byte_decoder.replacement_error_returned;
            continue;
        };

        in_pos += 1;

        // After the first error, decode() returns null (finished) for all subsequent bytes
        if (result == null) {
            // Just consume the byte and continue
            continue;
        }
    }

    state.replacement_error_returned = byte_decoder.replacement_error_returned;

    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .code_units_written = out_pos,
    };
}

test "replacement streaming decode - single byte" {
    const input = "A";
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .replacement = .{ .replacement_error_returned = false } },
    };

    const result = decode(&decoder, input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0xFFFD), output[0]); // Replacement character
}

test "replacement streaming decode - multiple bytes" {
    const input = "Hello, World!";
    var output: [50]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .replacement = .{ .replacement_error_returned = false } },
    };

    const result = decode(&decoder, input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 13), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written); // Only one U+FFFD!
    try std.testing.expectEqual(@as(u16, 0xFFFD), output[0]);
}

test "replacement streaming decode - empty input" {
    const input = "";
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .replacement = .{ .replacement_error_returned = false } },
    };

    const result = decode(&decoder, input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.code_units_written);
}
