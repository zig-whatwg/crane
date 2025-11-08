//! Single-Byte Encoder
//!
//! WHATWG Encoding Standard § 9.2
//! https://encoding.spec.whatwg.org/#single-byte-encoder
//!
//! Generic encoder for all 28 single-byte encodings.

const std = @import("std");
const streaming = @import("../streaming.zig");
const Encoder = @import("../encoding.zig").Encoder;
const index_gen = @import("index_generator.zig");

/// Single-byte encode implementation
///
/// WHATWG spec § 9.2:
/// 1. If code point is end-of-queue, return finished.
/// 2. If code point is an ASCII code point, return a byte whose value is code point.
/// 3. Let pointer be the index pointer for code point in index single-byte.
/// 4. If pointer is null, return error with code point.
/// 5. Return a byte whose value is pointer + 0x80.
pub fn encode(
    encoder: *Encoder,
    input: []const u16,
    output: []u8,
    is_last: bool,
) streaming.EncodeResult {
    _ = is_last; // Single-byte encoding doesn't need is_last
    std.debug.assert(encoder.state == .neutral);

    // Get the index from encoding
    const index = &encoder.encoding.single_byte_index.?;

    var in_pos: usize = 0;
    var out_pos: usize = 0;

    while (in_pos < input.len) {
        if (out_pos >= output.len) {
            // Output buffer full
            return .{
                .status = .output_full,
                .code_units_consumed = in_pos,
                .bytes_written = out_pos,
            };
        }

        const code_unit = input[in_pos];

        // Step 2: ASCII code points (0x0000-0x007F) pass through
        if (code_unit < 0x80) {
            output[out_pos] = @intCast(code_unit);
            out_pos += 1;
            in_pos += 1;
            continue;
        }

        // Step 3: Look up in index
        const pointer = index_gen.getPointer(index, @intCast(code_unit));

        if (pointer) |ptr| {
            // Step 5: Valid pointer found - return ptr + 0x80
            output[out_pos] = ptr + 0x80;
            out_pos += 1;
            in_pos += 1;
        } else {
            // Step 4: Not in index - emit error placeholder (?)
            // In replacement mode, emit '?' (0x3F)
            output[out_pos] = 0x3F; // Question mark
            out_pos += 1;
            in_pos += 1;
        }
    }

    // All input consumed
    return .{
        .status = .input_empty,
        .code_units_consumed = in_pos,
        .bytes_written = out_pos,
    };
}

// Tests

test "single-byte encode - ASCII" {
    // Create simple test index
    const test_index = index_gen.parseIndex("0\t0x0410\n");

    var encoder = Encoder{
        .encoding = &.{
            .name = "test",
            .whatwg_name = "test",
            .decode_fn = undefined,
            .encode_fn = null,
            .single_byte_index = test_index,
        },
        .state = .neutral,
    };

    const input = [_]u16{ 'A', 'B', 'C' };
    var output: [10]u8 = undefined;

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 3), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
    try std.testing.expectEqual(@as(u8, 'A'), output[0]);
    try std.testing.expectEqual(@as(u8, 'B'), output[1]);
    try std.testing.expectEqual(@as(u8, 'C'), output[2]);
}

test "single-byte encode - index lookup" {
    // Index: U+0410 → pointer 0, U+0411 → pointer 1
    const test_index = index_gen.parseIndex("0\t0x0410\n1\t0x0411\n");

    var encoder = Encoder{
        .encoding = &.{
            .name = "test",
            .whatwg_name = "test",
            .decode_fn = undefined,
            .encode_fn = null,
            .single_byte_index = test_index,
        },
        .state = .neutral,
    };

    const input = [_]u16{ 0x0410, 0x0411 };
    var output: [10]u8 = undefined;

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 2), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_written);
    try std.testing.expectEqual(@as(u8, 0x80), output[0]); // pointer 0 + 0x80
    try std.testing.expectEqual(@as(u8, 0x81), output[1]); // pointer 1 + 0x80
}

test "single-byte encode - unmapped code point" {
    // Empty index - no non-ASCII mappings
    const test_index = index_gen.parseIndex("");

    var encoder = Encoder{
        .encoding = &.{
            .name = "test",
            .whatwg_name = "test",
            .decode_fn = undefined,
            .encode_fn = null,
            .single_byte_index = test_index,
        },
        .state = .neutral,
    };

    const input = [_]u16{0x0410}; // Unmapped
    var output: [10]u8 = undefined;

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 1), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_written);
    try std.testing.expectEqual(@as(u8, '?'), output[0]); // Replacement
}

test "single-byte encode - mixed ASCII and non-ASCII" {
    const test_index = index_gen.parseIndex("0\t0x0410\n");

    var encoder = Encoder{
        .encoding = &.{
            .name = "test",
            .whatwg_name = "test",
            .decode_fn = undefined,
            .encode_fn = null,
            .single_byte_index = test_index,
        },
        .state = .neutral,
    };

    // "A" + U+0410 + "B"
    const input = [_]u16{ 'A', 0x0410, 'B' };
    var output: [10]u8 = undefined;

    const result = encode(&encoder, &input, &output, true);

    try std.testing.expectEqual(@as(usize, 3), result.code_units_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.bytes_written);
    try std.testing.expectEqual(@as(u8, 'A'), output[0]);
    try std.testing.expectEqual(@as(u8, 0x80), output[1]); // U+0410 → pointer 0 + 0x80
    try std.testing.expectEqual(@as(u8, 'B'), output[2]);
}
