//! Edge case tests for XMLHttpRequest
//!
//! Tests unusual scenarios, boundary conditions, and error paths.

const std = @import("std");
const xhr = @import("xhr");
const XMLHttpRequestState = xhr.XMLHttpRequestState;
const ReadyState = xhr.ReadyState;
const open = xhr.open.open;
const send = xhr.send.send;
const headers = xhr.headers;
const abort_mod = xhr.abort;
const timeout_mod = xhr.timeout;

// =============================================================================
// Multiple open() Calls
// =============================================================================

test "Multiple open() - aborts previous request" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // First open
    try open(&state, "GET", "http://example.com/1", true, null, null);
    try std.testing.expectEqualStrings("http://example.com/1", state.request_url.?);

    // Second open should replace
    try open(&state, "POST", "http://example.com/2", true, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com/2", state.request_url.?);
}

test "open() after send() - resets state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", true, null, null);
    try send(&state, null);

    // After send, state is DONE
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);

    // New open should reset
    try open(&state, "POST", "http://example.com/new", true, null, null);
    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

// =============================================================================
// Invalid State Errors
// =============================================================================

test "send() without open() throws InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = send(&state, null);
    try std.testing.expectError(error.InvalidStateError, result);
}

test "setRequestHeader() without open() throws InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const result = headers.setRequestHeader(&state, "Content-Type", "text/plain");
    try std.testing.expectError(headers.HeaderError.InvalidStateError, result);
}

test "setRequestHeader() after send() throws InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null);
    try send(&state, null);

    // State is now DONE, send_flag is cleared
    // But for setting headers, state must be OPENED
    const result = headers.setRequestHeader(&state, "X-Custom", "value");
    try std.testing.expectError(headers.HeaderError.InvalidStateError, result);
}

// =============================================================================
// Empty and Boundary Values
// =============================================================================

test "send() with empty string body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null);
    try send(&state, "");

    try std.testing.expect(state.upload_complete_flag);
}

test "Large body handling" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null);

    // Create a large body (64KB)
    const large_body = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(large_body);
    @memset(large_body, 'x');

    try send(&state, large_body);

    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

// =============================================================================
// Header Edge Cases
// =============================================================================

test "setRequestHeader() - case insensitive header names" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null);

    // Set header with different cases
    try headers.setRequestHeader(&state, "Content-Type", "application/json");

    // Header should be stored lowercase
    const value = state.request_headers.get("content-type");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("application/json", value.?);
}

test "setRequestHeader() - header value with special characters" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null);

    // Value with semicolon and equals (common in content-type)
    try headers.setRequestHeader(&state, "Content-Type", "text/html; charset=utf-8");

    const value = state.request_headers.get("content-type");
    try std.testing.expectEqualStrings("text/html; charset=utf-8", value.?);
}

// =============================================================================
// Timeout Edge Cases
// =============================================================================

test "setTimeout - zero means no timeout" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try timeout_mod.setTimeout(&state, 0, false);
    try std.testing.expectEqual(@as(u64, 0), state.timeout);

    // shouldTimeout should always return false
    try std.testing.expect(!timeout_mod.shouldTimeout(&state, 999999999));
}

test "setTimeout - very large value" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try timeout_mod.setTimeout(&state, std.math.maxInt(u64), false);
    try std.testing.expectEqual(std.math.maxInt(u64), state.timeout);
}

// =============================================================================
// Abort Edge Cases
// =============================================================================

test "abort() - multiple times is safe" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", true, null, null);
    state.send_flag = true;
    state.ready_state = .LOADING;

    abort_mod.abort(&state);
    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);

    // Second abort should be no-op
    abort_mod.abort(&state);
    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
}

test "abort() - during HEADERS_RECEIVED" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .HEADERS_RECEIVED;
    state.send_flag = true;

    abort_mod.abort(&state);

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
}

// =============================================================================
// Synchronous XHR Edge Cases
// =============================================================================

test "Sync XHR - basic flow" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Open synchronously (async=false)
    try open(&state, "GET", "http://example.com/data", false, null, null);
    try std.testing.expect(state.synchronous_flag);

    // Send (simulated fetch completes synchronously)
    try send(&state, null);

    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "Sync XHR - setTimeout restriction in Window" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.synchronous_flag = true;

    // Should throw when in Window context
    const result = timeout_mod.setTimeout(&state, 5000, true);
    try std.testing.expectError(timeout_mod.TimeoutError.InvalidAccessError, result);
}

// =============================================================================
// Response Accumulation Edge Cases
// =============================================================================

test "Response body - handles binary data with nulls" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Binary data with embedded nulls
    const binary_data = &[_]u8{ 0x00, 0x01, 0x00, 0x02, 0x00 };
    try state.received_bytes.appendSlice(allocator, binary_data);

    try std.testing.expectEqualSlices(u8, binary_data, state.received_bytes.items);
}

// =============================================================================
// Method Validation Edge Cases
// =============================================================================

test "open() - case insensitive method normalization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "get", "http://example.com", true, null, null);
    try std.testing.expectEqualStrings("GET", state.request_method.?);

    state.reset();

    try open(&state, "pOsT", "http://example.com", true, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "open() - custom method preserved as-is" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "CUSTOM", "http://example.com", true, null, null);
    try std.testing.expectEqualStrings("CUSTOM", state.request_method.?);
}
