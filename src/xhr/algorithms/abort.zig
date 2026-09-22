//! XMLHttpRequest abort() Algorithm
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#the-abort()-method

const std = @import("std");
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ReadyState = xhr_root.state_machine.ReadyState;
const ResponseProcessor = @import("response.zig").ResponseProcessor;

/// The abort() method steps.
///
/// Spec: https://xhr.spec.whatwg.org/#the-abort()-method
///
/// 1. Abort this's fetch controller.
/// 2. If this's state is opened with this's send() flag set, headers received,
///    or loading, then run the request error steps for this and `abort`.
/// 3. If this's state is done, then set this's state to unsent and set this's
///    response to a network error.
///
/// That is the whole algorithm. This file used to carry its own hand-inlined
/// copy of the request error steps AND finish by calling `state.reset()` -
/// which is open() step 11, not anything abort() does. `reset()` clears the
/// upload complete flag that step 6.1 has just SET, so `abort()` ended by
/// undoing part of its own work. The events now come from the one
/// implementation of the request error steps, in `response.zig`.
pub fn abort(state: *XMLHttpRequestState) void {
    // Step 1: Abort this's fetch controller.
    terminateFetch(state);

    // Step 2: run the request error steps for `abort`.
    if ((state.ready_state == .OPENED and state.send_flag) or
        state.ready_state == .HEADERS_RECEIVED or
        state.ready_state == .LOADING)
    {
        var processor = ResponseProcessor.init(state);
        processor.requestErrorSteps(.abort);
    }

    // Step 3: If this's state is done, set it to unsent and set this's response
    // to a network error.
    //
    // Spec note: "No readystatechange event is dispatched." So this assigns the
    // field rather than going through `changeState`, and fires nothing.
    if (state.ready_state == .DONE) {
        state.ready_state = .UNSENT;
        state.setResponseToNetworkError();
    }
}

/// Terminate the ongoing fetch operation
///
/// TODO: Integrate with FetchController.abort() when available. Until then an
/// abort() during a blocking fetch takes effect when the fetch returns, not
/// when abort() is called.
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

test "abort - keeps the request method and URL" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .LOADING;
    state.send_flag = true;
    state.request_method = try allocator.dupe(u8, "POST");
    state.request_url = try allocator.dupe(u8, "http://example.com");

    abort(&state);

    // The abort() steps are: abort the fetch controller, run the request error
    // steps, and set the state to unsent with a network-error response. They do
    // NOT empty the request method, the request URL or the author request
    // headers - that is open() step 11, "set variables associated with the
    // object", which runs when a NEW request is opened.
    //
    // This test previously asserted the opposite, because `abort()` ended with
    // a call to `state.reset()`. That call also cleared the upload complete
    // flag the request error steps had just set, so the two abort tests could
    // not both pass.
    try std.testing.expectEqualStrings("POST", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com", state.request_url.?);

    // What abort() does promise:
    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(state.isNetworkError());
}
