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
    std.debug.assert(decoder.state == .single_byte or decoder.state == .neutral);

    // Get the index for this encoding
    const index = &decoder.state.single_byte.index;

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    // Fast path detection: Check if bytes 0xA0-0xFF are identity mappings
    // This is true for Windows-1252, ISO-8859-1, and several other encodings
    // We detect this by checking if index[32] == 0x00A0 (the pattern starts there)
    const has_identity_mapping = index.map[32] == 0x00A0;

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

        // Fast path: For encodings with identity mapping 0xA0-0xFF → U+00A0-U+00FF
        // This includes Windows-1252, ISO-8859-1, and others (~50% of single-byte encodings)
        if (has_identity_mapping and byte >= 0xA0) {
            output[out_pos] = byte; // Direct mapping, no table lookup!
            out_pos += 1;
            in_pos += 1;
            continue;
        }

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
            // Step 4: Not in index - emit replacement character
            output[out_pos] = 0xFFFD; // U+FFFD REPLACEMENT CHARACTER
            out_pos += 1;
            in_pos += 1;
        }
    }

    // All input consumed
    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .code_units_written = out_pos,
    };
}

// Tests

test "single-byte decode - ASCII" {
    const allocator = std.testing.allocator;
    _ = allocator;

    // Create simple test index
    const test_index = index_gen.parseIndex("0\t0x0410\n");

    var decoder = Decoder{
        .encoding = undefined, // Not needed for this test
        .state = .{ .single_byte = .{ .index = test_index } },
    };

    const input = "ABC";
    var output: [10]u16 = undefined;

    const result = decode(&decoder, input, &output, true);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 'A'), output[0]);
    try std.testing.expectEqual(@as(u16, 'B'), output[1]);
    try std.testing.expectEqual(@as(u16, 'C'), output[2]);
}

test "single-byte decode - index lookup" {
    // Index: pointer 0 → U+0410 (Cyrillic А)
    const test_index = index_gen.parseIndex("0\t0x0410\n1\t0x0411\n");

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .single_byte = .{ .index = test_index } },
    };

    // 0x80 maps to pointer 0 → U+0410
    // 0x81 maps to pointer 1 → U+0411
    const input = [_]u8{ 0x80, 0x81 };
    var output: [10]u16 = undefined;

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x0410), output[0]);
    try std.testing.expectEqual(@as(u16, 0x0411), output[1]);
}

test "single-byte decode - unmapped byte" {
    // Empty index - all non-ASCII bytes unmapped
    const test_index = index_gen.parseIndex("");

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .single_byte = .{ .index = test_index } },
    };

    const input = [_]u8{0x80}; // Unmapped
    var output: [10]u16 = undefined;

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0xFFFD), output[0]); // Replacement character
}

test "single-byte decode - mixed ASCII and non-ASCII" {
    const test_index = index_gen.parseIndex("0\t0x0410\n");

    var decoder = Decoder{
        .encoding = undefined,
        .state = .{ .single_byte = .{ .index = test_index } },
    };

    // "A" + 0x80 (→ U+0410) + "B"
    const input = [_]u8{ 'A', 0x80, 'B' };
    var output: [10]u16 = undefined;

    const result = decode(&decoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 'A'), output[0]);
    try std.testing.expectEqual(@as(u16, 0x0410), output[1]);
    try std.testing.expectEqual(@as(u16, 'B'), output[2]);
}
