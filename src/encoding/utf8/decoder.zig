//! UTF-8 Decoder
//!
//! Spec: https://encoding.spec.whatwg.org/#utf-8-decoder
//!
//! Implements the UTF-8 decoding algorithm with:
//! - ASCII fast path (critical for 90%+ of web content)
//! - Proper error handling (no ASCII masking per security requirements)
//! - Streaming support (maintains state across calls)
//! - BOM handling

const std = @import("std");
const webidl = @import("webidl");
const streaming = @import("../streaming.zig");
const ascii = @import("ascii.zig");
const Decoder = @import("../encoding.zig").Decoder;

// Use webidl.code_points for surrogate pair handling
const code_points = webidl.code_points;

/// UTF-8 lead byte metadata
const LeadByteInfo = struct {
    /// Number of continuation bytes needed (0 for ASCII, 0xFF for invalid)
    bytes_needed: u8,
    /// Mask for extracting payload bits
    payload_mask: u8,
    /// Lower boundary for first continuation byte
    lower_boundary: u8,
    /// Upper boundary for first continuation byte
    upper_boundary: u8,
};

/// Comptime-generated lookup table for UTF-8 lead bytes
const lead_byte_table = blk: {
    var table: [256]LeadByteInfo = undefined;

    // ASCII: 0x00-0x7F
    for (0..0x80) |i| {
        table[i] = .{
            .bytes_needed = 0,
            .payload_mask = 0x7F,
            .lower_boundary = 0x80,
            .upper_boundary = 0xBF,
        };
    }

    // Invalid: 0x80-0xC1
    for (0x80..0xC2) |i| {
        table[i] = .{
            .bytes_needed = 0xFF, // Invalid marker
            .payload_mask = 0,
            .lower_boundary = 0x80,
            .upper_boundary = 0xBF,
        };
    }

    // 2-byte sequences: 0xC2-0xDF
    for (0xC2..0xE0) |i| {
        table[i] = .{
            .bytes_needed = 1,
            .payload_mask = 0x1F,
            .lower_boundary = 0x80,
            .upper_boundary = 0xBF,
        };
    }

    // 3-byte sequences: 0xE0-0xEF
    for (0xE0..0xF0) |i| {
        if (i == 0xE0) {
            // Prevent overlong sequences
            table[i] = .{
                .bytes_needed = 2,
                .payload_mask = 0x0F,
                .lower_boundary = 0xA0,
                .upper_boundary = 0xBF,
            };
        } else if (i == 0xED) {
            // Prevent surrogates
            table[i] = .{
                .bytes_needed = 2,
                .payload_mask = 0x0F,
                .lower_boundary = 0x80,
                .upper_boundary = 0x9F,
            };
        } else {
            table[i] = .{
                .bytes_needed = 2,
                .payload_mask = 0x0F,
                .lower_boundary = 0x80,
                .upper_boundary = 0xBF,
            };
        }
    }

    // 4-byte sequences: 0xF0-0xF4
    for (0xF0..0xF5) |i| {
        if (i == 0xF0) {
            table[i] = .{
                .bytes_needed = 3,
                .payload_mask = 0x07,
                .lower_boundary = 0x90,
                .upper_boundary = 0xBF,
            };
        } else if (i == 0xF4) {
            table[i] = .{
                .bytes_needed = 3,
                .payload_mask = 0x07,
                .lower_boundary = 0x80,
                .upper_boundary = 0x8F,
            };
        } else {
            table[i] = .{
                .bytes_needed = 3,
                .payload_mask = 0x07,
                .lower_boundary = 0x80,
                .upper_boundary = 0xBF,
            };
        }
    }

    // Invalid: 0xF5-0xFF
    for (0xF5..0x100) |i| {
        table[i] = .{
            .bytes_needed = 0xFF, // Invalid marker
            .payload_mask = 0,
            .lower_boundary = 0x80,
            .upper_boundary = 0xBF,
        };
    }

    break :blk table;
};

/// UTF-8 decoder state
pub const Utf8DecoderState = struct {
    /// Accumulated code point value
    code_point: u21 = 0,

    /// Number of continuation bytes seen so far
    bytes_seen: u8 = 0,

    /// Number of continuation bytes needed for current sequence
    bytes_needed: u8 = 0,

    /// Lower boundary for valid continuation bytes (security)
    lower_boundary: u8 = 0x80,

    /// Upper boundary for valid continuation bytes (security)
    upper_boundary: u8 = 0xBF,
};

/// UTF-8 decode implementation
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-decoder
///
/// This is the handler function for UTF-8 decoding.
pub fn decode(
    decoder: *Decoder,
    input: []const u8,
    output: []u16,
    is_last: bool,
) streaming.DecodeResult {
    std.debug.assert(decoder.state == .utf8 or decoder.state == .neutral);

    // Initialize state if needed
    if (decoder.state == .neutral) {
        decoder.state = .{ .utf8 = .{ .code_point = 0, .bytes_seen = 0, .bytes_needed = 0, .lower_boundary = 0x80, .upper_boundary = 0xBF } };
    }

    var state = &decoder.state.utf8;
    var in_pos: usize = 0;
    var out_pos: usize = 0;

    // Fast path: Process ASCII prefix
    const ascii_len = ascii.countAsciiPrefix(input);
    if (ascii_len > 0 and state.bytes_needed == 0) {
        const to_copy = @min(ascii_len, output.len);
        const copied = ascii.copyAsciiToUtf16(input[0..to_copy], output);
        in_pos = copied;
        out_pos = copied;

        if (copied < ascii_len) {
            // Output buffer full
            return .{
                .status = .output_full,
                .bytes_consumed = in_pos,
                .code_units_written = out_pos,
            };
        }
    }

    // Slow path: Process multi-byte UTF-8 sequences
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

        // If we're not in a sequence, check for lead byte
        if (state.bytes_needed == 0) {
            // Use lookup table for lead byte dispatch
            const info = lead_byte_table[byte];

            // ASCII fast path (0x00-0x7F)
            if (info.bytes_needed == 0) {
                output[out_pos] = byte;
                out_pos += 1;
                in_pos += 1;
                continue;
            }

            // Invalid byte (0xFF marker)
            if (info.bytes_needed == 0xFF) {
                output[out_pos] = 0xFFFD; // Replacement character
                out_pos += 1;
                in_pos += 1;
                continue;
            }

            // Multi-byte sequence (2, 3, or 4 bytes)
            state.bytes_needed = info.bytes_needed;
            state.code_point = @as(u21, byte & info.payload_mask);
            state.lower_boundary = info.lower_boundary;
            state.upper_boundary = info.upper_boundary;
            in_pos += 1;
            continue;
        }

        // We're in a multi-byte sequence - process continuation byte

        // Validate continuation byte is in range
        if (byte < state.lower_boundary or byte > state.upper_boundary) {
            @branchHint(.unlikely); // Invalid sequences are rare in valid UTF-8
            // Invalid continuation byte - reset and emit replacement
            state.bytes_needed = 0;
            state.bytes_seen = 0;
            state.lower_boundary = 0x80;
            state.upper_boundary = 0xBF;

            output[out_pos] = 0xFFFD;
            out_pos += 1;
            // Don't consume this byte - it might be a valid lead byte
            continue;
        }

        // Reset boundaries after first continuation byte
        state.lower_boundary = 0x80;
        state.upper_boundary = 0xBF;

        // Accumulate code point
        state.code_point = (state.code_point << 6) | @as(u21, byte & 0x3F);
        state.bytes_seen += 1;
        in_pos += 1;

        // Check if sequence is complete
        if (state.bytes_seen == state.bytes_needed) {
            const code_point = state.code_point;

            // Reset state
            state.code_point = 0;
            state.bytes_seen = 0;
            state.bytes_needed = 0;

            // Emit code point as UTF-16
            if (code_point <= 0xFFFF) {
                // BMP - single code unit
                output[out_pos] = @intCast(code_point);
                out_pos += 1;
            } else {
                // Supplementary plane - surrogate pair
                if (out_pos + 1 >= output.len) {
                    // Need 2 code units but only 1 space - keep state for next call
                    state.code_point = code_point;
                    state.bytes_needed = 0xFF; // Special marker for "need to emit surrogate pair"
                    return .{
                        .status = .output_full,
                        .bytes_consumed = in_pos,
                        .code_units_written = out_pos,
                    };
                }

                // Encode supplementary plane as surrogate pair (WHATWG Infra §4.5)
                const pair = code_points.encodeSurrogatePair(code_point) catch {
                    // This should never happen for valid code points
                    unreachable;
                };

                output[out_pos] = pair.high;
                output[out_pos + 1] = pair.low;
                out_pos += 2;
            }
        }
    }

    // Check if we have incomplete sequence at end
    if (is_last and state.bytes_needed > 0 and state.bytes_needed != 0xFF) {
        @branchHint(.unlikely); // Incomplete sequences at EOF are rare
        // Incomplete sequence at EOF - emit replacement character
        if (out_pos < output.len) {
            output[out_pos] = 0xFFFD;
            out_pos += 1;
        }

        state.bytes_needed = 0;
        state.bytes_seen = 0;
    }

    return .{
        .status = .input_empty,
        .bytes_consumed = in_pos,
        .code_units_written = out_pos,
    };
}

// ============================================================================
// Tests
// ============================================================================







