//! Header Validation Algorithms - WHATWG Fetch Standard
//!
//! This module implements all header validation algorithms from the Fetch spec.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-headers

const std = @import("std");
const Allocator = std.mem.Allocator;
const HeaderList = @import("header_list.zig").HeaderList;

// =============================================================================
// Header Name Validation
// =============================================================================

/// A header name is a byte sequence that matches the field-name token production.
/// field-name = token
/// token = 1*tchar
/// tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." /
///         "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-name
pub fn isValidHeaderName(name: []const u8) bool {
    if (name.len == 0) return false;

    for (name) |byte| {
        if (!isTokenChar(byte)) {
            return false;
        }
    }
    return true;
}

/// Check if a byte is a valid token character (tchar).
/// tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." /
///         "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
fn isTokenChar(byte: u8) bool {
    return switch (byte) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        '0'...'9' => true, // DIGIT
        'A'...'Z', 'a'...'z' => true, // ALPHA
        else => false,
    };
}

// =============================================================================
// Header Value Validation
// =============================================================================

/// A header value is a byte sequence that:
/// - Has no leading or trailing HTTP tab or space bytes
/// - Contains no 0x00 (NUL) or HTTP newline bytes (0x0A LF, 0x0D CR)
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-value
pub fn isValidHeaderValue(value: []const u8) bool {
    // Check for leading HTTP whitespace
    if (value.len > 0 and (value[0] == 0x09 or value[0] == 0x20)) {
        return false;
    }

    // Check for trailing HTTP whitespace
    if (value.len > 0 and (value[value.len - 1] == 0x09 or value[value.len - 1] == 0x20)) {
        return false;
    }

    // Check for NUL or HTTP newline bytes
    for (value) |byte| {
        if (byte == 0x00 or byte == 0x0A or byte == 0x0D) {
            return false;
        }
    }

    return true;
}

// =============================================================================
// CORS-Unsafe Request Header Bytes
// =============================================================================

/// A CORS-unsafe request-header byte is a byte for which one of the following is true:
/// - byte is less than 0x20 and is not 0x09 HT
/// - byte is 0x22 ("), 0x28 ((), 0x29 ()), 0x3A (:), 0x3C (<), 0x3E (>), 0x3F (?),
///   0x40 (@), 0x5B ([), 0x5C (\), 0x5D (]), 0x7B ({), 0x7D (}), or 0x7F DEL
///
/// Spec: https://fetch.spec.whatwg.org/#cors-unsafe-request-header-byte
pub fn isCORSUnsafeByte(byte: u8) bool {
    // byte < 0x20 and not 0x09
    if (byte < 0x20 and byte != 0x09) {
        return true;
    }

    return switch (byte) {
        0x22, // "
        0x28, // (
        0x29, // )
        0x3A, // :
        0x3C, // <
        0x3E, // >
        0x3F, // ?
        0x40, // @
        0x5B, // [
        0x5C, // \
        0x5D, // ]
        0x7B, // {
        0x7D, // }
        0x7F, // DEL
        => true,
        else => false,
    };
}

/// Check if a value contains any CORS-unsafe request-header bytes.
pub fn containsCORSUnsafeBytes(value: []const u8) bool {
    for (value) |byte| {
        if (isCORSUnsafeByte(byte)) {
            return true;
        }
    }
    return false;
}

// =============================================================================
// Accept-Language/Content-Language Validation
// =============================================================================

/// Check if a byte is valid for Accept-Language/Content-Language header values.
/// Valid bytes: 0x30-0x39 (0-9), 0x41-0x5A (A-Z), 0x61-0x7A (a-z),
/// 0x20 (SP), 0x2A (*), 0x2C (,), 0x2D (-), 0x2E (.), 0x3B (;), 0x3D (=)
fn isLanguageHeaderByte(byte: u8) bool {
    return switch (byte) {
        '0'...'9', 'A'...'Z', 'a'...'z' => true,
        ' ', '*', ',', '-', '.', ';', '=' => true,
        else => false,
    };
}

/// Check if all bytes in value are valid for language headers.
fn isValidLanguageHeaderValue(value: []const u8) bool {
    for (value) |byte| {
        if (!isLanguageHeaderByte(byte)) {
            return false;
        }
    }
    return true;
}

// =============================================================================
// CORS-Safelisted Request Headers
// =============================================================================

/// Check if (name, value) is a CORS-safelisted request-header.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-safelisted-request-header
pub fn isCORSSafelistedRequestHeader(name: []const u8, value: []const u8) bool {
    // Step 1: If value's length > 128, return false
    if (value.len > 128) {
        return false;
    }

    // Step 2: Switch on byte-lowercased name
    if (std.ascii.eqlIgnoreCase(name, "accept")) {
        // If value contains a CORS-unsafe byte, return false
        return !containsCORSUnsafeBytes(value);
    }

    if (std.ascii.eqlIgnoreCase(name, "accept-language") or
        std.ascii.eqlIgnoreCase(name, "content-language"))
    {
        // Check for valid language header bytes
        return isValidLanguageHeaderValue(value);
    }

    if (std.ascii.eqlIgnoreCase(name, "content-type")) {
        // Step 1: If value contains a CORS-unsafe byte, return false
        if (containsCORSUnsafeBytes(value)) {
            return false;
        }

        // Step 2-4: Parse MIME type and check essence
        // Simple parsing: extract the essence (type/subtype before any parameters)
        const essence = extractMimeEssence(value);

        // Check if essence is one of the allowed types
        if (std.ascii.eqlIgnoreCase(essence, "application/x-www-form-urlencoded") or
            std.ascii.eqlIgnoreCase(essence, "multipart/form-data") or
            std.ascii.eqlIgnoreCase(essence, "text/plain"))
        {
            return true;
        }

        return false;
    }

    if (std.ascii.eqlIgnoreCase(name, "range")) {
        // Parse range header and check if it's a simple range
        return isSimpleRangeHeader(value);
    }

    // Otherwise return false
    return false;
}

/// Extract the MIME essence (type/subtype) from a Content-Type value.
/// This is a simplified parser that extracts the part before any semicolon.
fn extractMimeEssence(value: []const u8) []const u8 {
    // Find the first semicolon (parameter separator)
    for (value, 0..) |byte, i| {
        if (byte == ';') {
            // Trim any trailing whitespace
            var end = i;
            while (end > 0 and (value[end - 1] == ' ' or value[end - 1] == '\t')) {
                end -= 1;
            }
            return value[0..end];
        }
    }
    // No parameters, return trimmed value
    var end = value.len;
    while (end > 0 and (value[end - 1] == ' ' or value[end - 1] == '\t')) {
        end -= 1;
    }
    return value[0..end];
}

/// Check if a Range header value is a "simple range" (bytes=N-M where N is provided).
/// Spec requires that rangeValue[0] is not null (i.e., start is specified).
fn isSimpleRangeHeader(value: []const u8) bool {
    // Must start with "bytes="
    const prefix = "bytes=";
    if (value.len < prefix.len) return false;

    if (!std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix)) {
        return false;
    }

    const range_spec = value[prefix.len..];

    // Find the hyphen
    var hyphen_pos: ?usize = null;
    for (range_spec, 0..) |byte, i| {
        if (byte == '-') {
            hyphen_pos = i;
            break;
        }
    }

    const dash = hyphen_pos orelse return false;

    // The part before the dash must have at least one digit (not be empty)
    // This ensures rangeValue[0] is not null
    if (dash == 0) {
        return false; // bytes=-500 is not safelisted
    }

    // Validate that the start is all digits
    for (range_spec[0..dash]) |byte| {
        if (byte < '0' or byte > '9') {
            return false;
        }
    }

    // The end part (after dash) can be empty or digits
    const end_part = range_spec[dash + 1 ..];
    for (end_part) |byte| {
        if (byte < '0' or byte > '9') {
            return false;
        }
    }

    return true;
}

// =============================================================================
// CORS-Unsafe Request Header Names
// =============================================================================

/// Get the CORS-unsafe request-header names from a header list.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-unsafe-request-header-names
pub fn getCORSUnsafeRequestHeaderNames(allocator: Allocator, headers: *const HeaderList) ![]const []const u8 {
    var unsafe_names = std.ArrayListUnmanaged([]const u8){};
    defer unsafe_names.deinit(allocator);
    errdefer {
        for (unsafe_names.items) |n| allocator.free(n);
    }

    var potentially_unsafe_names = std.ArrayListUnmanaged([]const u8){};
    defer {
        for (potentially_unsafe_names.items) |n| allocator.free(n);
        potentially_unsafe_names.deinit(allocator);
    }

    var safelist_value_size: usize = 0;

    // Step 4: For each header
    for (headers.entries.items) |header| {
        if (!isCORSSafelistedRequestHeader(header.name, header.value)) {
            // Not safelisted, add to unsafe names
            try unsafe_names.append(allocator, try allocator.dupe(u8, header.name));
        } else {
            // Safelisted, add to potentially unsafe and count size
            try potentially_unsafe_names.append(allocator, try allocator.dupe(u8, header.name));
            safelist_value_size += header.value.len;
        }
    }

    // Step 5: If safelistValueSize > 1024, all potentially unsafe become unsafe
    if (safelist_value_size > 1024) {
        for (potentially_unsafe_names.items) |name| {
            try unsafe_names.append(allocator, try allocator.dupe(u8, name));
        }
    }

    // Step 6: Convert to sorted-lowercase set
    // The function will free the input names after lowercasing them
    const result = try convertToSortedLowercaseSet(allocator, unsafe_names.items);

    // Free the original names (convertToSortedLowercaseSet creates new lowercase copies)
    for (unsafe_names.items) |n| allocator.free(n);

    return result;
}

/// Convert header names to a sorted-lowercase set.
fn convertToSortedLowercaseSet(allocator: Allocator, names: []const []const u8) ![]const []const u8 {
    var set = std.StringHashMap(void).init(allocator);
    defer set.deinit();

    var result = std.ArrayListUnmanaged([]const u8){};
    errdefer {
        for (result.items) |n| allocator.free(n);
        result.deinit(allocator);
    }

    for (names) |name| {
        const lower = try std.ascii.allocLowerString(allocator, name);
        errdefer allocator.free(lower);

        if (!set.contains(lower)) {
            try set.put(lower, {});
            try result.append(allocator, lower);
        } else {
            allocator.free(lower);
        }
    }

    // Sort
    std.mem.sort([]const u8, result.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    return try result.toOwnedSlice(allocator);
}

// =============================================================================
// Forbidden Request Headers
// =============================================================================

/// List of forbidden request-header names (always forbidden).
const FORBIDDEN_REQUEST_HEADERS = [_][]const u8{
    "accept-charset",
    "accept-encoding",
    "access-control-request-headers",
    "access-control-request-method",
    "connection",
    "content-length",
    "cookie",
    "cookie2",
    "date",
    "dnt",
    "expect",
    "host",
    "keep-alive",
    "origin",
    "referer",
    "set-cookie",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
    "via",
};

/// List of forbidden methods (CONNECT, TRACE, TRACK).
const FORBIDDEN_METHODS = [_][]const u8{ "connect", "trace", "track" };

/// Check if (name, value) is a forbidden request-header.
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-request-header
pub fn isForbiddenRequestHeader(name: []const u8, value: []const u8) bool {
    // Step 1: Check against always-forbidden names
    for (FORBIDDEN_REQUEST_HEADERS) |forbidden| {
        if (std.ascii.eqlIgnoreCase(name, forbidden)) {
            return true;
        }
    }

    // Step 2: Check Proxy-* and Sec-* prefixes
    if (name.len >= 6) {
        if (std.ascii.eqlIgnoreCase(name[0..6], "proxy-")) {
            return true;
        }
    }
    if (name.len >= 4) {
        if (std.ascii.eqlIgnoreCase(name[0..4], "sec-")) {
            return true;
        }
    }

    // Step 3: Check X-HTTP-Method* headers with forbidden method values
    if (std.ascii.eqlIgnoreCase(name, "x-http-method") or
        std.ascii.eqlIgnoreCase(name, "x-http-method-override") or
        std.ascii.eqlIgnoreCase(name, "x-method-override"))
    {
        // Parse and check for forbidden methods
        // Simple comma-split (spec uses get, decode, and split)
        var iter = std.mem.splitSequence(u8, value, ",");
        while (iter.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " \t");
            for (FORBIDDEN_METHODS) |forbidden| {
                if (std.ascii.eqlIgnoreCase(trimmed, forbidden)) {
                    return true;
                }
            }
        }
    }

    // Step 4: Return false
    return false;
}

// =============================================================================
// Forbidden Response Headers
// =============================================================================

/// Check if name is a forbidden response-header name.
/// Forbidden: Set-Cookie, Set-Cookie2
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-response-header-name
pub fn isForbiddenResponseHeaderName(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "set-cookie") or
        std.ascii.eqlIgnoreCase(name, "set-cookie2");
}

// =============================================================================
// No-CORS-Safelisted Request Headers
// =============================================================================

/// No-CORS-safelisted request-header names.
const NO_CORS_SAFELISTED_NAMES = [_][]const u8{
    "accept",
    "accept-language",
    "content-language",
    "content-type",
};

/// Check if name is a no-CORS-safelisted request-header name.
pub fn isNoCORSSafelistedRequestHeaderName(name: []const u8) bool {
    for (NO_CORS_SAFELISTED_NAMES) |safelisted| {
        if (std.ascii.eqlIgnoreCase(name, safelisted)) {
            return true;
        }
    }
    return false;
}

/// Check if (name, value) is a no-CORS-safelisted request-header.
///
/// Spec: https://fetch.spec.whatwg.org/#no-cors-safelisted-request-header
pub fn isNoCORSSafelistedRequestHeader(name: []const u8, value: []const u8) bool {
    // Step 1: If name is not a no-CORS-safelisted request-header name, return false
    if (!isNoCORSSafelistedRequestHeaderName(name)) {
        return false;
    }

    // Step 2: Return whether (name, value) is a CORS-safelisted request-header
    return isCORSSafelistedRequestHeader(name, value);
}

// =============================================================================
// CORS-Safelisted Response Headers
// =============================================================================

/// Default CORS-safelisted response-header names.
const DEFAULT_CORS_SAFELISTED_RESPONSE_HEADERS = [_][]const u8{
    "cache-control",
    "content-language",
    "content-length",
    "content-type",
    "expires",
    "last-modified",
    "pragma",
};

/// Check if name is a CORS-safelisted response-header name.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-safelisted-response-header-name
pub fn isCORSSafelistedResponseHeaderName(name: []const u8, exposed_list: []const []const u8) bool {
    // Check default list
    for (DEFAULT_CORS_SAFELISTED_RESPONSE_HEADERS) |safelisted| {
        if (std.ascii.eqlIgnoreCase(name, safelisted)) {
            return true;
        }
    }

    // Check exposed list (if not forbidden response header)
    for (exposed_list) |exposed| {
        if (std.ascii.eqlIgnoreCase(name, exposed)) {
            if (!isForbiddenResponseHeaderName(exposed)) {
                return true;
            }
        }
    }

    return false;
}

// =============================================================================
// Request-Body Header Names
// =============================================================================

/// Request-body-header names.
const REQUEST_BODY_HEADER_NAMES = [_][]const u8{
    "content-encoding",
    "content-language",
    "content-location",
    "content-type",
};

/// Check if name is a request-body-header name.
///
/// Spec: https://fetch.spec.whatwg.org/#request-body-header-name
pub fn isRequestBodyHeaderName(name: []const u8) bool {
    for (REQUEST_BODY_HEADER_NAMES) |body_header| {
        if (std.ascii.eqlIgnoreCase(name, body_header)) {
            return true;
        }
    }
    return false;
}

// =============================================================================
// CORS Non-Wildcard Request Headers
// =============================================================================

/// Check if name is a CORS non-wildcard request-header name.
/// Currently only: Authorization
///
/// Spec: https://fetch.spec.whatwg.org/#cors-non-wildcard-request-header-name
pub fn isCORSNonWildcardRequestHeaderName(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "authorization");
}

// =============================================================================
// Privileged No-CORS Request Headers
// =============================================================================

/// Check if name is a privileged no-CORS request-header name.
/// Currently only: Range
///
/// Spec: https://fetch.spec.whatwg.org/#privileged-no-cors-request-header-name
pub fn isPrivilegedNoCORSRequestHeaderName(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "range");
}

// =============================================================================
// Tests
// =============================================================================

test "isValidHeaderName: valid names" {
    try std.testing.expect(isValidHeaderName("Content-Type"));
    try std.testing.expect(isValidHeaderName("Accept"));
    try std.testing.expect(isValidHeaderName("X-Custom-Header"));
    try std.testing.expect(isValidHeaderName("x-request-id"));
    try std.testing.expect(isValidHeaderName("Cache-Control"));
}

test "isValidHeaderName: invalid names" {
    try std.testing.expect(!isValidHeaderName("")); // empty
    try std.testing.expect(!isValidHeaderName("Content Type")); // space
    try std.testing.expect(!isValidHeaderName("Content:Type")); // colon
    try std.testing.expect(!isValidHeaderName("Content\nType")); // newline
    try std.testing.expect(!isValidHeaderName("Content\x00Type")); // NUL
}

test "isValidHeaderValue: valid values" {
    try std.testing.expect(isValidHeaderValue("text/html"));
    try std.testing.expect(isValidHeaderValue(""));
    try std.testing.expect(isValidHeaderValue("hello world"));
    try std.testing.expect(isValidHeaderValue("value\twith\ttabs"));
}

test "isValidHeaderValue: invalid values" {
    try std.testing.expect(!isValidHeaderValue(" leading space"));
    try std.testing.expect(!isValidHeaderValue("trailing space "));
    try std.testing.expect(!isValidHeaderValue("\tleading tab"));
    try std.testing.expect(!isValidHeaderValue("has\x00null"));
    try std.testing.expect(!isValidHeaderValue("has\nnewline"));
    try std.testing.expect(!isValidHeaderValue("has\rcarriage"));
}

test "containsCORSUnsafeBytes: unsafe bytes" {
    try std.testing.expect(containsCORSUnsafeBytes("hello\x00world"));
    try std.testing.expect(containsCORSUnsafeBytes("has\"quote"));
    try std.testing.expect(containsCORSUnsafeBytes("has(paren"));
    try std.testing.expect(containsCORSUnsafeBytes("has)paren"));
    try std.testing.expect(containsCORSUnsafeBytes("has:colon"));
    try std.testing.expect(containsCORSUnsafeBytes("has<less"));
    try std.testing.expect(containsCORSUnsafeBytes("has>greater"));
    try std.testing.expect(containsCORSUnsafeBytes("has@at"));
    try std.testing.expect(containsCORSUnsafeBytes("has[bracket"));
    try std.testing.expect(containsCORSUnsafeBytes("has\\backslash"));
    try std.testing.expect(containsCORSUnsafeBytes("has{brace"));
    try std.testing.expect(containsCORSUnsafeBytes("has\x7Fdel"));
}

test "containsCORSUnsafeBytes: safe bytes" {
    try std.testing.expect(!containsCORSUnsafeBytes("text/html"));
    try std.testing.expect(!containsCORSUnsafeBytes("*/*"));
    try std.testing.expect(!containsCORSUnsafeBytes("en-US,en;q=0.9"));
    try std.testing.expect(!containsCORSUnsafeBytes("hello\tworld")); // HT is safe
}

test "isCORSSafelistedRequestHeader: accept" {
    try std.testing.expect(isCORSSafelistedRequestHeader("Accept", "*/*"));
    try std.testing.expect(isCORSSafelistedRequestHeader("accept", "text/html"));
    try std.testing.expect(!isCORSSafelistedRequestHeader("Accept", "text/html\x00")); // NUL
    try std.testing.expect(!isCORSSafelistedRequestHeader("Accept", "a" ** 129)); // too long
}

test "isCORSSafelistedRequestHeader: accept-language" {
    try std.testing.expect(isCORSSafelistedRequestHeader("Accept-Language", "en-US"));
    try std.testing.expect(isCORSSafelistedRequestHeader("accept-language", "en-US,en;q=0.9"));
    try std.testing.expect(!isCORSSafelistedRequestHeader("Accept-Language", "en\"US")); // quote
}

test "isCORSSafelistedRequestHeader: content-type" {
    try std.testing.expect(isCORSSafelistedRequestHeader("Content-Type", "text/plain"));
    try std.testing.expect(isCORSSafelistedRequestHeader("content-type", "application/x-www-form-urlencoded"));
    try std.testing.expect(isCORSSafelistedRequestHeader("Content-Type", "multipart/form-data; boundary=---"));
    try std.testing.expect(!isCORSSafelistedRequestHeader("Content-Type", "application/json")); // not allowed
    try std.testing.expect(!isCORSSafelistedRequestHeader("Content-Type", "text/xml")); // not allowed
}

test "isCORSSafelistedRequestHeader: range" {
    try std.testing.expect(isCORSSafelistedRequestHeader("Range", "bytes=0-100"));
    try std.testing.expect(isCORSSafelistedRequestHeader("range", "bytes=500-999"));
    try std.testing.expect(isCORSSafelistedRequestHeader("Range", "bytes=0-")); // open-ended
    try std.testing.expect(!isCORSSafelistedRequestHeader("Range", "bytes=-500")); // suffix range
}

test "isCORSSafelistedRequestHeader: unknown header" {
    try std.testing.expect(!isCORSSafelistedRequestHeader("X-Custom", "value"));
    try std.testing.expect(!isCORSSafelistedRequestHeader("Authorization", "Bearer token"));
}

test "isForbiddenRequestHeader: always forbidden" {
    try std.testing.expect(isForbiddenRequestHeader("Cookie", "sessionid=abc"));
    try std.testing.expect(isForbiddenRequestHeader("Host", "example.com"));
    try std.testing.expect(isForbiddenRequestHeader("Origin", "https://example.com"));
    try std.testing.expect(isForbiddenRequestHeader("Content-Length", "100"));
    try std.testing.expect(isForbiddenRequestHeader("Set-Cookie", "a=b"));
}

test "isForbiddenRequestHeader: Proxy- and Sec- prefixes" {
    try std.testing.expect(isForbiddenRequestHeader("Proxy-Authorization", "Basic abc"));
    try std.testing.expect(isForbiddenRequestHeader("Proxy-Anything", "value"));
    try std.testing.expect(isForbiddenRequestHeader("Sec-Fetch-Mode", "cors"));
    try std.testing.expect(isForbiddenRequestHeader("Sec-Fetch-Site", "same-origin"));
}

test "isForbiddenRequestHeader: X-HTTP-Method with forbidden methods" {
    try std.testing.expect(isForbiddenRequestHeader("X-HTTP-Method", "CONNECT"));
    try std.testing.expect(isForbiddenRequestHeader("X-HTTP-Method-Override", "trace"));
    try std.testing.expect(isForbiddenRequestHeader("X-Method-Override", "TRACK"));
    try std.testing.expect(!isForbiddenRequestHeader("X-HTTP-Method", "DELETE")); // allowed
    try std.testing.expect(!isForbiddenRequestHeader("X-HTTP-Method", "PUT")); // allowed
}

test "isForbiddenRequestHeader: not forbidden" {
    try std.testing.expect(!isForbiddenRequestHeader("Accept", "*/*"));
    try std.testing.expect(!isForbiddenRequestHeader("Content-Type", "text/plain"));
    try std.testing.expect(!isForbiddenRequestHeader("X-Custom-Header", "value"));
}

test "isForbiddenResponseHeaderName" {
    try std.testing.expect(isForbiddenResponseHeaderName("Set-Cookie"));
    try std.testing.expect(isForbiddenResponseHeaderName("set-cookie"));
    try std.testing.expect(isForbiddenResponseHeaderName("Set-Cookie2"));
    try std.testing.expect(!isForbiddenResponseHeaderName("Content-Type"));
}

test "isNoCORSSafelistedRequestHeader" {
    try std.testing.expect(isNoCORSSafelistedRequestHeader("Accept", "text/html"));
    try std.testing.expect(isNoCORSSafelistedRequestHeader("Content-Type", "text/plain"));
    try std.testing.expect(!isNoCORSSafelistedRequestHeader("Accept", "a" ** 129)); // too long
    try std.testing.expect(!isNoCORSSafelistedRequestHeader("Authorization", "Bearer x"));
}

test "isCORSSafelistedResponseHeaderName" {
    const empty_list: []const []const u8 = &.{};

    try std.testing.expect(isCORSSafelistedResponseHeaderName("Content-Type", empty_list));
    try std.testing.expect(isCORSSafelistedResponseHeaderName("Cache-Control", empty_list));
    try std.testing.expect(isCORSSafelistedResponseHeaderName("Expires", empty_list));
    try std.testing.expect(!isCORSSafelistedResponseHeaderName("X-Custom", empty_list));

    const exposed: []const []const u8 = &.{"X-Custom"};
    try std.testing.expect(isCORSSafelistedResponseHeaderName("X-Custom", exposed));

    // Set-Cookie in exposed list should still not be safelisted (it's forbidden)
    const exposed_forbidden: []const []const u8 = &.{"Set-Cookie"};
    try std.testing.expect(!isCORSSafelistedResponseHeaderName("Set-Cookie", exposed_forbidden));
}

test "isRequestBodyHeaderName" {
    try std.testing.expect(isRequestBodyHeaderName("Content-Type"));
    try std.testing.expect(isRequestBodyHeaderName("Content-Encoding"));
    try std.testing.expect(isRequestBodyHeaderName("Content-Language"));
    try std.testing.expect(isRequestBodyHeaderName("Content-Location"));
    try std.testing.expect(!isRequestBodyHeaderName("Accept"));
}

test "isCORSNonWildcardRequestHeaderName" {
    try std.testing.expect(isCORSNonWildcardRequestHeaderName("Authorization"));
    try std.testing.expect(isCORSNonWildcardRequestHeaderName("authorization"));
    try std.testing.expect(!isCORSNonWildcardRequestHeaderName("Accept"));
}

test "isPrivilegedNoCORSRequestHeaderName" {
    try std.testing.expect(isPrivilegedNoCORSRequestHeaderName("Range"));
    try std.testing.expect(isPrivilegedNoCORSRequestHeaderName("range"));
    try std.testing.expect(!isPrivilegedNoCORSRequestHeaderName("Accept"));
}

test "getCORSUnsafeRequestHeaderNames: basic" {
    const allocator = std.testing.allocator;

    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    try headers.append("Accept", "text/html");
    try headers.append("X-Custom", "value"); // unsafe
    try headers.append("Content-Type", "text/plain"); // safe

    const unsafe = try getCORSUnsafeRequestHeaderNames(allocator, &headers);
    defer {
        for (unsafe) |n| allocator.free(n);
        allocator.free(unsafe);
    }

    try std.testing.expectEqual(@as(usize, 1), unsafe.len);
    try std.testing.expectEqualStrings("x-custom", unsafe[0]);
}

test "getCORSUnsafeRequestHeaderNames: safelist size exceeded" {
    const allocator = std.testing.allocator;

    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    // Add safelisted headers with large values (> 1024 total)
    const large_value = "a" ** 600;
    try headers.append("Accept", large_value);
    try headers.append("Content-Type", "text/plain; charset=" ++ "b" ** 500);

    const unsafe = try getCORSUnsafeRequestHeaderNames(allocator, &headers);
    defer {
        for (unsafe) |n| allocator.free(n);
        allocator.free(unsafe);
    }

    // Both should now be unsafe because total safelist size > 1024
    try std.testing.expectEqual(@as(usize, 2), unsafe.len);
}
