//! XMLHttpRequest Header Algorithms
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#request-headers
//!
//! This module handles:
//! - setRequestHeader() - Add request headers with validation
//! - getResponseHeader() - Get single response header
//! - getAllResponseHeaders() - Get all response headers as string
//! - overrideMimeType() - Override response MIME type

const std = @import("std");
const Allocator = std.mem.Allocator;
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ReadyState = xhr_root.state_machine.ReadyState;

// Fetch Standard types
const fetch = @import("fetch");
const HeaderList = fetch.internal.HeaderList;

/// Error types for header operations
pub const HeaderError = error{
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
};

/// Forbidden request headers (spec-defined)
/// https://xhr.spec.whatwg.org/#dom-xmlhttprequest-setrequestheader
const forbidden_request_headers = [_][]const u8{
    "Accept-Charset",
    "Accept-Encoding",
    "Access-Control-Request-Headers",
    "Access-Control-Request-Method",
    "Connection",
    "Content-Length",
    "Cookie",
    "Cookie2",
    "Date",
    "DNT",
    "Expect",
    "Host",
    "Keep-Alive",
    "Origin",
    "Referer",
    "TE",
    "Trailer",
    "Transfer-Encoding",
    "Upgrade",
    "Via",
};

/// Forbidden request header prefixes
const forbidden_request_header_prefixes = [_][]const u8{
    "Proxy-",
    "Sec-",
};

/// Check if a header name is forbidden
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-request-header
pub fn isForbiddenRequestHeader(name: []const u8) bool {
    // Check exact matches (case-insensitive)
    for (forbidden_request_headers) |forbidden| {
        if (std.ascii.eqlIgnoreCase(name, forbidden)) {
            return true;
        }
    }

    // Check prefixes (case-insensitive)
    for (forbidden_request_header_prefixes) |prefix| {
        if (name.len >= prefix.len) {
            const name_prefix = name[0..prefix.len];
            if (std.ascii.eqlIgnoreCase(name_prefix, prefix)) {
                return true;
            }
        }
    }

    return false;
}

/// Validate header name (must be a valid token)
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-name
pub fn isValidHeaderName(name: []const u8) bool {
    if (name.len == 0) return false;

    for (name) |c| {
        if (!isTokenChar(c)) {
            return false;
        }
    }

    return true;
}

/// Validate header value
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-value
pub fn isValidHeaderValue(value: []const u8) bool {
    // Value must not have leading/trailing whitespace
    if (value.len > 0) {
        const first = value[0];
        const last = value[value.len - 1];
        if (first == ' ' or first == '\t' or last == ' ' or last == '\t') {
            return false;
        }
    }

    // Value must not contain forbidden characters
    for (value) |c| {
        if (c == 0x00 or c == '\n' or c == '\r') {
            return false;
        }
    }

    return true;
}

/// Token characters for header names
fn isTokenChar(c: u8) bool {
    return switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        '0'...'9', 'A'...'Z', 'a'...'z' => true,
        else => false,
    };
}

/// Set a request header
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-setrequestheader
///
/// Steps:
/// 1. If state is not OPENED, throw InvalidStateError
/// 2. If send flag is set, throw InvalidStateError
/// 3. Normalize value
/// 4. If name is not a header name or value is not a header value, throw SyntaxError
/// 5. If (name, value) is a forbidden request-header, return
/// 6. Combine (name, value) in this's author request headers
pub fn setRequestHeader(
    state: *XMLHttpRequestState,
    name: []const u8,
    value: []const u8,
) HeaderError!void {
    // Step 1: If this's state is not opened, throw InvalidStateError
    if (state.ready_state != .OPENED) {
        return HeaderError.InvalidStateError;
    }

    // Step 2: If this's send() flag is set, throw InvalidStateError
    if (state.send_flag) {
        return HeaderError.InvalidStateError;
    }

    // Step 3: Normalize value
    const normalized_value = normalizeHeaderValue(value);

    // Step 4: If name is not a header name or value is not a header value, throw SyntaxError
    if (!isValidHeaderName(name)) {
        return HeaderError.SyntaxError;
    }
    if (!isValidHeaderValue(normalized_value)) {
        return HeaderError.SyntaxError;
    }

    // Step 5: If (name, value) is a forbidden request-header, return
    // Note: We use Fetch's isForbiddenRequestHeader for spec compliance
    if (isForbiddenRequestHeader(name)) {
        return;
    }

    // Step 6: Combine (name, value) in this's author request headers
    // Uses Fetch's HeaderList.combine() which handles the spec's combine algorithm
    try state.author_request_headers.combine(name, normalized_value);
}

/// Normalize a header value by trimming HTTP whitespace
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-value-normalize
fn normalizeHeaderValue(value: []const u8) []const u8 {
    // Trim leading HTTP tab or space
    var start: usize = 0;
    while (start < value.len and (value[start] == ' ' or value[start] == '\t')) {
        start += 1;
    }

    // Trim trailing HTTP tab or space
    var end: usize = value.len;
    while (end > start and (value[end - 1] == ' ' or value[end - 1] == '\t')) {
        end -= 1;
    }

    return value[start..end];
}

/// Get a single response header
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-getresponseheader
///
/// "The getResponseHeader(name) method steps are to return the result of
/// getting name from this's response's header list."
///
/// Returns null if header not found or response not received.
pub fn getResponseHeader(
    allocator: Allocator,
    state: *const XMLHttpRequestState,
    name: []const u8,
) !?[]const u8 {
    // Per spec, if response is null/network error, header list is empty
    const response = state.response orelse return null;

    // Get header value from response's header list
    // Note: This combines multiple values with ", " per Fetch spec
    return try response.header_list.get(allocator, name);
}

/// Get all response headers as a string
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-getallresponseheaders
///
/// Steps:
/// 1. Let output be an empty byte sequence
/// 2. Let initialHeaders be the result of running sort and combine with response's header list
/// 3. Let headers be the result of sorting initialHeaders using legacy-uppercased-byte less than
/// 4. For each header, append "name: value\r\n"
/// 5. Return output
pub fn getAllResponseHeaders(
    allocator: Allocator,
    state: *const XMLHttpRequestState,
) ![]const u8 {
    // Per spec, if response is null/network error, return empty
    const response = state.response orelse return "";

    // Step 2: Sort and combine headers
    var sorted_headers = try response.header_list.sortAndCombine(allocator);
    defer sorted_headers.deinit();

    // Step 3: Sort using legacy-uppercased-byte less than
    // The sortAndCombine already sorts alphabetically, but XHR spec requires
    // legacy uppercased comparison for compatibility
    std.mem.sort(
        fetch.internal.Header,
        sorted_headers.entries.items,
        {},
        struct {
            fn lessThan(_: void, a: fetch.internal.Header, b: fetch.internal.Header) bool {
                return legacyUppercasedByteLessThan(a.name, b.name);
            }
        }.lessThan,
    );

    // Step 4: Build output string
    var output = std.ArrayListUnmanaged(u8){};
    errdefer output.deinit(allocator);

    for (sorted_headers.entries.items) |header| {
        try output.appendSlice(allocator, header.name);
        try output.appendSlice(allocator, ": ");
        try output.appendSlice(allocator, header.value);
        try output.appendSlice(allocator, "\r\n");
    }

    return try output.toOwnedSlice(allocator);
}

/// Legacy-uppercased-byte less than comparison
///
/// Spec: "A byte sequence a is legacy-uppercased-byte less than a byte sequence b if
/// the following steps return true:
/// 1. Let A be a, byte-uppercased
/// 2. Let B be b, byte-uppercased
/// 3. Return A is byte less than B"
fn legacyUppercasedByteLessThan(a: []const u8, b: []const u8) bool {
    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        const a_upper = std.ascii.toUpper(a[i]);
        const b_upper = std.ascii.toUpper(b[i]);
        if (a_upper < b_upper) return true;
        if (a_upper > b_upper) return false;
    }
    return a.len < b.len;
}

/// Override the response MIME type
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-overridemimetype
///
/// Steps:
/// 1. If this's state is loading or done, throw InvalidStateError
/// 2. Set this's override MIME type to the result of parsing mime
/// 3. If this's override MIME type is failure, set it to application/octet-stream
pub fn overrideMimeType(
    state: *XMLHttpRequestState,
    mime: []const u8,
) HeaderError!void {
    const allocator = state.allocator;

    // Step 1: If this's state is loading or done, throw InvalidStateError
    if (state.ready_state == .LOADING or state.ready_state == .DONE) {
        return HeaderError.InvalidStateError;
    }

    // Free existing override if any
    if (state.override_mime_type) |*existing| {
        existing.deinit();
        state.override_mime_type = null;
    }

    // Step 2: Set this's override MIME type to the result of parsing mime
    const mimesniff = @import("mimesniff");
    if (mimesniff.parseMimeType(allocator, mime)) |parsed| {
        state.override_mime_type = parsed;
    } else |_| {
        // Step 3: If parsing fails, set to application/octet-stream
        state.override_mime_type = mimesniff.parseMimeType(allocator, "application/octet-stream") catch null;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "isForbiddenRequestHeader - forbidden headers" {
    try std.testing.expect(isForbiddenRequestHeader("Cookie"));
    try std.testing.expect(isForbiddenRequestHeader("cookie"));
    try std.testing.expect(isForbiddenRequestHeader("COOKIE"));
    try std.testing.expect(isForbiddenRequestHeader("Host"));
    try std.testing.expect(isForbiddenRequestHeader("Origin"));
    try std.testing.expect(isForbiddenRequestHeader("Referer"));
}

test "isForbiddenRequestHeader - forbidden prefixes" {
    try std.testing.expect(isForbiddenRequestHeader("Proxy-Authorization"));
    try std.testing.expect(isForbiddenRequestHeader("proxy-authenticate"));
    try std.testing.expect(isForbiddenRequestHeader("Sec-Fetch-Mode"));
    try std.testing.expect(isForbiddenRequestHeader("sec-websocket-key"));
}

test "isForbiddenRequestHeader - allowed headers" {
    try std.testing.expect(!isForbiddenRequestHeader("Content-Type"));
    try std.testing.expect(!isForbiddenRequestHeader("Accept"));
    try std.testing.expect(!isForbiddenRequestHeader("X-Custom-Header"));
    try std.testing.expect(!isForbiddenRequestHeader("Authorization"));
}

test "isValidHeaderName - valid names" {
    try std.testing.expect(isValidHeaderName("Content-Type"));
    try std.testing.expect(isValidHeaderName("X-Custom"));
    try std.testing.expect(isValidHeaderName("Accept"));
}

test "isValidHeaderName - invalid names" {
    try std.testing.expect(!isValidHeaderName(""));
    try std.testing.expect(!isValidHeaderName("Header Name")); // space not allowed
    try std.testing.expect(!isValidHeaderName("Header:Name")); // colon not allowed
}

test "isValidHeaderValue - valid values" {
    try std.testing.expect(isValidHeaderValue("application/json"));
    try std.testing.expect(isValidHeaderValue("text/html; charset=utf-8"));
    try std.testing.expect(isValidHeaderValue(""));
}

test "isValidHeaderValue - invalid values" {
    try std.testing.expect(!isValidHeaderValue(" leading space"));
    try std.testing.expect(!isValidHeaderValue("trailing space "));
    try std.testing.expect(!isValidHeaderValue("has\nnewline"));
    try std.testing.expect(!isValidHeaderValue("has\rcarriage"));
    try std.testing.expect(!isValidHeaderValue("has\x00null"));
}

test "setRequestHeader - requires OPENED state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = setRequestHeader(&state, "Content-Type", "application/json");
    try std.testing.expectError(HeaderError.InvalidStateError, result);
}

test "setRequestHeader - adds header" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    try setRequestHeader(&state, "Content-Type", "application/json");

    // Uses Fetch's HeaderList - check with contains
    try std.testing.expect(state.author_request_headers.contains("Content-Type"));
}

test "setRequestHeader - combines duplicate headers" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    try setRequestHeader(&state, "Accept", "text/html");
    try setRequestHeader(&state, "Accept", "application/json");

    // HeaderList.combine() joins with ", "
    const value = try state.author_request_headers.get(allocator, "Accept");
    defer if (value) |v| allocator.free(v);

    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("text/html, application/json", value.?);
}

test "setRequestHeader - silently ignores forbidden headers" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    // Should not throw, should silently ignore
    try setRequestHeader(&state, "Cookie", "session=abc");

    // Header should not be stored
    try std.testing.expect(!state.author_request_headers.contains("Cookie"));
}

test "setRequestHeader - invalid name throws SyntaxError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    const result = setRequestHeader(&state, "Invalid Header", "value");
    try std.testing.expectError(HeaderError.SyntaxError, result);
}

test "setRequestHeader - normalizes value whitespace" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    // Value with leading/trailing whitespace
    try setRequestHeader(&state, "X-Custom", "  value  ");

    const value = try state.author_request_headers.get(allocator, "X-Custom");
    defer if (value) |v| allocator.free(v);

    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("value", value.?);
}

test "getResponseHeader - returns null when no response" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = try getResponseHeader(allocator, &state, "Content-Type");
    try std.testing.expect(result == null);
}

test "getAllResponseHeaders - returns empty when no response" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = try getAllResponseHeaders(allocator, &state);
    try std.testing.expectEqualStrings("", result);
}

test "legacyUppercasedByteLessThan" {
    // Same case comparison
    try std.testing.expect(legacyUppercasedByteLessThan("accept", "content-type"));
    try std.testing.expect(!legacyUppercasedByteLessThan("content-type", "accept"));

    // Case insensitive
    try std.testing.expect(legacyUppercasedByteLessThan("Accept", "content-type"));
    try std.testing.expect(legacyUppercasedByteLessThan("accept", "Content-Type"));

    // Equal strings
    try std.testing.expect(!legacyUppercasedByteLessThan("accept", "accept"));
    try std.testing.expect(!legacyUppercasedByteLessThan("Accept", "accept"));

    // Length comparison when prefix matches
    try std.testing.expect(legacyUppercasedByteLessThan("a", "ab"));
    try std.testing.expect(!legacyUppercasedByteLessThan("ab", "a"));
}
