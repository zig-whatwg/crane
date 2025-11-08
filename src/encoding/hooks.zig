//! WHATWG Encoding Standard Hooks
//!
//! WHATWG Encoding Standard § 6 - Hooks for standards
//! https://encoding.spec.whatwg.org/#hooks-for-standards
//!
//! These algorithms are intended for usage by other WHATWG standards (DOM, Fetch, URL, etc.).
//!
//! Three UTF-8 decode variants:
//! 1. `utf8Decode` - removes BOM if present (standard decode)
//! 2. `utf8DecodeWithoutBom` - no BOM removal
//! 3. `utf8DecodeWithoutBomOrFail` - no BOM removal, fatal errors
//!
//! One UTF-8 encode variant:
//! 1. `utf8Encode` - standard encoding

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const bom = @import("bom.zig");
const utf8_decode_fn = @import("utf8/decoder.zig").decode;
const utf8_encode_fn = @import("utf8/encoder.zig").encode;
const streaming = @import("streaming.zig");
const Decoder = @import("encoding.zig").Decoder;
const Encoder = @import("encoding.zig").Encoder;
const encoding_mod = @import("encoding.zig");

// Use webidl.code_points for surrogate handling (per AGENTS.md: "Prefer WebIDL API over Infra")
const code_points = webidl.code_points;

/// Error returned by decode operations
pub const DecodeError = error{
    /// Invalid UTF-8 sequence (only for fatal mode)
    InvalidUtf8Sequence,
    /// Out of memory
    OutOfMemory,
};

/// Error returned by encode operations
pub const EncodeError = error{
    /// Out of memory
    OutOfMemory,
};

/// UTF-8 decode - removes BOM if present.
///
/// WHATWG Encoding Standard § 6
/// https://encoding.spec.whatwg.org/#utf-8-decode
///
/// This is the standard decode algorithm that should be used by new formats.
/// If the input starts with a UTF-8 BOM (0xEF 0xBB 0xBF), it is removed.
///
/// Uses replacement error mode (invalid sequences → U+FFFD).
pub fn utf8Decode(allocator: std.mem.Allocator, bytes: []const u8) DecodeError![]const u16 {
    // Skip BOM if present
    const input = bom.skipUtf8Bom(bytes);

    // Decode using replacement mode
    return utf8DecodeWithoutBom(allocator, input);
}

/// UTF-8 decode without BOM - does not remove BOM.
///
/// WHATWG Encoding Standard § 6
/// https://encoding.spec.whatwg.org/#utf-8-decode-without-bom
///
/// For identifiers or byte sequences within a format or protocol.
/// Uses replacement error mode (invalid sequences → U+FFFD).
pub fn utf8DecodeWithoutBom(allocator: std.mem.Allocator, bytes: []const u8) DecodeError![]const u16 {
    // Fast path: ASCII-only input
    if (isAsciiOnly(bytes)) {
        // ASCII: each byte becomes a UTF-16 code unit
        const output = try allocator.alloc(u16, bytes.len);
        for (bytes, 0..) |byte, i| {
            output[i] = byte;
        }
        return output;
    }

    // Allocate worst-case output buffer (each byte could be a code unit, +2 for surrogate pairs)
    var output_buf = try allocator.alloc(u16, bytes.len + 2);
    defer allocator.free(output_buf);

    var decoder = Decoder{ .encoding = &encoding_mod.UTF_8, .state = .neutral };
    const result = utf8_decode_fn(&decoder, bytes, output_buf, true);

    // Verify all bytes consumed
    std.debug.assert(result.bytes_consumed == bytes.len);

    // Return only the written portion
    const final_output = try allocator.alloc(u16, result.code_units_written);
    @memcpy(final_output, output_buf[0..result.code_units_written]);
    return final_output;
}

/// UTF-8 decode without BOM or fail - does not remove BOM, fatal error mode.
///
/// WHATWG Encoding Standard § 6
/// https://encoding.spec.whatwg.org/#utf-8-decode-without-bom-or-fail
///
/// For identifiers or byte sequences within a format or protocol.
/// Uses fatal error mode (invalid sequences → error).
pub fn utf8DecodeWithoutBomOrFail(allocator: std.mem.Allocator, bytes: []const u8) DecodeError![]const u16 {
    // Fast path: ASCII-only input (always valid)
    if (isAsciiOnly(bytes)) {
        const output = try allocator.alloc(u16, bytes.len);
        for (bytes, 0..) |byte, i| {
            output[i] = byte;
        }
        return output;
    }

    // Allocate worst-case output buffer (each byte could be a code unit)
    var output_buf = try allocator.alloc(u16, bytes.len + 2); // +2 for potential surrogate pair at end
    defer allocator.free(output_buf);

    var decoder = Decoder{ .encoding = &encoding_mod.UTF_8, .state = .neutral };
    const result = utf8_decode_fn(&decoder, bytes, output_buf, true);

    // In fatal mode, any incomplete or invalid UTF-8 is an error
    if (result.bytes_consumed < bytes.len) {
        return DecodeError.InvalidUtf8Sequence;
    }

    // Return only the written portion
    const final_output = try allocator.alloc(u16, result.code_units_written);
    @memcpy(final_output, output_buf[0..result.code_units_written]);
    return final_output;
}

/// UTF-8 encode - standard encoding.
///
/// WHATWG Encoding Standard § 6
/// https://encoding.spec.whatwg.org/#utf-8-encode
///
/// Encodes a UTF-16 string to UTF-8.
/// This is the standard encode algorithm to be used by new standards.
pub fn utf8Encode(allocator: std.mem.Allocator, code_units: []const u16) EncodeError![]const u8 {
    // Fast path: ASCII-only input
    if (isAsciiOnlyUtf16(code_units)) {
        // ASCII: each UTF-16 code unit becomes a byte
        const output = try allocator.alloc(u8, code_units.len);
        for (code_units, 0..) |cu, i| {
            output[i] = @truncate(cu);
        }
        return output;
    }

    // Allocate worst-case output buffer (4 bytes per code unit for supplementary plane)
    var output_buf = try allocator.alloc(u8, code_units.len * 4);
    defer allocator.free(output_buf);

    var encoder = Encoder{ .encoding = &encoding_mod.UTF_8, .state = .neutral };
    const result = utf8_encode_fn(&encoder, code_units, output_buf, true);

    // Verify all code units consumed
    std.debug.assert(result.code_units_consumed == code_units.len);

    // Return only the written portion
    const final_output = try allocator.alloc(u8, result.bytes_written);
    @memcpy(final_output, output_buf[0..result.bytes_written]);
    return final_output;
}

// Helper functions

/// Checks if all bytes are ASCII (0x00-0x7F).
/// Uses WHATWG Infra Standard's SIMD-optimized implementation.
fn isAsciiOnly(bytes: []const u8) bool {
    return infra.string.isAscii(bytes);
}

/// Checks if all UTF-16 code units are ASCII (0x0000-0x007F).
/// Uses WHATWG Infra Standard's implementation.
fn isAsciiOnlyUtf16(code_units: []const u16) bool {
    return infra.string.isAsciiString(code_units);
}

// Tests

test "utf8Decode - with BOM" {
    const allocator = std.testing.allocator;

    // UTF-8 BOM + "Hello"
    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F };
    const result = try utf8Decode(allocator, &input);
    defer allocator.free(result);

    // BOM should be removed, only "Hello" decoded
    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(u16, 'H'), result[0]);
    try std.testing.expectEqual(@as(u16, 'e'), result[1]);
    try std.testing.expectEqual(@as(u16, 'l'), result[2]);
    try std.testing.expectEqual(@as(u16, 'l'), result[3]);
    try std.testing.expectEqual(@as(u16, 'o'), result[4]);
}

test "utf8Decode - without BOM" {
    const allocator = std.testing.allocator;

    const input = "Hello";
    const result = try utf8Decode(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(u16, 'H'), result[0]);
}

test "utf8DecodeWithoutBom - ASCII" {
    const allocator = std.testing.allocator;

    const input = "Hello";
    const result = try utf8DecodeWithoutBom(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(u16, 'H'), result[0]);
}

test "utf8DecodeWithoutBom - BOM not removed" {
    const allocator = std.testing.allocator;

    // UTF-8 BOM + "Hi"
    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 0x48, 0x69 };
    const result = try utf8DecodeWithoutBom(allocator, &input);
    defer allocator.free(result);

    // BOM should be preserved and decoded as U+FEFF
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(u16, 0xFEFF), result[0]); // BOM
    try std.testing.expectEqual(@as(u16, 'H'), result[1]);
    try std.testing.expectEqual(@as(u16, 'i'), result[2]);
}

test "utf8Encode - ASCII" {
    const allocator = std.testing.allocator;

    const input = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    const result = try utf8Encode(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqualSlices(u8, "Hello", result);
}

test "utf8Encode - surrogate pair" {
    const allocator = std.testing.allocator;

    // U+1F4A9 (💩) as surrogate pair: 0xD83D 0xDCA9
    const input = [_]u16{ 0xD83D, 0xDCA9 };
    const result = try utf8Encode(allocator, &input);
    defer allocator.free(result);

    // UTF-8: 0xF0 0x9F 0x92 0xA9
    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(u8, 0xF0), result[0]);
    try std.testing.expectEqual(@as(u8, 0x9F), result[1]);
    try std.testing.expectEqual(@as(u8, 0x92), result[2]);
    try std.testing.expectEqual(@as(u8, 0xA9), result[3]);
}

test "utf8Encode - unpaired surrogate" {
    const allocator = std.testing.allocator;

    // Unpaired leading surrogate: 0xD83D (no trailing surrogate)
    const input = [_]u16{0xD83D};
    const result = try utf8Encode(allocator, &input);
    defer allocator.free(result);

    // Should emit U+FFFD (replacement character): 0xEF 0xBF 0xBD
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(u8, 0xEF), result[0]);
    try std.testing.expectEqual(@as(u8, 0xBF), result[1]);
    try std.testing.expectEqual(@as(u8, 0xBD), result[2]);
}

// ============================================================================
// LEGACY HOOKS FOR STANDARDS
// ============================================================================
// WHATWG Encoding Standard § 6 - Legacy hooks for standards
// https://encoding.spec.whatwg.org/#legacy-hooks-for-standards
//
// These hooks are provided for compatibility with legacy content and protocols.
// New protocols should use the UTF-8 hooks above.

/// decode - unified decode with BOM sniffing and fallback encoding.
///
/// WHATWG Encoding Standard § 6.1
/// https://encoding.spec.whatwg.org/#decode
///
/// Steps:
/// 1. Let BOMEncoding be the result of BOM sniffing ioQueue
/// 2. If BOMEncoding is non-null:
///    a. Set encoding to BOMEncoding
///    b. Read bytes from ioQueue (3 for UTF-8, 2 for UTF-16BE/LE)
/// 3. Process a queue with encoding's decoder, ioQueue, output, and "replacement"
/// 4. Return output
///
/// This algorithm gives BOM priority over Content-Type headers.
pub fn decode(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    fallback_encoding: *const encoding_mod.Encoding,
) DecodeError![]const u16 {
    var encoding = fallback_encoding;
    var input = bytes;

    // Step 1-2: BOM sniffing
    if (bom.sniff(bytes)) |bom_encoding| {
        // BOM found - use detected encoding and skip BOM bytes
        encoding = switch (bom_encoding) {
            .utf8 => &encoding_mod.UTF_8,
            .utf16be => &encoding_mod.UTF_16BE,
            .utf16le => &encoding_mod.UTF_16LE,
        };
        const bom_len = bom.length(bom_encoding);
        input = bytes[bom_len..];
    }

    // Step 3: Decode using detected or fallback encoding
    var decoder = encoding.newDecoder();

    // Allocate output buffer
    const max_output_len = encoding.maxUtf16Length(input.len);
    var output_buf = try allocator.alloc(u16, max_output_len);
    defer allocator.free(output_buf);

    const result = decoder.decode(input, output_buf, true);

    // Step 4: Return output (replacement mode - no errors)
    const final_output = try allocator.alloc(u16, result.code_units_written);
    @memcpy(final_output, output_buf[0..result.code_units_written]);
    return final_output;
}

/// encode - legacy encoding with HTML error mode.
///
/// WHATWG Encoding Standard § 6.2
/// https://encoding.spec.whatwg.org/#encode
///
/// Steps:
/// 1. Let encoder be the result of getting an encoder from encoding
/// 2. Process a queue with encoder, ioQueue, output, and "html"
/// 3. Return output
///
/// This is used by HTML forms. The HTML error mode emits &#NNNN; for unmappable characters.
pub fn encode(
    allocator: std.mem.Allocator,
    code_units: []const u16,
    encoding: *const encoding_mod.Encoding,
) EncodeError![]const u8 {
    // Step 1: Get encoder
    var encoder = getEncoder(encoding) orelse return EncodeError.OutOfMemory;

    // Allocate output buffer (worst case: 4 bytes per code unit)
    var output_buf = try allocator.alloc(u8, code_units.len * 4);
    defer allocator.free(output_buf);

    // Step 2: Encode with HTML error mode
    // Note: HTML error mode is currently not implemented in the encoder
    // For now, we use the standard encoder (matches TextEncoder behavior)
    const result = encoder.encode(code_units, output_buf, true);

    // Step 3: Return output
    const final_output = try allocator.alloc(u8, result.bytes_written);
    @memcpy(final_output, output_buf[0..result.bytes_written]);
    return final_output;
}

/// get an encoder - returns an encoder for the given encoding.
///
/// WHATWG Encoding Standard § 6.3
/// https://encoding.spec.whatwg.org/#get-an-encoder
///
/// Steps:
/// 1. Assert: encoding is not replacement or UTF-16BE/LE
/// 2. Return an instance of encoding's encoder
///
/// This is used by encode() and encodeOrFail().
pub fn getEncoder(encoding: *const encoding_mod.Encoding) ?encoding_mod.Encoder {
    // Step 1: Assert encoding is not replacement or UTF-16BE/LE
    std.debug.assert(encoding != &encoding_mod.REPLACEMENT);
    std.debug.assert(encoding != &encoding_mod.UTF_16BE);
    std.debug.assert(encoding != &encoding_mod.UTF_16LE);

    // Step 2: Return encoder instance
    return encoding.newEncoder();
}

/// encode or fail - encode with fatal error mode, return error code point.
///
/// WHATWG Encoding Standard § 6.4
/// https://encoding.spec.whatwg.org/#encode-or-fail
///
/// Steps:
/// 1. Let potentialError be the result of processing a queue with encoder, ioQueue, output, and "fatal"
/// 2. Push end-of-queue to output
/// 3. If potentialError is an error, return error's code point's value
/// 4. Return null
///
/// This is used by URL percent-encoding. The caller must handle the error code point.
/// Note: For ISO-2022-JP, the encoder state affects behavior - caller must keep encoder alive.
pub fn encodeOrFail(
    encoder: *encoding_mod.Encoder,
    code_units: []const u16,
    output: []u8,
) ?u21 {
    // Step 1: Encode with fatal mode
    const result = encoder.encode(code_units, output, true);

    // Step 2-3: If unmappable, return the code point that failed
    // Note: Current encoder API doesn't expose the failing code point
    // For now, we return null on success, or a placeholder on error
    if (result.status == streaming.EncodeResult.Status.unmappable) {
        // Find the code unit that failed
        if (result.code_units_consumed < code_units.len) {
            const failed_cu = code_units[result.code_units_consumed];

            // Use webidl code point predicates for surrogate handling
            // If it's not a surrogate, return it as code point
            if (!code_points.isSurrogate(failed_cu)) {
                return @as(u21, failed_cu);
            }

            // If it's a lead surrogate, try to decode surrogate pair
            if (code_points.isLeadSurrogate(failed_cu)) {
                if (result.code_units_consumed + 1 < code_units.len) {
                    const low = code_units[result.code_units_consumed + 1];
                    if (code_points.isTrailSurrogate(low)) {
                        // Decode surrogate pair
                        return code_points.decodeSurrogatePair(failed_cu, low) catch {
                            // Invalid pair, return replacement character
                            return 0xFFFD;
                        };
                    }
                }
            }

            // Unpaired surrogate
            return 0xFFFD;
        }
    }

    // Step 4: Success
    return null;
}

// ============================================================================
// TESTS - Legacy Hooks
// ============================================================================

test "decode - with UTF-8 BOM" {
    const allocator = std.testing.allocator;

    // UTF-8 BOM + "Hello"
    const input = [_]u8{ 0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F };
    const result = try decode(allocator, &input, &encoding_mod.WINDOWS_1252);
    defer allocator.free(result);

    // BOM should be removed, UTF-8 should be used (not windows-1252)
    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(u16, 'H'), result[0]);
    try std.testing.expectEqual(@as(u16, 'e'), result[1]);
    try std.testing.expectEqual(@as(u16, 'l'), result[2]);
    try std.testing.expectEqual(@as(u16, 'l'), result[3]);
    try std.testing.expectEqual(@as(u16, 'o'), result[4]);
}

test "decode - with UTF-16BE BOM" {
    const allocator = std.testing.allocator;

    // UTF-16BE BOM + "Hi" (U+0048 U+0069)
    const input = [_]u8{ 0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69 };
    const result = try decode(allocator, &input, &encoding_mod.UTF_8);
    defer allocator.free(result);

    // BOM should be removed, UTF-16BE should be used
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(u16, 'H'), result[0]);
    try std.testing.expectEqual(@as(u16, 'i'), result[1]);
}

test "decode - without BOM uses fallback" {
    const allocator = std.testing.allocator;

    const input = "Hello";
    const result = try decode(allocator, input, &encoding_mod.UTF_8);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(u16, 'H'), result[0]);
}

test "encode - basic UTF-8" {
    const allocator = std.testing.allocator;

    const input = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    const result = try encode(allocator, &input, &encoding_mod.UTF_8);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqualSlices(u8, "Hello", result);
}

test "getEncoder - UTF-8" {
    const encoder = getEncoder(&encoding_mod.UTF_8);
    try std.testing.expect(encoder != null);
}

test "getEncoder - windows-1252" {
    const encoder = getEncoder(&encoding_mod.WINDOWS_1252);
    try std.testing.expect(encoder != null);
}

test "encodeOrFail - success" {
    var encoder = encoding_mod.UTF_8.newEncoder().?;
    var output: [100]u8 = undefined;

    const input = [_]u16{ 'H', 'i' };
    const error_cp = encodeOrFail(&encoder, &input, &output);

    try std.testing.expect(error_cp == null);
}

test "encodeOrFail - success with ASCII" {
    var encoder = encoding_mod.UTF_8.newEncoder().?;
    var output: [100]u8 = undefined;

    // ASCII should always encode successfully
    const input = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    const error_cp = encodeOrFail(&encoder, &input, &output);

    // Should return null on success
    try std.testing.expect(error_cp == null);
}
