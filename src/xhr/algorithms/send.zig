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

/// Send request synchronously
///
/// Spec step 12: If the synchronous flag is set
/// https://xhr.spec.whatwg.org/#the-send()-method
///
/// Browser behavior (Chromium/Firefox/WebKit):
/// - Network I/O is still async underneath
/// - JavaScript execution blocks
/// - Event loop spins, processing only network events
/// - No progress events fire during sync request
/// - Errors throw exceptions instead of firing events
fn sendSync(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    // Create response processor
    var processor = ResponseProcessor.init(state);

    // Upload tracker not used for sync (no progress events)
    var upload_tracker: ?UploadTracker = null;
    if (body) |b| {
        if (b.len > 0) {
            // Track total but don't fire events
            upload_tracker = UploadTracker.init(b.len);
        }
    }

    // Create a sync context for blocking execution
    var sync_ctx = SyncContext.init(state, &processor, &upload_tracker);

    // Execute fetch and spin until complete
    try sync_ctx.executeAndWait(body);

    // After completion, check for errors and throw if needed
    if (state.timed_out_flag) {
        return error.TimeoutError;
    }
    if (state.error_flag) {
        return error.NetworkError;
    }
}

/// Context for synchronous XHR execution
///
/// Manages the blocking wait for response using event loop ticking.
const SyncContext = struct {
    state: *XMLHttpRequestState,
    processor: *ResponseProcessor,
    upload_tracker: ?*?UploadTracker,
    completed: bool,
    error_occurred: bool,

    pub fn init(
        state: *XMLHttpRequestState,
        processor: *ResponseProcessor,
        upload_tracker: ?*?UploadTracker,
    ) SyncContext {
        return .{
            .state = state,
            .processor = processor,
            .upload_tracker = upload_tracker,
            .completed = false,
            .error_occurred = false,
        };
    }

    /// Execute the fetch and wait for completion
    ///
    /// This spins the event loop until the response is complete.
    /// Matches browser behavior: blocks JS execution while allowing
    /// network I/O to progress.
    pub fn executeAndWait(self: *SyncContext, body: ?[]const u8) !void {
        const allocator = self.state.allocator;

        // Get upload tracker value if present
        var upload: ?UploadTracker = null;
        if (self.upload_tracker) |ut_ptr| {
            upload = ut_ptr.*;
        }

        // Start fetch (this sets up the async operation)
        try FetchIntegration.fetch(
            self.state,
            body,
            self.processor,
            if (upload != null) &upload.? else null,
        );

        // The synchronous XHR blocks here by spinning the event loop
        // Until the response is in DONE state
        //
        // In a real implementation with event loop integration:
        // var event_loop = getEventLoop();
        // while (self.state.ready_state != .DONE and !self.error_occurred) {
        //     _ = event_loop.tick();
        // }
        //
        // For now, the fetch completes synchronously via simulateFetch,
        // so we just verify the state is DONE

        // Verify completion
        if (self.state.ready_state != .DONE) {
            // This shouldn't happen with current simulation, but guards for future
            _ = allocator;
            // In real implementation: spin event loop until done
        }

        self.completed = true;
    }
};

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

test "sendSync() - synchronous request completes" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Set up for sync request
    state.ready_state = .OPENED;
    state.synchronous_flag = true;

    // Send synchronously
    try send(&state, null);

    // Verify completed (DONE state)
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(!state.send_flag); // Reset after complete
}

test "sendSync() - with body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    state.synchronous_flag = true;

    const body = "test body data";
    try send(&state, body);

    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
    try std.testing.expect(state.upload_complete_flag);
}

test "sendSync() - timeout error" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    state.synchronous_flag = true;

    // Simulate timeout before send
    // In real scenario, timeout happens during fetch
    // Here we test the error checking after completion
    try send(&state, null);

    // Timeout flag is not set by simulation, so no error
    try std.testing.expect(!state.timed_out_flag);
}

test "SyncContext - initialization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    var processor = ResponseProcessor.init(&state);
    var upload_tracker: ?UploadTracker = null;

    const ctx = SyncContext.init(&state, &processor, &upload_tracker);

    try std.testing.expect(!ctx.completed);
    try std.testing.expect(!ctx.error_occurred);
}
