//! XMLHttpRequest Timeout Handling
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#the-timeout-attribute
//!
//! The timeout attribute controls how long a request can run before being aborted.
//!
//! Behavior:
//! - Async: Fire timeout event, then loadend event
//! - Sync: Throw TimeoutError exception
//!
//! Restrictions:
//! - Cannot set timeout on sync XHR in Window context (deprecated behavior)
//! - Timeout is in milliseconds
//! - 0 means no timeout

const std = @import("std");
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ReadyState = xhr_root.state_machine.ReadyState;
const event_support = @import("../internal/event_support.zig");

/// Error types for timeout operations
pub const TimeoutError = error{
    InvalidAccessError,
    TimeoutError,
};

/// Set the timeout value
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-timeout
///
/// Steps:
/// 1. If in Window context and synchronous flag is set, throw InvalidAccessError
///    (This is deprecated behavior but still required for spec compliance)
/// 2. Set timeout to the given value
pub fn setTimeout(
    state: *XMLHttpRequestState,
    timeout_ms: u64,
    in_window_context: bool,
) TimeoutError!void {
    // Step 1: Check for deprecated sync XHR timeout in Window
    if (in_window_context and state.synchronous_flag) {
        return TimeoutError.InvalidAccessError;
    }

    // Step 2: Set timeout
    state.timeout = timeout_ms;
}

/// Get the timeout value
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-timeout
pub fn getTimeout(state: *const XMLHttpRequestState) u64 {
    return state.timeout;
}

/// Check if a request should be timed out
///
/// Called periodically during request processing.
/// Returns true if the timeout has elapsed.
pub fn shouldTimeout(state: *const XMLHttpRequestState, elapsed_ms: u64) bool {
    if (state.timeout == 0) {
        return false; // No timeout set
    }

    return elapsed_ms >= state.timeout;
}

/// Handle timeout occurrence
///
/// For async requests: sets timeout flag and fires events
/// For sync requests: caller should throw TimeoutError
///
/// Spec: https://xhr.spec.whatwg.org/#timeout-error
pub fn handleTimeout(state: *XMLHttpRequestState) void {
    // Set timeout flag
    state.timed_out_flag = true;

    // Unset send flag
    state.send_flag = false;

    // Transition to DONE
    state.changeState(.DONE);

    // Fire readystatechange event
    event_support.fireEvent(.readystatechange);

    // Fire timeout event (for async)
    event_support.fireProgressEvent(.timeout, .{
        .lengthComputable = false,
        .loaded = 0,
        .total = 0,
    });

    // Fire loadend event
    event_support.fireProgressEvent(.loadend, .{
        .lengthComputable = false,
        .loaded = 0,
        .total = 0,
    });
}

/// Timer state for tracking request duration
pub const TimeoutTimer = struct {
    start_time: i64,
    timeout_ms: u64,

    /// Create a new timeout timer
    pub fn init(timeout_ms: u64) TimeoutTimer {
        return .{
            .start_time = std.time.milliTimestamp(),
            .timeout_ms = timeout_ms,
        };
    }

    /// Check if the timeout has elapsed
    pub fn hasElapsed(self: *const TimeoutTimer) bool {
        if (self.timeout_ms == 0) {
            return false; // No timeout
        }

        const now = std.time.milliTimestamp();
        const elapsed = now - self.start_time;

        return elapsed >= @as(i64, @intCast(self.timeout_ms));
    }

    /// Get elapsed time in milliseconds
    pub fn getElapsedMs(self: *const TimeoutTimer) u64 {
        const now = std.time.milliTimestamp();
        const elapsed = now - self.start_time;

        if (elapsed < 0) return 0;
        return @intCast(elapsed);
    }

    /// Reset the timer
    pub fn reset(self: *TimeoutTimer) void {
        self.start_time = std.time.milliTimestamp();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "setTimeout - sets timeout value" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try setTimeout(&state, 5000, false);

    try std.testing.expectEqual(@as(u64, 5000), state.timeout);
}

test "setTimeout - sync XHR in Window throws" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.synchronous_flag = true;

    const result = setTimeout(&state, 5000, true);
    try std.testing.expectError(TimeoutError.InvalidAccessError, result);
}

test "setTimeout - sync XHR not in Window is allowed" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.synchronous_flag = true;

    // Not in Window context - should be allowed
    try setTimeout(&state, 5000, false);
    try std.testing.expectEqual(@as(u64, 5000), state.timeout);
}

test "getTimeout - returns timeout value" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.timeout = 3000;

    try std.testing.expectEqual(@as(u64, 3000), getTimeout(&state));
}

test "shouldTimeout - no timeout returns false" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.timeout = 0;

    try std.testing.expect(!shouldTimeout(&state, 999999));
}

test "shouldTimeout - returns true when elapsed" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.timeout = 5000;

    try std.testing.expect(!shouldTimeout(&state, 4999));
    try std.testing.expect(shouldTimeout(&state, 5000));
    try std.testing.expect(shouldTimeout(&state, 5001));
}

test "handleTimeout - sets flags and state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .LOADING;
    state.send_flag = true;

    handleTimeout(&state);

    try std.testing.expect(state.timed_out_flag);
    try std.testing.expect(!state.send_flag);
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "TimeoutTimer - init and elapsed" {
    const timer = TimeoutTimer.init(100);

    // Immediately after init, should not be elapsed
    try std.testing.expect(!timer.hasElapsed());

    // Elapsed time should be very small
    const elapsed = timer.getElapsedMs();
    try std.testing.expect(elapsed < 50);
}

test "TimeoutTimer - no timeout never elapses" {
    const timer = TimeoutTimer.init(0);

    try std.testing.expect(!timer.hasElapsed());
}
