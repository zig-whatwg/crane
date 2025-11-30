//! XMLHttpRequest abort() Algorithm
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#the-abort()-method
//!
//! The abort() method cancels any network activity and resets the XHR object.

const std = @import("std");
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ReadyState = xhr_root.state_machine.ReadyState;
const event_support = @import("../internal/event_support.zig");

/// Abort the XMLHttpRequest
///
/// Spec: https://xhr.spec.whatwg.org/#the-abort()-method
///
/// Steps:
/// 1. Terminate any ongoing fetch (via fetch controller)
/// 2. If state is OPENED with send flag, HEADERS_RECEIVED, or LOADING:
///    - Set state to DONE
///    - Fire readystatechange event
///    - If upload complete flag is unset:
///      - Set upload complete flag
///      - Fire abort on upload object
///      - Fire loadend on upload object
///    - Fire abort event
///    - Fire loadend event
/// 3. If state is DONE:
///    - Reset to UNSENT (no events)
pub fn abort(state: *XMLHttpRequestState) void {
    // Step 1: Terminate any ongoing fetch
    // TODO: Call fetch_controller.abort() when integrated
    terminateFetch(state);

    // Step 2: Handle based on state
    const current_state = state.ready_state;
    const send_flag = state.send_flag;

    if ((current_state == .OPENED and send_flag) or
        current_state == .HEADERS_RECEIVED or
        current_state == .LOADING)
    {
        // Transition to DONE and fire events
        abortWithEvents(state);
    } else if (current_state == .DONE) {
        // Just reset to UNSENT (no events)
        resetToUnsent(state);
    }
    // If UNSENT or OPENED without send flag, do nothing
}

/// Abort with events (for active requests)
fn abortWithEvents(state: *XMLHttpRequestState) void {
    // Set state to DONE
    state.changeState(.DONE);

    // Unset send flag
    state.send_flag = false;

    // Fire readystatechange event
    event_support.fireEvent(.readystatechange);

    // Handle upload events if upload not complete
    if (!state.upload_complete_flag) {
        state.upload_complete_flag = true;

        // Fire abort on upload object
        event_support.fireUploadProgressEvent(.abort, .{
            .lengthComputable = false,
            .loaded = 0,
            .total = 0,
        });

        // Fire loadend on upload object
        event_support.fireUploadProgressEvent(.loadend, .{
            .lengthComputable = false,
            .loaded = 0,
            .total = 0,
        });
    }

    // Fire abort event on XHR
    event_support.fireProgressEvent(.abort, .{
        .lengthComputable = false,
        .loaded = 0,
        .total = 0,
    });

    // Fire loadend event on XHR
    event_support.fireProgressEvent(.loadend, .{
        .lengthComputable = false,
        .loaded = 0,
        .total = 0,
    });

    // Reset to UNSENT for next request
    resetToUnsent(state);
}

/// Reset state to UNSENT (no events)
fn resetToUnsent(state: *XMLHttpRequestState) void {
    state.ready_state = .UNSENT;

    // Clear request/response data
    state.reset();
}

/// Terminate the ongoing fetch operation
///
/// TODO: Integrate with FetchController.abort() when available
fn terminateFetch(state: *XMLHttpRequestState) void {
    // When integrated with Fetch:
    // if (state.fetch_controller) |controller| {
    //     controller.abort();
    // }
    _ = state;
}

// =============================================================================
// Tests
// =============================================================================

test "abort - UNSENT state does nothing" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    abort(&state);

    // Should remain UNSENT
    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
}

test "abort - OPENED without send flag does nothing" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    state.send_flag = false;

    abort(&state);

    // Should remain OPENED
    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
}

test "abort - OPENED with send flag fires events and resets" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    state.send_flag = true;

    abort(&state);

    // Should be reset to UNSENT
    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
}

test "abort - HEADERS_RECEIVED fires events and resets" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .HEADERS_RECEIVED;
    state.send_flag = true;

    abort(&state);

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
}

test "abort - LOADING fires events and resets" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .LOADING;
    state.send_flag = true;
    state.upload_complete_flag = false;

    abort(&state);

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(state.upload_complete_flag); // Should be set
}

test "abort - DONE just resets without events" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.send_flag = false;

    abort(&state);

    // Should be reset to UNSENT
    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
}

test "abort - clears request data" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Set some request data
    state.ready_state = .LOADING;
    state.send_flag = true;
    state.request_method = try allocator.dupe(u8, "POST");
    state.request_url = try allocator.dupe(u8, "http://example.com");

    abort(&state);

    // Should be cleared
    try std.testing.expect(state.request_method == null);
    try std.testing.expect(state.request_url == null);
}
