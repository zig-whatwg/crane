//! XMLHttpRequest send() Algorithm
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#the-send()-method
//!
//! The send() method initiates the request. It has two paths:
//! - Asynchronous: Returns immediately, fires events as response arrives
//! - Synchronous: Blocks until response complete (Week 5)

const std = @import("std");
const Allocator = std.mem.Allocator;
const xhr_root = @import("../root.zig");
const state_machine = xhr_root.state_machine;
const XMLHttpRequestState = state_machine.XMLHttpRequestState;
const ReadyState = state_machine.ReadyState;
const ResponseProcessor = @import("response.zig").ResponseProcessor;
const UploadTracker = @import("upload.zig").UploadTracker;
const event_support = @import("../internal/event_support.zig");

// Fetch integration
const FetchIntegration = @import("fetch_integration.zig");

/// Send request
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
pub fn send(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    // Step 1: Validate state
    if (state.ready_state != .OPENED) {
        return error.InvalidStateError;
    }

    // Step 2: Check send flag
    if (state.send_flag) {
        return error.InvalidStateError;
    }

    // Step 3-7: Extract body (if provided)
    const request_body = body;

    // Step 8-10: Set flags
    state.send_flag = true;
    state.upload_complete_flag = (request_body == null or request_body.?.len == 0);

    // Step 11: Choose async or sync path
    if (!state.synchronous_flag) {
        // Async path (this week)
        try sendAsync(state, request_body);
    } else {
        // Sync path (Week 5)
        try sendSync(state, request_body);
    }
}

/// Send request asynchronously
///
/// Spec step 11: Async path
fn sendAsync(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    // Create response processor
    var processor = ResponseProcessor.init(state);

    // Create upload tracker if body exists
    var upload_tracker: ?UploadTracker = null;
    if (body) |b| {
        if (b.len > 0 and state.upload_listener_flag) {
            upload_tracker = UploadTracker.init(b.len);
        }
    }

    // Fire loadstart event
    event_support.fireProgressEvent(.loadstart, .{
        .lengthComputable = false,
        .loaded = 0,
        .total = 0,
    });

    // Fire loadstart on upload if listeners and body exists
    if (state.upload_listener_flag and body != null and body.?.len > 0) {
        const body_size = body.?.len;
        event_support.fireUploadProgressEvent(.loadstart, .{
            .lengthComputable = true,
            .loaded = 0,
            .total = body_size,
        });
    }

    // Start fetch with real Fetch infrastructure
    try FetchIntegration.fetch(state, body, &processor, &upload_tracker);
}

/// Send request synchronously (Week 5)
fn sendSync(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    _ = state;
    _ = body;
    // TODO: Week 5 implementation
    return error.NotImplemented;
}

// =============================================================================
// Tests
// =============================================================================

test "send() - requires OPENED state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Try send without open()
    const result = send(&state, null);
    try std.testing.expectError(error.InvalidStateError, result);
}

test "send() - sets send flag" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Open first
    state.ready_state = .OPENED;

    // Send
    try send(&state, null);

    // Verify send flag set
    try std.testing.expect(state.send_flag);
}

test "send() - upload complete flag for empty body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    try send(&state, null);

    // Upload should be complete for null body
    try std.testing.expect(state.upload_complete_flag);
}

test "send() - cannot send twice" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    try send(&state, null);

    // Try to send again
    const result = send(&state, null);
    try std.testing.expectError(error.InvalidStateError, result);
}
