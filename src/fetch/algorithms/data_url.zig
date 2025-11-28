//! Data URL Processor - WHATWG Fetch Specification
//!
//! This module implements the data: URL processor per Fetch spec.
//!
//! Spec: https://fetch.spec.whatwg.org/#data-url-processor
//!
//! Data URLs have the format:
//!   data:[<mediatype>][;base64],<data>
//!
//! Examples:
//!   data:text/plain;base64,SGVsbG8gV29ybGQh
//!   data:text/html,%3Ch1%3EHello%3C%2Fh1%3E
//!   data:,Hello%2C%20World!

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Result of processing a data: URL.
pub const DataUrlResult = struct {
    allocator: Allocator,
    /// The MIME type string
    mime_type: []const u8,
    /// The decoded body bytes
    body: []const u8,

    pub fn deinit(self: *DataUrlResult) void {
        self.allocator.free(self.mime_type);
        self.allocator.free(self.body);
    }
};

/// Error types for data URL processing.
pub const DataUrlError = error{
    /// URL scheme is not "data"
    NotDataUrl,
    /// Missing comma separator
    MissingComma,
    /// Base64 decoding failed
    Base64DecodeFailed,
    /// Out of memory
    OutOfMemory,
};

/// Process a data: URL and extract its MIME type and body.
///
/// Algorithm per Fetch spec:
/// 1. Assert: url's scheme is "data"
/// 2. Let input be the result of running the URL serializer on url with
///    exclude fragment set to true
/// 3. Remove the leading "data:" from input
/// 4. Let position be a position variable for input, initially pointing at
///    the start of input
/// 5. Let mimeType be the result of collecting a sequence of code points
///    that are not equal to U+002C (,) from input, given position
/// 6. Strip leading and trailing ASCII whitespace from mimeType
/// 7. If position is past the end of input, then return failure
/// 8. Advance position by 1
/// 9. Let encodedBody be the remainder of input
/// 10. Let body = encodedBody
/// 11. If mimeType ends with U+003B (;), followed by a sequence of code points
///     equal to "base64" in ASCII case-insensitive:
///     a. Let stringBody be the isomorphic decode of the result of
///        percent-decoding encodedBody
///     b. Set body to the result of forgiving-base64 decode stringBody
///     c. If body is failure, return failure
///     d. Remove the last 7 code points from mimeType (";base64")
/// 12. Otherwise:
///     a. Set body to the percent-decoding of encodedBody
/// 13. If mimeType starts with U+003B (;), prepend "text/plain" to mimeType
/// 14. Let mimeTypeRecord be the result of parsing mimeType
/// 15. If mimeTypeRecord is failure, set mimeTypeRecord to text/plain;charset=US-ASCII
/// 16. Return (mimeTypeRecord, body)
pub fn processDataUrl(allocator: Allocator, url_str: []const u8) DataUrlError!?DataUrlResult {
    // Step 1: Verify this is a data: URL
    if (!std.ascii.startsWithIgnoreCase(url_str, "data:")) {
        return DataUrlError.NotDataUrl;
    }

    // Step 2-3: Remove "data:" prefix
    const input = url_str[5..];

    // Step 4-5: Find the comma separator
    const comma_pos = std.mem.indexOf(u8, input, ",") orelse {
        // Step 7: No comma found
        return DataUrlError.MissingComma;
    };

    // Step 5-6: Extract and trim MIME type
    var mime_type_raw = std.mem.trim(u8, input[0..comma_pos], " \t\n\r\x0c");

    // Step 8-9: Get encoded body (after comma)
    const encoded_body = input[comma_pos + 1 ..];

    // Step 10-12: Decode body
    var body: []const u8 = undefined;
    var is_base64 = false;
    var mime_type_end = mime_type_raw.len;

    // Step 11: Check for ;base64 suffix (case-insensitive)
    if (mime_type_raw.len >= 7) {
        const suffix_start = mime_type_raw.len - 7;
        const suffix = mime_type_raw[suffix_start..];
        if (std.ascii.eqlIgnoreCase(suffix, ";base64")) {
            is_base64 = true;
            mime_type_end = suffix_start;
        }
    }

    if (is_base64) {
        // Step 11a: Percent-decode first, then base64 decode
        const percent_decoded = try percentDecode(allocator, encoded_body);
        defer allocator.free(percent_decoded);

        body = forgivingBase64Decode(allocator, percent_decoded) catch {
            return DataUrlError.Base64DecodeFailed;
        };
    } else {
        // Step 12: Just percent-decode
        body = try percentDecode(allocator, encoded_body);
    }
    errdefer allocator.free(body);

    // Step 13-15: Process MIME type
    var final_mime_type: []const u8 = undefined;
    const trimmed_mime = std.mem.trim(u8, mime_type_raw[0..mime_type_end], " \t\n\r\x0c");

    if (trimmed_mime.len == 0 or trimmed_mime[0] == ';') {
        // Step 13: Empty or starts with ; - prepend text/plain
        if (trimmed_mime.len == 0) {
            final_mime_type = try allocator.dupe(u8, "text/plain;charset=US-ASCII");
        } else {
            // Prepend "text/plain" to existing parameters
            final_mime_type = try std.fmt.allocPrint(allocator, "text/plain{s}", .{trimmed_mime});
        }
    } else {
        // Use as-is
        final_mime_type = try allocator.dupe(u8, trimmed_mime);
    }

    return DataUrlResult{
        .allocator = allocator,
        .mime_type = final_mime_type,
        .body = body,
    };
}

/// Percent-decode a string.
/// Converts %XX sequences to their byte values.
fn percentDecode(allocator: Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex = input[i + 1 .. i + 3];
            if (isHexDigit(hex[0]) and isHexDigit(hex[1])) {
                const byte = (hexValue(hex[0]) << 4) | hexValue(hex[1]);
                try result.append(allocator, byte);
                i += 3;
                continue;
            }
        }
        try result.append(allocator, input[i]);
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

fn isHexDigit(c: u8) bool {
    return (c >= '0' and c <= '9') or
        (c >= 'a' and c <= 'f') or
        (c >= 'A' and c <= 'F');
}

fn hexValue(c: u8) u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    unreachable;
}

/// Forgiving base64 decode per WHATWG Infra spec.
/// Strips ASCII whitespace before decoding.
fn forgivingBase64Decode(allocator: Allocator, encoded: []const u8) ![]const u8 {
    // Count non-whitespace characters
    var count: usize = 0;
    for (encoded) |c| {
        if (!isAsciiWhitespace(c)) count += 1;
    }

    // Strip whitespace
    const stripped = try allocator.alloc(u8, count);
    defer allocator.free(stripped);

    var idx: usize = 0;
    for (encoded) |c| {
        if (!isAsciiWhitespace(c)) {
            stripped[idx] = c;
            idx += 1;
        }
    }

    // Decode
    const decoder = std.base64.standard.Decoder;
    const decoded_len = try decoder.calcSizeForSlice(stripped);
    const result = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(result);

    try decoder.decode(result, stripped);
    return result;
}

fn isAsciiWhitespace(c: u8) bool {
    return c == 0x09 or c == 0x0A or c == 0x0C or c == 0x0D or c == 0x20;
}

// =============================================================================
// Tests
// =============================================================================

test "processDataUrl - plain text" {
    const allocator = std.testing.allocator;

    var result = (try processDataUrl(allocator, "data:,Hello%2C%20World!")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/plain;charset=US-ASCII", result.mime_type);
    try std.testing.expectEqualStrings("Hello, World!", result.body);
}

test "processDataUrl - with explicit MIME type" {
    const allocator = std.testing.allocator;

    var result = (try processDataUrl(allocator, "data:text/html,%3Ch1%3EHello%3C%2Fh1%3E")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/html", result.mime_type);
    try std.testing.expectEqualStrings("<h1>Hello</h1>", result.body);
}

test "processDataUrl - base64 encoded" {
    const allocator = std.testing.allocator;

    // "Hello World!" in base64
    var result = (try processDataUrl(allocator, "data:text/plain;base64,SGVsbG8gV29ybGQh")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/plain", result.mime_type);
    try std.testing.expectEqualStrings("Hello World!", result.body);
}

test "processDataUrl - base64 case insensitive" {
    const allocator = std.testing.allocator;

    var result = (try processDataUrl(allocator, "data:text/plain;BASE64,SGVsbG8gV29ybGQh")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/plain", result.mime_type);
    try std.testing.expectEqualStrings("Hello World!", result.body);
}

test "processDataUrl - MIME type with parameters" {
    const allocator = std.testing.allocator;

    var result = (try processDataUrl(allocator, "data:text/html;charset=utf-8,%3Cp%3E%C3%A9%3C%2Fp%3E")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/html;charset=utf-8", result.mime_type);
}

test "processDataUrl - semicolon only prepends text/plain" {
    const allocator = std.testing.allocator;

    var result = (try processDataUrl(allocator, "data:;charset=utf-8,test")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/plain;charset=utf-8", result.mime_type);
    try std.testing.expectEqualStrings("test", result.body);
}

test "processDataUrl - not a data URL" {
    const allocator = std.testing.allocator;

    const result = processDataUrl(allocator, "https://example.com");
    try std.testing.expectError(DataUrlError.NotDataUrl, result);
}

test "processDataUrl - missing comma" {
    const allocator = std.testing.allocator;

    const result = processDataUrl(allocator, "data:text/plain");
    try std.testing.expectError(DataUrlError.MissingComma, result);
}

test "processDataUrl - empty body" {
    const allocator = std.testing.allocator;

    var result = (try processDataUrl(allocator, "data:text/plain,")).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("text/plain", result.mime_type);
    try std.testing.expectEqualStrings("", result.body);
}

test "processDataUrl - image data" {
    const allocator = std.testing.allocator;

    // Small 1x1 transparent GIF
    const gif_base64 = "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
    const url = try std.fmt.allocPrint(allocator, "data:image/gif;base64,{s}", .{gif_base64});
    defer allocator.free(url);

    var result = (try processDataUrl(allocator, url)).?;
    defer result.deinit();

    try std.testing.expectEqualStrings("image/gif", result.mime_type);
    try std.testing.expect(result.body.len > 0);
}

test "processDataUrl - invalid base64" {
    const allocator = std.testing.allocator;

    const result = processDataUrl(allocator, "data:text/plain;base64,!!invalid!!");
    try std.testing.expectError(DataUrlError.Base64DecodeFailed, result);
}

test "percentDecode - basic" {
    const allocator = std.testing.allocator;

    const result = try percentDecode(allocator, "Hello%20World%21");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "percentDecode - no encoding" {
    const allocator = std.testing.allocator;

    const result = try percentDecode(allocator, "Hello World");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}

test "percentDecode - incomplete sequence" {
    const allocator = std.testing.allocator;

    const result = try percentDecode(allocator, "Hello%2");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello%2", result);
}

test "percentDecode - invalid hex" {
    const allocator = std.testing.allocator;

    const result = try percentDecode(allocator, "Hello%GG");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello%GG", result);
}
