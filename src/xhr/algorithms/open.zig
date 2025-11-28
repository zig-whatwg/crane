//! XMLHttpRequest open() Algorithm
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/#the-open()-method

const std = @import("std");
const Allocator = std.mem.Allocator;
const xhr = @import("../root.zig");
const XMLHttpRequestState = xhr.XMLHttpRequestState;
const ReadyState = xhr.ReadyState;

/// Error types for open()
pub const OpenError = error{
    InvalidMethod,
    InvalidURL,
    InvalidState,
    SecurityError,
    OutOfMemory,
};

/// Forbidden HTTP methods (spec-defined)
const forbidden_methods = [_][]const u8{
    "CONNECT",
    "TRACE",
    "TRACK",
};

/// Methods that should be normalized to uppercase
const methods_to_normalize = [_][]const u8{
    "delete",
    "get",
    "head",
    "options",
    "post",
    "put",
};

/// Validate and normalize HTTP method
///
/// Spec step 1-2: Method validation and normalization
fn validateAndNormalizeMethod(allocator: Allocator, method: []const u8) ![]const u8 {
    // Step 1: Check if method is a forbidden method
    for (forbidden_methods) |forbidden| {
        if (std.ascii.eqlIgnoreCase(method, forbidden)) {
            return OpenError.SecurityError;
        }
    }

    // Step 2: Normalize method to uppercase if it's a standard method
    for (methods_to_normalize) |standard| {
        if (std.ascii.eqlIgnoreCase(method, standard)) {
            return try std.ascii.allocUpperString(allocator, method);
        }
    }

    // Otherwise, use method as-is
    return try allocator.dupe(u8, method);
}

/// Parse and validate URL
///
/// Spec step 3-5: URL parsing
fn parseURL(allocator: Allocator, url: []const u8, base: ?[]const u8) ![]const u8 {
    _ = base; // TODO: Implement URL parsing with base

    // For now, basic validation
    if (url.len == 0) {
        return OpenError.InvalidURL;
    }

    // Check for valid URL scheme
    if (!std.mem.startsWith(u8, url, "http://") and
        !std.mem.startsWith(u8, url, "https://") and
        !std.mem.startsWith(u8, url, "data:") and
        !std.mem.startsWith(u8, url, "file://"))
    {
        return OpenError.InvalidURL;
    }

    return try allocator.dupe(u8, url);
}

/// The open() method
///
/// Spec: https://xhr.spec.whatwg.org/#the-open()-method
///
/// Steps:
/// 1. Validate method
/// 2. Parse URL
/// 3. Validate URL scheme
/// 4. Handle username/password
/// 5. Validate async mode
/// 6. Terminate ongoing fetch
/// 7. Reset state
/// 8. Set state to OPENED
pub fn open(
    state: *XMLHttpRequestState,
    method: []const u8,
    url: []const u8,
    async_mode: bool,
    username: ?[]const u8,
    password: ?[]const u8,
) OpenError!void {
    const allocator = state.allocator;

    // Step 1-2: Validate and normalize method
    const normalized_method = try validateAndNormalizeMethod(allocator, method);
    errdefer allocator.free(normalized_method);

    // Step 3-5: Parse URL
    const parsed_url = try parseURL(allocator, url, null);
    errdefer allocator.free(parsed_url);

    // Step 6-7: Handle username/password (if provided)
    // TODO: Set username/password on parsed URL
    _ = username;
    _ = password;

    // Step 8: Validate URL scheme
    // (Already done in parseURL)

    // Step 9: If not async and in Window context, deprecation warning
    // TODO: Check if in Window context (requires HTML Standard)

    // Step 10: Terminate ongoing fetch if any
    // TODO: Terminate fetch controller

    // Step 11-13: Reset state
    state.reset();

    // Step 14: Set request method and URL
    state.request_method = normalized_method;
    state.request_url = parsed_url;
    state.synchronous_flag = !async_mode;

    // Step 15: Set state to OPENED
    state.changeState(.OPENED);
}

test "open - GET request" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com", true, null, null);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqualStrings("GET", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com", state.request_url.?);
    try std.testing.expect(!state.synchronous_flag);
}

test "open - POST request" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "https://example.com/api", true, null, null);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "open - method normalization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Lowercase methods should be normalized to uppercase
    try open(&state, "get", "http://example.com", true, null, null);
    try std.testing.expectEqualStrings("GET", state.request_method.?);

    state.reset();

    try open(&state, "post", "http://example.com", true, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "open - forbidden methods" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // CONNECT should be forbidden
    const result1 = open(&state, "CONNECT", "http://example.com", true, null, null);
    try std.testing.expectError(OpenError.SecurityError, result1);

    // TRACE should be forbidden
    const result2 = open(&state, "TRACE", "http://example.com", true, null, null);
    try std.testing.expectError(OpenError.SecurityError, result2);

    // TRACK should be forbidden
    const result3 = open(&state, "TRACK", "http://example.com", true, null, null);
    try std.testing.expectError(OpenError.SecurityError, result3);
}

test "open - synchronous mode" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com", false, null, null);

    try std.testing.expect(state.synchronous_flag);
}

test "open - invalid URL" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Empty URL
    const result1 = open(&state, "GET", "", true, null, null);
    try std.testing.expectError(OpenError.InvalidURL, result1);

    // Invalid scheme
    const result2 = open(&state, "GET", "ftp://example.com", true, null, null);
    try std.testing.expectError(OpenError.InvalidURL, result2);
}

test "open - multiple calls (reset)" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // First open
    try open(&state, "GET", "http://example.com/1", true, null, null);
    try std.testing.expectEqualStrings("http://example.com/1", state.request_url.?);

    // Second open should reset and replace
    try open(&state, "POST", "http://example.com/2", true, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com/2", state.request_url.?);
}
