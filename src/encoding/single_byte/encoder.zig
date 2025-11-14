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




