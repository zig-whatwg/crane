//! Comprehensive state machine tests
//!
//! Tests all state transitions and edge cases for XMLHttpRequest state machine.

const std = @import("std");
const xhr = @import("xhr");
const XMLHttpRequestState = xhr.XMLHttpRequestState;
const ReadyState = xhr.ReadyState;
const ResponseType = xhr.state_machine.ResponseType;

// =============================================================================
// State Initialization
// =============================================================================

test "XMLHttpRequestState - default initialization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(!state.upload_complete_flag);
    try std.testing.expect(!state.upload_listener_flag);
    try std.testing.expect(!state.timed_out_flag);
    try std.testing.expect(!state.synchronous_flag);
    try std.testing.expect(!state.error_flag);
    try std.testing.expect(state.request_method == null);
    try std.testing.expect(state.request_url == null);
    try std.testing.expect(state.request_body == null);
    try std.testing.expectEqual(@as(u64, 0), state.timeout);
    try std.testing.expect(!state.with_credentials);
    try std.testing.expectEqual(ResponseType.empty, state.response_type);
}

// =============================================================================
// State Transitions
// =============================================================================

test "State transitions - UNSENT to OPENED" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);

    state.changeState(.OPENED);
    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
}

test "State transitions - full sequence" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // UNSENT -> OPENED
    state.changeState(.OPENED);
    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);

    // OPENED -> HEADERS_RECEIVED
    state.changeState(.HEADERS_RECEIVED);
    try std.testing.expectEqual(ReadyState.HEADERS_RECEIVED, state.ready_state);

    // HEADERS_RECEIVED -> LOADING
    state.changeState(.LOADING);
    try std.testing.expectEqual(ReadyState.LOADING, state.ready_state);

    // LOADING -> DONE
    state.changeState(.DONE);
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "State transitions - same state is idempotent" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.changeState(.OPENED);
    state.changeState(.OPENED);
    state.changeState(.OPENED);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
}

// =============================================================================
// Reset Behavior
// =============================================================================

test "reset - clears all request state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Set various state
    state.request_method = try allocator.dupe(u8, "POST");
    state.request_url = try allocator.dupe(u8, "http://example.com");
    state.request_body = try allocator.dupe(u8, "body data");
    state.send_flag = true;
    state.error_flag = true;
    state.timed_out_flag = true;

    // Reset
    state.reset();

    // Verify cleared
    try std.testing.expect(state.request_method == null);
    try std.testing.expect(state.request_url == null);
    try std.testing.expect(state.request_body == null);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(!state.error_flag);
    try std.testing.expect(!state.timed_out_flag);
}

test "reset - clears headers" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Add some headers
    const key = try allocator.dupe(u8, "content-type");
    const value = try allocator.dupe(u8, "application/json");
    try state.request_headers.put(allocator, key, value);

    // Reset
    state.reset();

    // Headers should be cleared
    try std.testing.expectEqual(@as(usize, 0), state.request_headers.count());
}

test "reset - clears received bytes" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try state.received_bytes.appendSlice(allocator, "response data");
    try std.testing.expect(state.received_bytes.items.len > 0);

    state.reset();

    try std.testing.expectEqual(@as(usize, 0), state.received_bytes.items.len);
}

// =============================================================================
// Response Type
// =============================================================================

test "ResponseType - all variants" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.response_type = .empty;
    try std.testing.expectEqual(ResponseType.empty, state.response_type);

    state.response_type = .text;
    try std.testing.expectEqual(ResponseType.text, state.response_type);

    state.response_type = .arraybuffer;
    try std.testing.expectEqual(ResponseType.arraybuffer, state.response_type);

    state.response_type = .blob;
    try std.testing.expectEqual(ResponseType.blob, state.response_type);

    state.response_type = .document;
    try std.testing.expectEqual(ResponseType.document, state.response_type);

    state.response_type = .json;
    try std.testing.expectEqual(ResponseType.json, state.response_type);
}

// =============================================================================
// Flags
// =============================================================================

test "Flags - synchronous flag" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expect(!state.synchronous_flag);

    state.synchronous_flag = true;
    try std.testing.expect(state.synchronous_flag);
}

test "Flags - with_credentials" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expect(!state.with_credentials);

    state.with_credentials = true;
    try std.testing.expect(state.with_credentials);
}

test "Flags - upload_listener_flag" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expect(!state.upload_listener_flag);

    state.upload_listener_flag = true;
    try std.testing.expect(state.upload_listener_flag);
}

// =============================================================================
// Memory Safety
// =============================================================================

test "Memory safety - repeated reset does not leak" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Allocate and reset multiple times
    for (0..10) |_| {
        state.request_method = try allocator.dupe(u8, "GET");
        state.request_url = try allocator.dupe(u8, "http://example.com");
        state.reset();
    }

    // No leaks should occur (testing allocator will catch them)
}

test "Memory safety - deinit cleans up everything" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);

    // Set up state with allocations
    state.request_method = try allocator.dupe(u8, "POST");
    state.request_url = try allocator.dupe(u8, "http://example.com/api");
    state.request_body = try allocator.dupe(u8, "request body");

    const key = try allocator.dupe(u8, "x-custom");
    const value = try allocator.dupe(u8, "header-value");
    try state.request_headers.put(allocator, key, value);

    try state.received_bytes.appendSlice(allocator, "response data");

    // deinit should clean up everything
    state.deinit();

    // No leaks should occur (testing allocator will catch them)
}
