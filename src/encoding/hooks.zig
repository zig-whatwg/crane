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
    // Replacement error mode: the decoder reports errors, this hook substitutes
    // U+FFFD for each one. Before it did, the assertion below could not fail
    // because the decoder never stopped short.
    const result = decoder.decodeReplacement(bytes, output_buf, true);

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

    // Fatal error mode: the decoder's error is the answer. The
    // `bytes_consumed` check alone was not enough - it can only notice an
    // error that stopped the decoder, and for years the UTF-8 decoder
    // substituted U+FFFD and ran to the end, so this hook returned a string of
    // replacement characters and called it success.
    if (result.status == .malformed or result.bytes_consumed < bytes.len) {
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

    const result = decoder.decodeReplacement(input, output_buf, true);

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
///
/// WHATWG Encoding Standard § 4.1.3 (process an item, "html" mode):
/// "Push 0x26 (&), 0x23 (#), followed by the shortest sequence of 0x30 (0) to
/// 0x39 (9), inclusive, representing result's code point's value in base ten,
/// followed by 0x3B (;) to output."
pub fn encode(
    allocator: std.mem.Allocator,
    code_units: []const u16,
    encoding: *const encoding_mod.Encoding,
) EncodeError![]const u8 {
    // Step 1: Get encoder
    var encoder = getEncoder(encoding) orelse return EncodeError.OutOfMemory;

    // Build output using List for dynamic sizing (HTML escapes can be longer than input)
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    // Process code units one at a time to handle HTML error mode
    var i: usize = 0;
    while (i < code_units.len) {
        // Handle surrogate pairs
        var code_point: u21 = undefined;
        var units_consumed: usize = 1;

        const cu = code_units[i];
        if (code_points.isLeadSurrogate(cu) and i + 1 < code_units.len) {
            const low = code_units[i + 1];
            if (code_points.isTrailSurrogate(low)) {
                // Decode surrogate pair
                code_point = code_points.decodeSurrogatePair(cu, low) catch {
                    // Invalid pair - emit &#FFFD; for each
                    try appendHtmlNumericReference(&output, 0xFFFD);
                    try appendHtmlNumericReference(&output, 0xFFFD);
                    i += 2;
                    continue;
                };
                units_consumed = 2;
            } else {
                // Unpaired lead surrogate - emit replacement
                try appendHtmlNumericReference(&output, 0xFFFD);
                i += 1;
                continue;
            }
        } else if (code_points.isSurrogate(cu)) {
            // Unpaired surrogate - emit replacement
            try appendHtmlNumericReference(&output, 0xFFFD);
            i += 1;
            continue;
        } else {
            code_point = @as(u21, cu);
        }

        // Step 2: keep one encoder for the queue. ISO-2022-JP may emit a
        // designation plus a character (five bytes), or an ASCII designation
        // before returning an error. Neither output may be discarded.
        var temp_buf: [16]u8 = undefined;
        const cu_slice = code_units[i .. i + units_consumed];
        var consumed: usize = 0;
        while (true) {
            const result = encoder.encode(cu_slice[consumed..], &temp_buf, false);
            try output.appendSlice(temp_buf[0..result.bytes_written]);
            consumed += result.code_units_consumed;
            switch (result.status) {
                .input_empty => break,
                .output_full => {
                    // The buffer fits the largest indivisible encoder unit.
                    std.debug.assert(result.bytes_written != 0 or result.code_units_consumed != 0);
                },
                .unmappable => {
                    // Process an item, HTML mode: use the handler's error
                    // code point (ISO-2022-JP reports ESC as U+FFFD).
                    try appendHtmlNumericReference(&output, if (result.error_code_point != 0) result.error_code_point else code_point);
                    break;
                },
            }
        }

        i += units_consumed;
    }

    // Process the queue's single end-of-queue item after all its scalars.
    // ISO-2022-JP encoder steps 1–2 emit the final ASCII designation here.
    var tail: [16]u8 = undefined;
    while (true) {
        const result = encoder.encode(&.{}, &tail, true);
        try output.appendSlice(tail[0..result.bytes_written]);
        switch (result.status) {
            .input_empty => break,
            .output_full => std.debug.assert(result.bytes_written != 0),
            .unmappable => {
                try appendHtmlNumericReference(&output, result.error_code_point);
                break;
            },
        }
    }

    return output.toOwnedSlice();
}

/// Append an HTML numeric character reference (&#NNNN;) to output
///
/// WHATWG Encoding Standard § 4.1.3
/// "Push 0x26 (&), 0x23 (#), followed by the shortest sequence of 0x30 (0) to
/// 0x39 (9), inclusive, representing result's code point's value in base ten,
/// followed by 0x3B (;) to output."
fn appendHtmlNumericReference(output: *infra.List(u8), code_point: u21) !void {
    // &# prefix
    try output.append('&');
    try output.append('#');

    // Convert code point to decimal string (shortest representation)
    var buf: [10]u8 = undefined; // Max 10 digits for u21 (max 1114111 = 7 digits)
    var len: usize = 0;
    var value = code_point;

    if (value == 0) {
        buf[0] = '0';
        len = 1;
    } else {
        // Build digits in reverse
        while (value > 0) : (len += 1) {
            buf[len] = @intCast('0' + @as(u8, @intCast(value % 10)));
            value /= 10;
        }
        // Reverse the digits
        var left: usize = 0;
        var right: usize = len - 1;
        while (left < right) {
            const tmp = buf[left];
            buf[left] = buf[right];
            buf[right] = tmp;
            left += 1;
            right -= 1;
        }
    }

    // Append decimal digits
    try output.appendSlice(buf[0..len]);

    // ; suffix
    try output.append(';');
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

    // Steps 2-3: return the handler's scalar, not a UTF-16 code unit at
    // its input cursor. A supplementary error can span two input calls.
    if (result.status == .unmappable) return result.error_code_point;

    // Step 4: Success
    return null;
}

// ============================================================================
// TESTS - Legacy Hooks
// ============================================================================
