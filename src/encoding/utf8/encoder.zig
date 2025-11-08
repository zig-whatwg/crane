//! UTF-8 Encoder
//!
//! Spec: https://encoding.spec.whatwg.org/#utf-8-encoder
//!
//! Converts UTF-16 code units to UTF-8 bytes with:
//! - ASCII fast path
//! - Surrogate pair handling
//! - Validation (surrogates must be paired)

const std = @import("std");
const webidl = @import("webidl");
const streaming = @import("../streaming.zig");
const ascii = @import("ascii.zig");
const Encoder = @import("../encoding.zig").Encoder;

// Use webidl.code_points for surrogate pair handling
const code_points = webidl.code_points;

/// UTF-8 encoder state
pub const Utf8EncoderState = struct {
    /// Pending high surrogate (if we're expecting a low surrogate)
    pending_high_surrogate: ?u16 = null,
};

/// UTF-8 encode implementation
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-encoder
pub fn encode(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    std.debug.assert(encoder.state == .neutral);

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    // Fast path: Process ASCII prefix
    const ascii_len = ascii.countAsciiPrefixUtf16(input);
    if (ascii_len > 0) {
        const to_copy = @min(ascii_len, output.len);
        const copied = ascii.copyUtf16ToAscii(input[0..to_copy], output);
        in_pos = copied;
        out_pos = copied;

        if (copied < ascii_len) {
            // Output buffer full
            return .{
                .status = .output_full,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }
    }

    // Slow path: Process non-ASCII code units
    while (in_pos < input.len) {
        // Prefetch next cache line for large buffers
        if (in_pos + 32 < input.len) {
            @prefetch(&input[in_pos + 32], .{ .rw = .read, .locality = 3 });
        }

        const code_unit = input[in_pos];

        // ASCII (0x0000-0x007F) - 1 byte
        if (code_unit < 0x80) {
            if (out_pos >= output.len) {
                return .{
                    .status = .output_full,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }

            output[out_pos] = @intCast(code_unit);
            out_pos += 1;
            in_pos += 1;
            continue;
        }

        // Branchless check for high surrogate: 0xD800-0xDBFF
        // Top 6 bits should be 110110
        const is_high_surrogate = (code_unit & 0xFC00) == 0xD800;

        // High surrogate (0xD800-0xDBFF)
        if (is_high_surrogate) {
            // Check if we have next code unit
            if (in_pos + 1 >= input.len) {
                if (is_last) {
                    // Unpaired high surrogate at EOF - emit replacement
                    if (out_pos + 3 > output.len) {
                        return .{
                            .status = .output_full,
                            .code_units_consumed = in_pos,
                            .bytes_written = out_pos,
                        };
                    }

                    output[out_pos] = 0xEF;
                    output[out_pos + 1] = 0xBF;
                    output[out_pos + 2] = 0xBD; // U+FFFD in UTF-8
                    out_pos += 3;
                    in_pos += 1;
                } else {
                    // Wait for more input
                    return .{
                        .status = .input_empty,
                        .code_units_consumed = in_pos,
                        .bytes_written = out_pos,
                    };
                }
                continue;
            }

            const next_unit = input[in_pos + 1];

            // Branchless surrogate pair validation:
            // High surrogate: 0xD800-0xDBFF (bits 11011000xxxxxxxx to 11011011xxxxxxxx)
            // Low  surrogate: 0xDC00-0xDFFF (bits 11011100xxxxxxxx to 11011111xxxxxxxx)
            // Check top 6 bits using mask
            const is_low_surrogate = (next_unit & 0xFC00) == 0xDC00;

            // Check if next is low surrogate (0xDC00-0xDFFF)
            if (is_low_surrogate) {
                // Valid surrogate pair - decode to scalar value (WHATWG Infra §4.5)
                const code_point = code_points.decodeSurrogatePair(code_unit, next_unit) catch {
                    // This should never happen if our checks are correct
                    unreachable;
                };

                // Encode as 4-byte UTF-8
                if (out_pos + 4 > output.len) {
                    return .{
                        .status = .output_full,
                        .code_units_consumed = in_pos,
                        .bytes_written = out_pos,
                    };
                }

                output[out_pos] = @intCast(0xF0 | (code_point >> 18));
                output[out_pos + 1] = @intCast(0x80 | ((code_point >> 12) & 0x3F));
                output[out_pos + 2] = @intCast(0x80 | ((code_point >> 6) & 0x3F));
                output[out_pos + 3] = @intCast(0x80 | (code_point & 0x3F));
                out_pos += 4;
                in_pos += 2;
            } else {
                @branchHint(.unlikely); // Unpaired surrogates are rare
                // Unpaired high surrogate - emit replacement
                if (out_pos + 3 > output.len) {
                    return .{
                        .status = .output_full,
                        .code_units_consumed = in_pos,
                        .bytes_written = out_pos,
                    };
                }

                output[out_pos] = 0xEF;
                output[out_pos + 1] = 0xBF;
                output[out_pos + 2] = 0xBD;
                out_pos += 3;
                in_pos += 1;
            }
            continue;
        }

        // Branchless check for low surrogate: 0xDC00-0xDFFF
        const is_lone_low_surrogate = (code_unit & 0xFC00) == 0xDC00;

        // Low surrogate (0xDC00-0xDFFF) without high - emit replacement
        if (is_lone_low_surrogate) {
            @branchHint(.unlikely); // Unpaired surrogates are rare
            if (out_pos + 3 > output.len) {
                return .{
                    .status = .output_full,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }

            output[out_pos] = 0xEF;
            output[out_pos + 1] = 0xBF;
            output[out_pos + 2] = 0xBD;
            out_pos += 3;
            in_pos += 1;
            continue;
        }

        // BMP (0x0080-0xFFFF, excluding surrogates)
        const code_point: u21 = code_unit;

        if (code_point < 0x800) {
            // 2-byte sequence
            if (out_pos + 2 > output.len) {
                return .{
                    .status = .output_full,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }

            output[out_pos] = @intCast(0xC0 | (code_point >> 6));
            output[out_pos + 1] = @intCast(0x80 | (code_point & 0x3F));
            out_pos += 2;
        } else {
            // 3-byte sequence
            if (out_pos + 3 > output.len) {
                return .{
                    .status = .output_full,
                    .code_units_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }

            output[out_pos] = @intCast(0xE0 | (code_point >> 12));
            output[out_pos + 1] = @intCast(0x80 | ((code_point >> 6) & 0x3F));
            output[out_pos + 2] = @intCast(0x80 | (code_point & 0x3F));
            out_pos += 3;
        }

        in_pos += 1;
    }

    return .{
        .status = .input_empty,
        .code_units_consumed = in_pos,
        .bytes_written = out_pos,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "UTF-8 encode - ASCII only" {
    const input = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    var output: [100]u8 = undefined;

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 5), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 5), result.bytes_written);

    try std.testing.expectEqualStrings("Hello", output[0..5]);
}

test "UTF-8 encode - 2-byte sequence" {
    const input = [_]u16{ 'C', 'a', 'f', 0x00E9 }; // Café
    var output: [100]u8 = undefined;

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 4), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 5), result.bytes_written);

    try std.testing.expectEqualStrings("Caf", output[0..3]);
    // é is 0xC3 0xA9 in UTF-8
    try std.testing.expectEqual(@as(u8, 0xC3), output[3]);
    try std.testing.expectEqual(@as(u8, 0xA9), output[4]);
}

test "UTF-8 encode - 3-byte sequence" {
    const input = [_]u16{0x4E16}; // 世 (Chinese)
    var output: [100]u8 = undefined;

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
}

test "UTF-8 encode - surrogate pair (emoji)" {
    const input = [_]u16{ 0xD83D, 0xDCA9 }; // 💩 (U+1F4A9)
    var output: [100]u8 = undefined;

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_written);

    // U+1F4A9 in UTF-8: F0 9F 92 A9
    try std.testing.expectEqual(@as(u8, 0xF0), output[0]);
    try std.testing.expectEqual(@as(u8, 0x9F), output[1]);
    try std.testing.expectEqual(@as(u8, 0x92), output[2]);
    try std.testing.expectEqual(@as(u8, 0xA9), output[3]);
}

test "UTF-8 encode - unpaired high surrogate" {
    const input = [_]u16{ 0xD800, 'A' }; // Unpaired high surrogate
    var output: [100]u8 = undefined;

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_written);

    // Should emit replacement character (U+FFFD = EF BF BD in UTF-8)
    try std.testing.expectEqual(@as(u8, 0xEF), output[0]);
    try std.testing.expectEqual(@as(u8, 0xBF), output[1]);
    try std.testing.expectEqual(@as(u8, 0xBD), output[2]);
    try std.testing.expectEqual(@as(u8, 'A'), output[3]);
}

test "UTF-8 encode - unpaired low surrogate" {
    const input = [_]u16{ 0xDC00, 'A' }; // Unpaired low surrogate
    var output: [100]u8 = undefined;

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_written);

    // Should emit replacement character
    try std.testing.expectEqual(@as(u8, 0xEF), output[0]);
    try std.testing.expectEqual(@as(u8, 0xBF), output[1]);
    try std.testing.expectEqual(@as(u8, 0xBD), output[2]);
    try std.testing.expectEqual(@as(u8, 'A'), output[3]);
}

test "UTF-8 encode - output buffer full" {
    const input = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    var output: [3]u8 = undefined; // Deliberately small

    var encoder_obj: Encoder = .{
        .encoding = undefined,
        .state = .neutral,
    };

    const result = encode(&encoder_obj, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.output_full, result.status);
    try std.testing.expectEqual(@as(usize, 3), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
}
