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

    // Initialize state if needed
    if (decoder.state == .neutral) {
        decoder.state = .{ .gb18030 = .{
            .gb18030_first = 0x00,
            .gb18030_second = 0x00,
            .gb18030_third = 0x00,
            .is_gbk = false,
        } };
    }

    var state = &decoder.state.gb18030;
    var byte_decoder = gb18030_impl.Decoder{
        .gb18030_first = state.gb18030_first,
        .gb18030_second = state.gb18030_second,
        .gb18030_third = state.gb18030_third,
        .is_gbk = state.is_gbk,
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        // Prefetch next cache line for large buffers (64-byte cache lines)
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }

        if (out_pos >= output.len) {
            // Output buffer full - save state and return
            state.gb18030_first = byte_decoder.gb18030_first;
            state.gb18030_second = byte_decoder.gb18030_second;
            state.gb18030_third = byte_decoder.gb18030_third;
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }

        const byte = input[in_pos];

        // Decode one byte
        const result = byte_decoder.decode(byte) catch {
            @branchHint(.unlikely); // Decoding errors are rare in valid GB18030
            // Decoding error - emit replacement character
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            in_pos += 1;

            // Reset decoder state
            byte_decoder.gb18030_first = 0x00;
            byte_decoder.gb18030_second = 0x00;
            byte_decoder.gb18030_third = 0x00;
            continue;
        };

        in_pos += 1;

        if (result) |code_point| {
            // Got a code point - emit it as UTF-16
            if (code_point <= 0xFFFF) {
                // BMP code point - single UTF-16 code unit
                output[out_pos] = @intCast(code_point);
                out_pos += 1;
            } else {
                // Supplementary code point - need surrogate pair
                if (out_pos + 1 >= output.len) {
                    // Not enough space for surrogate pair - back up
                    in_pos -= 1;
                    state.gb18030_first = byte_decoder.gb18030_first;
                    state.gb18030_second = byte_decoder.gb18030_second;
                    state.gb18030_third = byte_decoder.gb18030_third;
                    return .{
                        .status = .output_full,
                        .bytes_consumed = in_pos,
                        .code_units_written = out_pos,
                    };
                }

                // Encode as UTF-16 surrogate pair
                const adjusted = code_point - 0x10000;
                const high: u16 = @intCast(0xD800 + (adjusted >> 10));
                const low: u16 = @intCast(0xDC00 + (adjusted & 0x3FF));
                output[out_pos] = high;
                output[out_pos + 1] = low;
                out_pos += 2;
            }
        }
        // If result is null, continue accumulating bytes
    }

    // Save state
    state.gb18030_first = byte_decoder.gb18030_first;
    state.gb18030_second = byte_decoder.gb18030_second;
    state.gb18030_third = byte_decoder.gb18030_third;

    // Check if we have pending bytes at end of stream
    if (is_last and (state.gb18030_first != 0x00 or
        state.gb18030_second != 0x00 or
        state.gb18030_third != 0x00))
    {
        @branchHint(.unlikely); // Incomplete sequences at EOF are rare
        // Incomplete sequence at end - emit error
        if (out_pos < output.len) {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
            state.gb18030_first = 0x00;
            state.gb18030_second = 0x00;
            state.gb18030_third = 0x00;
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

// Tests
test "gb18030 streaming decode - ASCII" {
    const input = "Hello, World!";
    var output: [50]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .gb18030_first = 0, .gb18030_second = 0, .gb18030_third = 0, .is_gbk = false } },
    };

    const result = decode(&decoder, input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 13), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 13), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 'H'), output[0]);
    try std.testing.expectEqual(@as(u16, '!'), output[12]);
}

test "gb18030 streaming decode - Euro sign" {
    const input = [_]u8{0x80}; // € in gb18030
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .gb18030_first = 0, .gb18030_second = 0, .gb18030_third = 0, .is_gbk = false } },
    };

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x20AC), output[0]); // €
}

test "gb18030 streaming decode - 2-byte sequence" {
    const input = [_]u8{ 0x81, 0x40 }; // U+4E02
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .gb18030_first = 0, .gb18030_second = 0, .gb18030_third = 0, .is_gbk = false } },
    };

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x4E02), output[0]);
}

test "gb18030 streaming decode - 4-byte sequence" {
    const input = [_]u8{ 0x81, 0x30, 0x81, 0x30 }; // U+0080
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .gb18030_first = 0, .gb18030_second = 0, .gb18030_third = 0, .is_gbk = false } },
    };

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x0080), output[0]);
}

test "gb18030 streaming decode - output buffer full" {
    const input = "Hello";
    var output: [3]u16 = undefined; // Only room for 3 chars

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .gb18030_first = 0, .gb18030_second = 0, .gb18030_third = 0, .is_gbk = false } },
    };

    const result = decode(&decoder, input, &output, false);

    try std.testing.expectEqual(streaming.DecodeResult.Status.output_full, result.status);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.code_units_written);
}

test "gb18030 streaming decode - chunked input" {
    var output: [10]u16 = undefined;

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .gb18030_first = 0, .gb18030_second = 0, .gb18030_third = 0, .is_gbk = false } },
    };

    // First chunk: first byte of 2-byte sequence
    const chunk1 = [_]u8{0x81};
    const result1 = decode(&decoder, &chunk1, &output, false);
    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result1.status);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result1.code_units_written); // No output yet

    // Second chunk: second byte completes the sequence
    const chunk2 = [_]u8{0x40};
    const result2 = decode(&decoder, &chunk2, &output, true);
    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result2.status);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result2.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x4E02), output[0]);
}

test "gb18030 streaming encode - ASCII" {
    const input = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    var output: [50]u8 = undefined;

    var encoder = Encoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .is_gbk = false, .pending_high_surrogate = null } },
    };

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 5), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 5), result.bytes_written);
    try std.testing.expectEqualSlices(u8, "Hello", output[0..5]);
}

test "gb18030 streaming encode - 2-byte sequence" {
    const input = [_]u16{0x4E02}; // 丂
    var output: [10]u8 = undefined;

    var encoder = Encoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .is_gbk = false, .pending_high_surrogate = null } },
    };

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_written);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x81, 0x40 }, output[0..2]);
}

test "gb18030 streaming encode - 4-byte sequence" {
    const input = [_]u16{0x0080};
    var output: [10]u8 = undefined;

    var encoder = Encoder{
        .encoding = undefined,
        .state = .{ .gb18030 = .{ .is_gbk = false, .pending_high_surrogate = null } },
    };

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_written);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x81, 0x30, 0x81, 0x30 }, output[0..4]);
}
