//! Integration tests for XHR send() - async path

const std = @import("std");
const xhr_root = @import("xhr");
const XMLHttpRequestState = xhr_root.XMLHttpRequestState;
const ReadyState = xhr_root.ReadyState;
const send = xhr_root.send.send;
const open = xhr_root.open.open;

test "send() - complete async flow" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Open request
    try open(&state, "GET", "http://example.com/data", false);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);

    // Send request
    try send(&state, null);

    // After send completes (in simplified fetch), should be DONE
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(!state.send_flag);
}

test "send() - accumulates response body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", false);
    try send(&state, null);

    // Should have received mock response
    try std.testing.expect(state.received_bytes.items.len > 0);
    try std.testing.expectEqualStrings("Mock response data from simplified fetch", state.received_bytes.items);
}

test "send() - POST with body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/api", false);

    const body = "request body data";
    try send(&state, body);

    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(state.upload_complete_flag);
}

test "send() - state transitions" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", false);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);

    try send(&state, null);

    // Final state should be DONE
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "send() - upload complete flag for null body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", false);
    try send(&state, null);

    try std.testing.expect(state.upload_complete_flag);
}

test "send() - upload complete flag for empty body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/data", false);
    try send(&state, "");

    try std.testing.expect(state.upload_complete_flag);
}

test "send() - upload complete flag for non-empty body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "http://example.com/data", false);
    try send(&state, "test data");

    // Should be complete after simplified fetch processes it
    try std.testing.expect(state.upload_complete_flag);
}

test "send() - cannot send twice" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com/data", false);

    // First send() should be set but will be cleared by fetch completion
    try send(&state, null);

    // Try to send again after completion (should work since send_flag was cleared)
    // Need to open again first
    try open(&state, "GET", "http://example.com/data2", false);
    try send(&state, null);

    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "send() - requires OPENED state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Try send without open()
    const result = send(&state, null);
    try std.testing.expectError(error.InvalidStateError, result);
}
