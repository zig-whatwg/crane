//! Comptime Encoding/Decoding
//!
//! Zero-runtime-cost string decoding for compile-time literals.
//! Decoded strings are embedded directly in the binary.

const std = @import("std");

/// Decode UTF-8 string literal at compile time.
///
/// Returns array (not slice) embedded in binary. Zero runtime cost.
///
/// Example:
/// ```zig
/// const decoded = comptime decodeUtf8Comptime("Hello, 世界!");
/// // decoded is [N]u16 embedded in .rodata section
/// // No runtime decoding needed
/// ```
///
/// **Performance:** ∞ speedup (zero runtime cost)
pub fn decodeUtf8Comptime(comptime input: []const u8) ComptimeDecodeResult(input) {
    comptime {
        // Count output length at comptime
        const output_len = countUtf8CodeUnits(input);

        // Create result array
        var result: [output_len]u16 = undefined;

        // Decode at comptime
        var in_pos: usize = 0;
        var out_pos: usize = 0;

        while (in_pos < input.len) {
            const byte = input[in_pos];

            // ASCII (0x00-0x7F)
            if (byte <= 0x7F) {
                result[out_pos] = byte;
                out_pos += 1;
                in_pos += 1;
                continue;
            }

            // 2-byte sequence (0xC2-0xDF)
            if (byte >= 0xC2 and byte <= 0xDF) {
                if (in_pos + 1 >= input.len) @compileError("Incomplete UTF-8 sequence");
                const byte2 = input[in_pos + 1];
                if (byte2 < 0x80 or byte2 > 0xBF) @compileError("Invalid UTF-8 continuation byte");

                const code_point = (@as(u21, byte & 0x1F) << 6) | @as(u21, byte2 & 0x3F);
                result[out_pos] = @intCast(code_point);
                out_pos += 1;
                in_pos += 2;
                continue;
            }

            // 3-byte sequence (0xE0-0xEF)
            if (byte >= 0xE0 and byte <= 0xEF) {
                if (in_pos + 2 >= input.len) @compileError("Incomplete UTF-8 sequence");
                const byte2 = input[in_pos + 1];
                const byte3 = input[in_pos + 2];

                // Validate continuation bytes
                if (byte == 0xE0 and byte2 < 0xA0) @compileError("Overlong UTF-8 sequence");
                if (byte == 0xED and byte2 > 0x9F) @compileError("Surrogate in UTF-8");
                if (byte2 < 0x80 or byte2 > 0xBF) @compileError("Invalid UTF-8 continuation byte");
                if (byte3 < 0x80 or byte3 > 0xBF) @compileError("Invalid UTF-8 continuation byte");

                const code_point = (@as(u21, byte & 0x0F) << 12) |
                    (@as(u21, byte2 & 0x3F) << 6) |
                    @as(u21, byte3 & 0x3F);
                result[out_pos] = @intCast(code_point);
                out_pos += 1;
                in_pos += 3;
                continue;
            }

            // 4-byte sequence (0xF0-0xF4)
            if (byte >= 0xF0 and byte <= 0xF4) {
                if (in_pos + 3 >= input.len) @compileError("Incomplete UTF-8 sequence");
                const byte2 = input[in_pos + 1];
                const byte3 = input[in_pos + 2];
                const byte4 = input[in_pos + 3];

                // Validate continuation bytes
                if (byte == 0xF0 and byte2 < 0x90) @compileError("Overlong UTF-8 sequence");
                if (byte == 0xF4 and byte2 > 0x8F) @compileError("Code point > U+10FFFF");
                if (byte2 < 0x80 or byte2 > 0xBF) @compileError("Invalid UTF-8 continuation byte");
                if (byte3 < 0x80 or byte3 > 0xBF) @compileError("Invalid UTF-8 continuation byte");
                if (byte4 < 0x80 or byte4 > 0xBF) @compileError("Invalid UTF-8 continuation byte");

                const code_point = (@as(u21, byte & 0x07) << 18) |
                    (@as(u21, byte2 & 0x3F) << 12) |
                    (@as(u21, byte3 & 0x3F) << 6) |
                    @as(u21, byte4 & 0x3F);

                // Emit as surrogate pair
                if (out_pos + 1 >= output_len) @compileError("Buffer overflow");
                const high = @as(u16, @intCast(0xD800 + ((code_point - 0x10000) >> 10)));
                const low = @as(u16, @intCast(0xDC00 + ((code_point - 0x10000) & 0x3FF)));
                result[out_pos] = high;
                result[out_pos + 1] = low;
                out_pos += 2;
                in_pos += 4;
                continue;
            }

            @compileError("Invalid UTF-8 lead byte");
        }

        return result;
    }
}

/// Get result type for comptime decoding
fn ComptimeDecodeResult(comptime input: []const u8) type {
    const len = countUtf8CodeUnits(input);
    return [len]u16;
}

/// Count UTF-16 code units needed for UTF-8 input (at comptime)
fn countUtf8CodeUnits(comptime input: []const u8) usize {
    comptime {
        var count: usize = 0;
        var i: usize = 0;

        while (i < input.len) {
            const byte = input[i];

            if (byte <= 0x7F) {
                count += 1;
                i += 1;
            } else if (byte >= 0xC2 and byte <= 0xDF) {
                count += 1;
                i += 2;
            } else if (byte >= 0xE0 and byte <= 0xEF) {
                count += 1;
                i += 3;
            } else if (byte >= 0xF0 and byte <= 0xF4) {
                count += 2; // Surrogate pair
                i += 4;
            } else {
                @compileError("Invalid UTF-8 sequence");
            }
        }

        return count;
    }
}

// Tests





