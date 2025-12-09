//! Single-Byte Decoder
//!
//! WHATWG Encoding Standard § 9.1
//! https://encoding.spec.whatwg.org/#single-byte-decoder
//!
//! Generic decoder for all 28 single-byte encodings.
//! Each encoding has a 128-entry index mapping pointers 0-127 to Unicode code points.

const std = @import("std");
const streaming = @import("../streaming.zig");
const Decoder = @import("../encoding.zig").Decoder;
const index_gen = @import("index_generator.zig");

/// Single-byte decode implementation
///
/// WHATWG spec § 9.1:
/// 1. If byte is end-of-queue, return finished.
/// 2. If byte is an ASCII byte, return a code point whose value is byte.
/// 3. Let code point be the index code point for byte − 0x80 in index single-byte.
/// 4. If code point is null, return error.
/// 5. Return a code point whose value is code point.
pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    _ = is_last; // Single-byte decoding doesn't need is_last

    // Get the index for this encoding
    // Single-byte decoders MUST have single_byte state with a valid index
    const index = switch (decoder.state) {
        .single_byte => |*sb| &sb.index,
        else => {
            // Invalid state - this shouldn't happen for single-byte encodings
            // Return empty result to prevent undefined behavior
            return .{
                .status = .input_empty,
                .bytes_consumed = 0,
                .code_units_written = 0,
            };
        },
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    // NOTE: A fast path optimization was removed here. The optimization assumed
    // that if index[32] == 0x00A0, all bytes >= 0xA0 could be passed through directly.
    // This is incorrect for encodings like ISO-8859-3 which have unmapped bytes
    // (0xFFFF values) in the 0xA0-0xFF range. Table lookup is required for correctness.

    while (in_pos < input.len) {
        // Prefetch next cache line for large buffers (64-byte cache lines)
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }

        if (out_pos >= output.len) {
            // Output buffer full
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }

        const byte = input[in_pos];

        // Step 2: ASCII bytes (0x00-0x7F) pass through
        if (byte < 0x80) {
            output[out_pos] = byte;
            out_pos += 1;
            in_pos += 1;
            continue;
        }

        // NOTE: Removed the "identity mapping fast path" optimization.
        // While some encodings (ISO-8859-1, Windows-1252) have contiguous identity mappings
        // for 0xA0-0xFF, other encodings (ISO-8859-3, ISO-8859-6, etc.) have holes
        // in this range that must return errors. The table lookup is necessary
        // for correctness.

        // Step 3: Look up in index (byte - 0x80)
        const pointer = byte - 0x80;
        const code_point = index_gen.getCodePoint(index, pointer);

        if (code_point) |cp| {
            // Step 5: Valid code point found
            output[out_pos] = @intCast(cp);
            out_pos += 1;
            in_pos += 1;
        } else {
            @branchHint(.unlikely); // Invalid code points are rare in valid encodings
            // Step 4: Not in index - return error
            // The higher-level algorithm decides whether to throw (fatal mode)
            // or emit replacement character (replacement mode)
            return .{
                .status = .malformed,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
                .error_length = 1, // Single byte error
            };
        }
    }

    // All input consumed
    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .code_units_written = out_pos,
    };
}

/// Single-byte decode implementation outputting directly to UTF-8
///
/// This is an optimized path that avoids the UTF-16 intermediate buffer.
/// Each input byte maps to exactly one code point, which is encoded directly
/// as 1-3 UTF-8 bytes.
///
/// WHATWG spec § 9.1 (same algorithm, different output format):
/// 1. If byte is end-of-queue, return finished.
/// 2. If byte is an ASCII byte, return a code point whose value is byte.
/// 3. Let code point be the index code point for byte − 0x80 in index single-byte.
/// 4. If code point is null, return error.
/// 5. Return a code point whose value is code point.
pub fn decodeToUtf8(
    decoder: *Decoder,
    input: []const u8,
    output: []u8,
    is_last: bool,
) streaming.DecodeToUtf8Result {
    _ = is_last; // Single-byte decoding doesn't need is_last

    // Get the index for this encoding
    const index = switch (decoder.state) {
        .single_byte => |*sb| &sb.index,
        else => {
            return .{
                .status = .input_empty,
                .bytes_consumed = 0,
                .bytes_written = 0,
            };
        },
    };

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        // Prefetch next cache line for large buffers
        if (in_pos + 64 < input.len) {
            @prefetch(&input[in_pos + 64], .{ .rw = .read, .locality = 3 });
        }

        const byte = input[in_pos];

        // Step 2: ASCII bytes (0x00-0x7F) pass through as single UTF-8 byte
        if (byte < 0x80) {
            if (out_pos >= output.len) {
                return .{
                    .status = .output_full,
                    .bytes_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }
            output[out_pos] = byte;
            out_pos += 1;
            in_pos += 1;
            continue;
        }

        // Step 3: Look up in index (byte - 0x80)
        const pointer = byte - 0x80;
        const code_point = index_gen.getCodePoint(index, pointer);

        if (code_point) |cp| {
            // Step 5: Valid code point found - encode to UTF-8
            const bytes_needed = utf8ByteLen(cp);
            if (out_pos + bytes_needed > output.len) {
                return .{
                    .status = .output_full,
                    .bytes_consumed = in_pos,
                    .bytes_written = out_pos,
                };
            }

            out_pos += writeUtf8(cp, output[out_pos..]);
            in_pos += 1;
        } else {
            @branchHint(.unlikely);
            // Step 4: Not in index - return error
            return .{
                .status = .malformed,
                .bytes_consumed = in_pos,
                .bytes_written = out_pos,
                .error_length = 1,
            };
        }
    }

    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .bytes_written = out_pos,
    };
}

/// Calculate UTF-8 byte length for a code point
inline fn utf8ByteLen(cp: u21) usize {
    if (cp < 0x80) return 1;
    if (cp < 0x800) return 2;
    if (cp < 0x10000) return 3;
    return 4;
}

/// Write a code point as UTF-8 bytes. Returns number of bytes written.
inline fn writeUtf8(cp: u21, output: []u8) usize {
    if (cp < 0x80) {
        output[0] = @intCast(cp);
        return 1;
    } else if (cp < 0x800) {
        output[0] = @intCast(0xC0 | (cp >> 6));
        output[1] = @intCast(0x80 | (cp & 0x3F));
        return 2;
    } else if (cp < 0x10000) {
        output[0] = @intCast(0xE0 | (cp >> 12));
        output[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        output[2] = @intCast(0x80 | (cp & 0x3F));
        return 3;
    } else {
        output[0] = @intCast(0xF0 | (cp >> 18));
        output[1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
        output[2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        output[3] = @intCast(0x80 | (cp & 0x3F));
        return 4;
    }
}

// Tests

const encoding = @import("../encoding.zig");

test "decodeToUtf8 - ASCII passthrough" {
    // ASCII bytes should pass through unchanged
    var decoder = encoding.WINDOWS_1252.newDecoder();
    const input = "Hello, World!";
    var output: [64]u8 = undefined;

    const result = decodeToUtf8(&decoder, input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(input.len, result.bytes_consumed);
    try std.testing.expectEqual(input.len, result.bytes_written);
    try std.testing.expectEqualStrings(input, output[0..result.bytes_written]);
}

test "decodeToUtf8 - Windows-1252 euro sign (0x80 -> U+20AC)" {
    // Windows-1252: 0x80 maps to U+20AC (€)
    // U+20AC in UTF-8 is: 0xE2 0x82 0xAC
    var decoder = encoding.WINDOWS_1252.newDecoder();
    const input = [_]u8{0x80};
    var output: [64]u8 = undefined;

    const result = decodeToUtf8(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xE2, 0x82, 0xAC }, output[0..result.bytes_written]);
}

test "decodeToUtf8 - mixed ASCII and non-ASCII" {
    // Windows-1252: 0x80 (€) followed by 'A'
    var decoder = encoding.WINDOWS_1252.newDecoder();
    const input = [_]u8{ 0x80, 'A' };
    var output: [64]u8 = undefined;

    const result = decodeToUtf8(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.bytes_written); // 3 bytes for € + 1 for A
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xE2, 0x82, 0xAC, 'A' }, output[0..result.bytes_written]);
}

test "decodeToUtf8 - output buffer full" {
    // Test that we handle output buffer being too small
    var decoder = encoding.WINDOWS_1252.newDecoder();
    const input = [_]u8{0x80}; // € needs 3 bytes
    var output: [2]u8 = undefined; // Only 2 bytes available

    const result = decodeToUtf8(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.output_full, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.bytes_written);
}

test "decodeToUtf8 - 2-byte UTF-8 characters" {
    // ISO-8859-2: 0xC0 maps to U+0154 (Ŕ with acute)
    // U+0154 in UTF-8 is: 0xC5 0x94
    var decoder = encoding.ISO_8859_2.newDecoder();
    const input = [_]u8{0xC0};
    var output: [64]u8 = undefined;

    const result = decodeToUtf8(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_written);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xC5, 0x94 }, output[0..result.bytes_written]);
}

test "decodeToUtf8 - unmapped byte returns malformed" {
    // ISO-8859-3: 0xA5 is unmapped (returns null)
    var decoder = encoding.ISO_8859_3.newDecoder();
    const input = [_]u8{0xA5};
    var output: [64]u8 = undefined;

    const result = decodeToUtf8(&decoder, &input, &output, true);

    try std.testing.expectEqual(streaming.DecodeToUtf8Result.Status.malformed, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.bytes_written);
    try std.testing.expectEqual(@as(u8, 1), result.error_length);
}
