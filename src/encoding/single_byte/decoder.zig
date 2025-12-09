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

// Tests
