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
/// 3. Validate header name
/// 4. Validate header value
/// 5. If header is forbidden, return (silently fail)
/// 6. Combine with existing header of same name, or add new
pub fn setRequestHeader(
    state: *XMLHttpRequestState,
    name: []const u8,
    value: []const u8,
) HeaderError!void {
    const allocator = state.allocator;

    // Step 1-2: Check state
    if (state.ready_state != .OPENED) {
        return HeaderError.InvalidStateError;
    }

    if (state.send_flag) {
        return HeaderError.InvalidStateError;
    }

    // Step 3: Validate name
    if (!isValidHeaderName(name)) {
        return HeaderError.SyntaxError;
    }

    // Step 4: Validate value
    if (!isValidHeaderValue(value)) {
        return HeaderError.SyntaxError;
    }

    // Step 5: If forbidden, silently ignore
    if (isForbiddenRequestHeader(name)) {
        return;
    }

    // Step 6: Combine or add header
    // Normalize header name to lowercase for storage
    const name_lower = try std.ascii.allocLowerString(allocator, name);
    errdefer allocator.free(name_lower);

    if (state.request_headers.get(name_lower)) |existing| {
        // Combine with existing value
        const combined = try std.fmt.allocPrint(allocator, "{s}, {s}", .{ existing, value });
        allocator.free(name_lower);
        allocator.free(existing);
        try state.request_headers.put(allocator, name_lower, combined);
    } else {
        // Add new header
        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);
        try state.request_headers.put(allocator, name_lower, value_copy);
    }
}

/// Get a single response header
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-getresponseheader
///
/// Returns null if header not found or response not received.
pub fn getResponseHeader(
    state: *const XMLHttpRequestState,
    name: []const u8,
) ?[]const u8 {
    // Step 1: If state is UNSENT or OPENED, return null
    if (state.ready_state == .UNSENT or state.ready_state == .OPENED) {
        return null;
    }

    // TODO: When InternalResponse is integrated, get header from response
    // For now, return null (no response headers stored yet)
    _ = name;
    return null;
}

/// Get all response headers as a string
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-getallresponseheaders
///
/// Returns empty string if response not received.
/// Headers are sorted and formatted as "name: value\r\n" pairs.
pub fn getAllResponseHeaders(
    allocator: Allocator,
    state: *const XMLHttpRequestState,
) ![]const u8 {
    // Step 1: If state is UNSENT or OPENED, return empty string
    if (state.ready_state == .UNSENT or state.ready_state == .OPENED) {
        return "";
    }

    // TODO: When InternalResponse is integrated, build header string
    // For now, return empty string
    _ = allocator;
    return "";
}

/// Override the response MIME type
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-overridemimetype
///
/// This affects how the response is interpreted.
pub fn overrideMimeType(
    state: *XMLHttpRequestState,
    mime: []const u8,
) HeaderError!void {
    // Step 1: If state is LOADING or DONE, throw InvalidStateError
    if (state.ready_state == .LOADING or state.ready_state == .DONE) {
        return HeaderError.InvalidStateError;
    }

    // Step 2: Store the override MIME type
    // TODO: Store in state when override_mime_type field is added
    _ = mime;
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

    const value = state.request_headers.get("content-type");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("application/json", value.?);
}

test "setRequestHeader - silently ignores forbidden headers" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    // Should not throw, should silently ignore
    try setRequestHeader(&state, "Cookie", "session=abc");

    // Header should not be stored
    const value = state.request_headers.get("cookie");
    try std.testing.expect(value == null);
}

test "setRequestHeader - invalid name throws SyntaxError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    const result = setRequestHeader(&state, "Invalid Header", "value");
    try std.testing.expectError(HeaderError.SyntaxError, result);
}

test "getResponseHeader - returns null when UNSENT" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = getResponseHeader(&state, "Content-Type");
    try std.testing.expect(result == null);
}

test "getAllResponseHeaders - returns empty when UNSENT" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = try getAllResponseHeaders(allocator, &state);
    try std.testing.expectEqualStrings("", result);
}
