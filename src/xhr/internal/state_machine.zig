//! XMLHttpRequest State Machine
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/#states
//!
//! The XMLHttpRequest object has an associated state, which is one of:
//! - UNSENT (0)
//! - OPENED (1)
//! - HEADERS_RECEIVED (2)
//! - LOADING (3)
//! - DONE (4)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// XMLHttpRequest ready states
///
/// Spec: https://xhr.spec.whatwg.org/#states
pub const ReadyState = enum(u16) {
    UNSENT = 0,
    OPENED = 1,
    HEADERS_RECEIVED = 2,
    LOADING = 3,
    DONE = 4,
};

/// Response type enum
pub const ResponseType = enum {
    empty, // "" - text or document based on MIME
    text, // text string
    arraybuffer, // ArrayBuffer
    blob, // Blob
    document, // Document (stubbed)
    json, // parsed JSON
};

/// XMLHttpRequest internal state
///
/// Spec: https://xhr.spec.whatwg.org/#xmlhttprequest
///
/// Each XMLHttpRequest object has the following associated state:
pub const XMLHttpRequestState = struct {
    /// Ready state (UNSENT, OPENED, HEADERS_RECEIVED, LOADING, DONE)
    ready_state: ReadyState,

    /// Send flag - set when send() has been invoked
    send_flag: bool,

    /// Upload complete flag
    upload_complete_flag: bool,

    /// Upload listener flag - true if upload has event listeners
    upload_listener_flag: bool,

    /// Timed out flag - set when request times out
    timed_out_flag: bool,

    /// Synchronous flag - true for synchronous requests
    synchronous_flag: bool,

    /// Error flag
    error_flag: bool,

    // Request state

    /// Request method (GET, POST, etc.)
    request_method: ?[]const u8,

    /// Request URL
    request_url: ?[]const u8,

    /// Request headers
    request_headers: std.StringHashMapUnmanaged([]const u8),

    /// Request body
    request_body: ?[]const u8,

    // Response state

    /// Response (from Fetch)
    response: ?*anyopaque, // TODO: InternalResponse type

    /// Received bytes (accumulated response body)
    received_bytes: std.ArrayListUnmanaged(u8),

    // Configuration

    /// Timeout in milliseconds (0 = no timeout)
    timeout: u64,

    /// with credentials flag (CORS)
    with_credentials: bool,

    /// Response type
    response_type: ResponseType,

    /// Allocator
    allocator: Allocator,

    /// Initialize state
    pub fn init(allocator: Allocator) XMLHttpRequestState {
        return .{
            .ready_state = .UNSENT,
            .send_flag = false,
            .upload_complete_flag = false,
            .upload_listener_flag = false,
            .timed_out_flag = false,
            .synchronous_flag = false,
            .error_flag = false,
            .request_method = null,
            .request_url = null,
            .request_headers = .{},
            .request_body = null,
            .response = null,
            .received_bytes = .{},
            .timeout = 0,
            .with_credentials = false,
            .response_type = .empty,
            .allocator = allocator,
        };
    }

    /// Clean up state
    pub fn deinit(self: *XMLHttpRequestState) void {
        if (self.request_method) |m| self.allocator.free(m);
        if (self.request_url) |u| self.allocator.free(u);
        if (self.request_body) |b| self.allocator.free(b);

        // Free headers
        var it = self.request_headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.request_headers.deinit(self.allocator);

        self.received_bytes.deinit(self.allocator);
    }

    /// Change ready state and fire readystatechange event
    ///
    /// Spec: When the ready state changes, fire readystatechange event
    pub fn changeState(self: *XMLHttpRequestState, new_state: ReadyState) void {
        if (self.ready_state != new_state) {
            self.ready_state = new_state;
            // Event firing will be handled by caller
            // (requires access to XMLHttpRequest instance to dispatch event)
        }
    }

    /// Reset state (called by open())
    pub fn reset(self: *XMLHttpRequestState) void {
        // Clear request state
        if (self.request_method) |m| {
            self.allocator.free(m);
            self.request_method = null;
        }
        if (self.request_url) |u| {
            self.allocator.free(u);
            self.request_url = null;
        }
        if (self.request_body) |b| {
            self.allocator.free(b);
            self.request_body = null;
        }

        // Clear headers
        var it = self.request_headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.request_headers.clearRetainingCapacity();

        // Clear response
        self.response = null;
        self.received_bytes.clearRetainingCapacity();

        // Reset flags
        self.send_flag = false;
        self.upload_complete_flag = false;
        self.upload_listener_flag = false;
        self.timed_out_flag = false;
        self.error_flag = false;
    }
};

test "State - initialization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(!state.synchronous_flag);
    try std.testing.expectEqual(@as(u64, 0), state.timeout);
}

test "State - change state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.changeState(.OPENED);
    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);

    state.changeState(.HEADERS_RECEIVED);
    try std.testing.expectEqual(ReadyState.HEADERS_RECEIVED, state.ready_state);

    state.changeState(.LOADING);
    try std.testing.expectEqual(ReadyState.LOADING, state.ready_state);

    state.changeState(.DONE);
    try std.testing.expectEqual(ReadyState.DONE, state.ready_state);
}

test "State - reset" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Set some state
    state.request_method = try allocator.dupe(u8, "POST");
    state.request_url = try allocator.dupe(u8, "http://example.com");
    state.send_flag = true;
    state.error_flag = true;

    // Reset
    state.reset();

    // Verify cleared
    try std.testing.expect(state.request_method == null);
    try std.testing.expect(state.request_url == null);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(!state.error_flag);
}
