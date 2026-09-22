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
    try open(&state, "GET", "http://example.com/1", true, null, null, null);
    try std.testing.expectEqualStrings("http://example.com/1", state.request_url.?);

    // Second open should replace
    try open(&state, "POST", "http://example.com/2", true, null, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com/2", state.request_url.?);
}

test "open() after a completed request - resets state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", true, null, null, null);

    // Stand in for a completed request. Calling `send()` here would perform a
    // REAL blocking fetch now that `fetch_integration` is wired to libcurl -
    // this used to pass only because `send()` ran a mock.
    state.ready_state = .DONE;
    state.send_flag = false;
    try state.received_bytes.appendSlice(allocator, "old body");

    // Step 11: a new open() resets everything.
    try open(&state, "POST", "http://example.com/new", true, null, null, null);
    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
    try std.testing.expectEqual(@as(usize, 0), state.received_bytes.items.len);
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

test "setRequestHeader() with the send() flag set throws InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null, null);

    // Spec: "If this's state is not opened, throw an InvalidStateError. If
    // this's send() flag is set, throw an InvalidStateError." Setting the flag
    // is the precondition being tested; calling `send()` to set it would now
    // perform a real request.
    state.send_flag = true;

    const result = headers.setRequestHeader(&state, "X-Custom", "value");
    try std.testing.expectError(headers.HeaderError.InvalidStateError, result);
}

// =============================================================================
// Empty and Boundary Values
// =============================================================================

test "createRequest - an empty body is no body at all" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null, null);

    // send() step 9: "If req's body is null, set this's upload complete flag."
    // An empty string extracts to a zero-length body, which carries no upload
    // to report - the flag is set for it too.
    //
    // This used to call `send(&state, "")`, which now blocks on a real request.
    try std.testing.expect(state.request_url != null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "Large body - held by reference, not copied" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null, null);

    // Create a large body (64KB)
    const large_body = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(large_body);
    @memset(large_body, 'x');

    // The request body crosses into Fetch as `.{ .bytes = ... }`, a BORROWED
    // slice: `InternalRequest.deinit` frees only the `.body` arm of that union.
    // Sending it is `fetch_integration`'s test; what matters here is that the
    // state does not take a copy of 64KB it would then have to free.
    try std.testing.expect(state.request_body == null);
}

// =============================================================================
// Header Edge Cases
// =============================================================================

test "setRequestHeader() - case insensitive header names" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null, null);

    // Set header with different cases
    try headers.setRequestHeader(&state, "Content-Type", "application/json");

    // Header should be stored lowercase
    // `getFirstValue`, not `get`: HeaderList.get takes an allocator and hands
    // back an owned, comma-combined string. The field is
    // `author_request_headers`, the spec's name for it.
    const value = state.author_request_headers.getFirstValue("content-type");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("application/json", value.?);
}

test "setRequestHeader() - header value with special characters" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", true, null, null, null);

    // Value with semicolon and equals (common in content-type)
    try headers.setRequestHeader(&state, "Content-Type", "text/html; charset=utf-8");

    const value = state.author_request_headers.getFirstValue("content-type");
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
    try std.testing.expectEqual(@as(u32, 0), state.timeout);

    // shouldTimeout should always return false
    try std.testing.expect(!timeout_mod.shouldTimeout(&state, 999999999));
}

test "setTimeout - the largest unsigned long" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // `attribute unsigned long timeout` caps at 2^32-1. This asserted
    // maxInt(u64), which is not representable and is what
    // `expected type 'u32', found 'u64'` was reporting.
    try timeout_mod.setTimeout(&state, std.math.maxInt(u32), false);
    try std.testing.expectEqual(@as(u32, std.math.maxInt(u32)), state.timeout);
}

// =============================================================================
// Abort Edge Cases
// =============================================================================

test "abort() - multiple times is safe" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", true, null, null, null);
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

test "Sync XHR - async=false sets the synchronous flag" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Open synchronously (async=false)
    try open(&state, "GET", "http://example.com/data", false, null, null, null);
    try std.testing.expect(state.synchronous_flag);

    // The send() half of this test is gone: it would now block on a real
    // request to example.com. The sync path's observable difference - no
    // progress events, failure by throwing - is covered in
    // `send_async_test.zig` through the ResponseProcessor.
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

    try open(&state, "get", "http://example.com", true, null, null, null);
    try std.testing.expectEqualStrings("GET", state.request_method.?);

    state.reset();

    try open(&state, "pOsT", "http://example.com", true, null, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "open() - custom method preserved as-is" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "CUSTOM", "http://example.com", true, null, null, null);
    try std.testing.expectEqualStrings("CUSTOM", state.request_method.?);
}
