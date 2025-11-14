//! Percent Encoding and Decoding
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#percent-encoded-bytes
//! Spec Reference: Lines 118-235
//!
//! Percent encoding converts bytes into %XX format where XX is the hexadecimal
//! representation of the byte value. Percent decoding reverses this process.
//!
//! ## Key Functions
//!
//! - `percentEncodeByte()` - Encode a single byte to %XX
//! - `percentDecode()` - Decode %XX sequences in byte sequence
//! - `percentDecodeString()` - Decode %XX sequences in UTF-8 string
//! - `utf8PercentEncode()` - Encode UTF-8 string with given encode set
//!
//! ## Usage
//!
//! ```zig
//! const percent = @import("encoding/percent_encoding.zig");
//! const encode_sets = @import("encode_sets");
//!
//! // Encode a byte
//! const encoded = percent.percentEncodeByte(0x20); // "%20"
//!
//! // Decode a string
//! const decoded = try percent.percentDecodeString(allocator, "hello%20world");
//! defer allocator.free(decoded);
//!
//! // UTF-8 percent encode
//! const encoded_str = try percent.utf8PercentEncode(
//!     allocator,
//!     "hello world",
//!     .userinfo
//! );
//! defer allocator.free(encoded_str);
//! ```

const std = @import("std");
const infra = @import("infra");
const encode_sets = @import("encode_sets");

/// Percent-encode a single byte (spec line 124)
///
/// Returns a 3-character string: U+0025 (%), followed by two ASCII upper hex digits.
///
/// Example: 0x20 -> "%20"
pub fn percentEncodeByte(byte: u8) [3]u8 {
    const hex_digits = "0123456789ABCDEF";
    return [3]u8{
        '%',
        hex_digits[byte >> 4],
        hex_digits[byte & 0x0F],
    };
}

/// P9 Optimization: Fast inline encoding for single ASCII character
///
/// For ASCII-only input (char < 128), determines if encoding is needed and
/// returns either the character as-is or percent-encoded, without allocation.
///
/// Returns: (needs_encoding, encoded_length, encoded_bytes)
/// - If needs_encoding = false: encoded_bytes[0] = original char, length = 1
/// - If needs_encoding = true: encoded_bytes[0..3] = "%XX", length = 3
pub inline fn encodeSingleAscii(char: u8, encode_set: encode_sets.EncodeSet) struct { needs_encoding: bool, length: u8, bytes: [3]u8 } {
    // Check if character needs encoding
    if (encode_sets.shouldEncode(@as(u21, char), encode_set)) {
        const encoded = percentEncodeByte(char);
        return .{ .needs_encoding = true, .length = 3, .bytes = encoded };
    } else {
        return .{ .needs_encoding = false, .length = 1, .bytes = [3]u8{ char, 0, 0 } };
    }
}

/// Check if next two bytes are ASCII hex digits (helper for percent-decode)
fn isValidPercentEncoding(input: []const u8, pos: usize) bool {
    if (pos + 2 >= input.len) return false;

    const first = input[pos + 1];
    const second = input[pos + 2];

    return std.ascii.isHex(first) and std.ascii.isHex(second);
}

/// Parse two ASCII hex digits to byte value (helper for percent-decode)
fn parseHexByte(first: u8, second: u8) u8 {
    const hi = std.fmt.charToDigit(first, 16) catch unreachable;
    const lo = std.fmt.charToDigit(second, 16) catch unreachable;
    return (@as(u8, hi) << 4) | lo;
}

/// Percent-decode a byte sequence (spec lines 126-146)
///
/// Steps:
/// 1. Create output byte sequence
/// 2. For each byte in input:
///    - If not '%', append byte to output
///    - If '%' but next two aren't hex digits, append '%' to output
///    - Otherwise, decode hex bytes and append to output, skip next two bytes
/// 3. Return output
///
/// Example: "%25%20" -> "% " (0x25 0x20)
pub fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const byte = input[i];

        // Step 2.1: If byte is not 0x25 (%), append to output
        if (byte != '%') {
            try output.append(byte);
            continue;
        }

        // Step 2.2: If % but next two aren't hex digits, append %
        if (!isValidPercentEncoding(input, i)) {
            try output.append(byte);
            continue;
        }

        // Step 2.3: Decode hex bytes
        const decoded_byte = parseHexByte(input[i + 1], input[i + 2]);
        try output.append(decoded_byte);
        i += 2; // Skip next two bytes
    }

    return output.toOwnedSlice();
}

/// Percent-decode a UTF-8 string (spec lines 148-152)
///
/// Steps:
/// 1. Convert string to UTF-8 bytes
/// 2. Percent-decode the bytes
/// 3. Return decoded bytes as string
///
/// Note: Result may not be valid UTF-8. Caller should validate if needed.
pub fn percentDecodeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // Input is already UTF-8 bytes (Zig strings are UTF-8)
    return percentDecode(allocator, input);
}

/// P5 Optimization: ASCII-only fast path for percent encoding
///
/// For ASCII-only strings (90% of URLs), skip expensive UTF-8 validation
/// and use direct byte operations. Falls back to UTF-8 path for non-ASCII.
inline fn utf8PercentEncodeAscii(
    allocator: std.mem.Allocator,
    input: []const u8,
    encode_set: encode_sets.EncodeSet,
) ![]u8 {
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    // Fast path: Process bytes directly (all are single-byte code points)
    for (input) |byte| {
        // Check if byte should be encoded (cast to u21 for API compatibility)
        if (encode_sets.shouldEncode(@as(u21, byte), encode_set)) {
            const encoded = percentEncodeByte(byte);
            try output.appendSlice(&encoded);
        } else {
            try output.append(byte);
        }
    }

    return output.toOwnedSlice();
}

/// UTF-8 percent-encode a string using a percent-encode set (spec line 218)
///
/// For each code point in input:
/// 1. If code point is not in encode set, append as-is
/// 2. Otherwise, convert to UTF-8 bytes and percent-encode each byte
///
/// Example: "hello world" with userinfo set -> "hello%20world"
///
/// P5 Optimization: Detects ASCII-only input and uses fast path (90% of URLs).
pub fn utf8PercentEncode(
    allocator: std.mem.Allocator,
    input: []const u8,
    encode_set: encode_sets.EncodeSet,
) ![]u8 {
    // P5: ASCII fast path detection
    // Check if all bytes are ASCII (< 128)
    var is_ascii = true;
    for (input) |byte| {
        if (byte >= 128) {
            is_ascii = false;
            break;
        }
    }

    // Use ASCII fast path if possible
    if (is_ascii) {
        return utf8PercentEncodeAscii(allocator, input, encode_set);
    }

    // UTF-8 slow path for non-ASCII input
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    var i: usize = 0;
    while (i < input.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            // Invalid UTF-8, encode the byte
            const encoded = percentEncodeByte(input[i]);
            try output.appendSlice(&encoded);
            i += 1;
            continue;
        };

        if (i + cp_len > input.len) {
            // Truncated UTF-8, encode remaining bytes
            while (i < input.len) : (i += 1) {
                const encoded = percentEncodeByte(input[i]);
                try output.appendSlice(&encoded);
            }
            break;
        }

        const cp = std.unicode.utf8Decode(input[i..][0..cp_len]) catch {
            // Invalid UTF-8, encode the bytes
            var j: usize = 0;
            while (j < cp_len) : (j += 1) {
                const encoded = percentEncodeByte(input[i + j]);
                try output.appendSlice(&encoded);
            }
            i += cp_len;
            continue;
        };

        // Check if code point should be encoded
        if (encode_sets.shouldEncode(cp, encode_set)) {
            // Percent-encode each UTF-8 byte
            var j: usize = 0;
            while (j < cp_len) : (j += 1) {
                const encoded = percentEncodeByte(input[i + j]);
                try output.appendSlice(&encoded);
            }
        } else {
            // Append code point as-is
            try output.appendSlice(input[i..][0..cp_len]);
        }

        i += cp_len;
    }

    return output.toOwnedSlice();
}






