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
const infra = @import("infra");
const mimesniff = @import("mimesniff");

/// Result of processing a data: URL.
pub const DataUrlResult = struct {
    allocator: Allocator,
    /// The MIME type record, serialized to bytes (MIME Sniffing "serialize a
    /// MIME type to bytes"). OWNED.
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
/// Fetch 6, "the data: URL processor", given a URL `dataURL` (here its
/// serialization, `url_str`). Each step is numbered below as the spec numbers
/// it. The struct's MIME type is a MIME type record; `mime_type` holds it
/// serialized to bytes (MIME Sniffing "serialize a MIME type to bytes"), the
/// form scheme fetch "data" step 3 puts in the response's `Content-Type`.
pub fn processDataUrl(allocator: Allocator, url_str: []const u8) DataUrlError!?DataUrlResult {
    // 1. Assert: dataURL's scheme is "data".
    if (!std.ascii.startsWithIgnoreCase(url_str, "data:")) {
        return DataUrlError.NotDataUrl;
    }

    // 2. Let input be the result of running the URL serializer on dataURL
    // with exclude fragment set to true.
    // 3. Remove the leading "data:" from input.
    // (Done before finding the comma or percent-decoding: an escaped # belongs
    // to the body, while a comma in the fragment cannot delimit it.)
    const input_end = std.mem.indexOfScalar(u8, url_str, '#') orelse url_str.len;
    const input = url_str[5..input_end];

    // 4. Let position point at the start of input.
    // 5. Let mimeType be the result of collecting a sequence of code points
    // that are not equal to U+002C (,), given position.
    // 7. If position is past the end of input, then return failure.
    const comma_pos = std.mem.indexOfScalar(u8, input, ',') orelse return DataUrlError.MissingComma;

    // 6. Strip leading and trailing ASCII whitespace from mimeType.
    var mime_type = std.mem.trim(u8, input[0..comma_pos], " \t\n\r\x0c");

    // 8. Advance position by 1.
    // 9. Let encodedBody be the remainder of input.
    const encoded_body = input[comma_pos + 1 ..];

    // 10. Let body be the percent-decoding of encodedBody.
    var body = try percentDecode(allocator, encoded_body);
    errdefer allocator.free(body);

    // 11. If mimeType ends with U+003B (;), followed by zero or more U+0020
    // SPACE, followed by an ASCII case-insensitive match for "base64", then:
    if (base64MarkerStart(mime_type)) |semicolon| {
        // 11.1. Let stringBody be the isomorphic decode of body.
        // 11.2. Set body to the forgiving-base64 decode of stringBody.
        // (Forgiving-base64 decode reads code points; isomorphic decoding
        // maps each byte to the code point of its value, which this decoder
        // reads byte for byte.)
        const decoded = infra.base64.forgivingBase64Decode(allocator, body) catch |err| switch (err) {
            // 11.3. If body is failure, then return failure.
            error.InvalidBase64 => return DataUrlError.Base64DecodeFailed,
            error.OutOfMemory => return error.OutOfMemory,
        };
        allocator.free(body);
        body = decoded;
        // 11.4. Remove the last 6 code points from mimeType.
        // 11.5. Remove trailing U+0020 SPACE code points from mimeType, if any.
        // 11.6. Remove the last U+003B (;) from mimeType.
        mime_type = mime_type[0..semicolon];
    }

    // 12. If mimeType starts with ";", then prepend "text/plain" to mimeType.
    const prepended = if (std.mem.startsWith(u8, mime_type, ";"))
        try std.fmt.allocPrint(allocator, "text/plain{s}", .{mime_type})
    else
        null;
    defer if (prepended) |owned| allocator.free(owned);

    // 13. Let mimeTypeRecord be the result of parsing mimeType.
    // 14. If mimeTypeRecord is failure, then set mimeTypeRecord to
    // text/plain;charset=US-ASCII.
    const serialized = try serializedMimeType(allocator, prepended orelse mime_type);

    // 15. Return a new data: URL struct whose MIME type is mimeTypeRecord and
    // body is body.
    return DataUrlResult{
        .allocator = allocator,
        .mime_type = serialized,
        .body = body,
    };
}

/// Step 11's test: where the ";" of a base64 marker at the end of
/// `mime_type` is - a U+003B (;), then zero or more U+0020 SPACE, then
/// "base64" in ASCII case-insensitive - or null when it has none.
fn base64MarkerStart(mime_type: []const u8) ?usize {
    const marker = "base64";
    if (mime_type.len < marker.len + 1) return null;
    if (!std.ascii.eqlIgnoreCase(mime_type[mime_type.len - marker.len ..], marker)) return null;
    var index = mime_type.len - marker.len;
    while (index > 0 and mime_type[index - 1] == ' ') index -= 1;
    if (index == 0 or mime_type[index - 1] != ';') return null;
    return index - 1;
}

/// Steps 13-14: `mime_type` parsed (MIME Sniffing "parse a MIME type" - the
/// string is isomorphic decoded first, as each of its bytes is a code point)
/// and serialized to bytes; text/plain;charset=US-ASCII when it does not
/// parse. OWNED.
fn serializedMimeType(allocator: Allocator, mime_type: []const u8) error{OutOfMemory}![]const u8 {
    const failure = "text/plain;charset=US-ASCII";
    const parsed = mimesniff.mime_type.parseMimeType(allocator, mime_type) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => null,
    };
    var record = parsed orelse return allocator.dupe(u8, failure);
    defer record.deinit();
    return mimesniff.mime_type.serializeMimeTypeToBytes(allocator, record) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        // Isomorphic encoding cannot fail here: every code point of the
        // record came from isomorphic decoding a byte.
        else => allocator.dupe(u8, failure),
    };
}

/// Percent-decode a string.
/// Converts %XX sequences to their byte values.
fn percentDecode(allocator: Allocator, input: []const u8) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
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
