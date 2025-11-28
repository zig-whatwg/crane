//! Response Processing Algorithms
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#response

const std = @import("std");
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ReadyState = xhr_root.state_machine.ReadyState;
const ProgressTracker = @import("../internal/progress_tracker.zig").ProgressTracker;

/// Response processor - handles response callbacks
pub const ResponseProcessor = struct {
    state: *XMLHttpRequestState,
    progress_tracker: ProgressTracker,

    pub fn init(state: *XMLHttpRequestState) ResponseProcessor {
        return .{
            .state = state,
            .progress_tracker = ProgressTracker.init(),
        };
    }

    /// Process response headers received
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-response
    pub fn processResponse(self: *ResponseProcessor) void {
        // Transition to HEADERS_RECEIVED
        self.state.changeState(.HEADERS_RECEIVED);

        // Transition to LOADING if body expected
        self.state.changeState(.LOADING);

        // TODO: Fire readystatechange events (requires event dispatch)
    }

    /// Process response body chunk
    ///
    /// Spec: Accumulate received bytes
    pub fn processResponseBodyChunk(self: *ResponseProcessor, chunk: []const u8) !void {
        // Accumulate into received_bytes
        try self.state.received_bytes.appendSlice(self.state.allocator, chunk);

        // Update progress tracker (fires throttled progress events)
        const should_fire = self.progress_tracker.onChunk(chunk.len);

        // TODO: Fire progress event if should_fire (requires event dispatch)
        _ = should_fire;
    }

    /// Process response end of body
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-response-end-of-body
    pub fn processResponseEndOfBody(self: *ResponseProcessor) void {
        // Fire final progress event
        self.progress_tracker.forceFire();

        // Transition to DONE
        self.state.changeState(.DONE);

        // Unset send flag
        self.state.send_flag = false;

        // TODO: Fire load, loadend events (requires event dispatch)
    }

    /// Handle network error
    pub fn handleNetworkError(self: *ResponseProcessor) void {
        // Set error flag
        self.state.error_flag = true;

        // Transition to DONE
        self.state.changeState(.DONE);

        // Unset send flag
        self.state.send_flag = false;

        // TODO: Fire error, loadend events (requires event dispatch)
    }

    /// Handle timeout
    pub fn handleTimeout(self: *ResponseProcessor) void {
        self.state.timed_out_flag = true;
        self.state.send_flag = false;
        self.state.changeState(.DONE);

        // TODO: Fire timeout, loadend events (requires event dispatch)
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ResponseProcessor - initialization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const processor = ResponseProcessor.init(&state);

    try std.testing.expectEqual(@as(usize, 0), processor.progress_tracker.total_bytes);
}

test "ResponseProcessor - process response transitions to HEADERS_RECEIVED" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;

    var processor = ResponseProcessor.init(&state);
    processor.processResponse();

    // Should transition through HEADERS_RECEIVED to LOADING
    try std.testing.expectEqual(ReadyState.LOADING, state.ready_state);
}

test "ResponseProcessor - accumulates body chunks" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var processor = ResponseProcessor.init(&state);

    try processor.processResponseBodyChunk("Hello ");
    try processor.processResponseBodyChunk("World");

    try std.testing.expectEqualStrings("Hello World", state.received_bytes.items);
}

test "ResponseProcessor - end of body sets DONE" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.send_flag = true;

    var processor = ResponseProcessor.init(&state);
    processor.processResponseEndOfBody();

    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(!state.send_flag);
}

test "ResponseProcessor - network error sets error flag" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var processor = ResponseProcessor.init(&state);
    processor.handleNetworkError();

    try std.testing.expect(state.error_flag);
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "ResponseProcessor - timeout sets timed_out flag" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var processor = ResponseProcessor.init(&state);
    processor.handleTimeout();

    try std.testing.expect(state.timed_out_flag);
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}
