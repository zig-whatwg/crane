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

// Fetch Standard types for spec compliance
// Using the fetch module (wired in build.zig)
const fetch = @import("fetch");
const InternalResponse = fetch.internal.InternalResponse;
const HeaderList = fetch.internal.HeaderList;
const FetchController = fetch.internal.FetchController;
const networkError = fetch.internal.networkError;

// MIME types for response handling
const mimesniff = @import("mimesniff");
const MimeType = mimesniff.MimeType;

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
///
/// Spec: https://xhr.spec.whatwg.org/#dom-xmlhttprequest-responsetype
pub const ResponseType = enum {
    empty, // "" - text or document based on MIME
    text, // "text" - text string
    arraybuffer, // "arraybuffer" - ArrayBuffer
    blob, // "blob" - Blob
    document, // "document" - Document
    json, // "json" - parsed JSON

    /// Convert from string value (as used in WebIDL)
    pub fn fromString(s: []const u8) ?ResponseType {
        if (s.len == 0) return .empty;
        if (std.mem.eql(u8, s, "text")) return .text;
        if (std.mem.eql(u8, s, "arraybuffer")) return .arraybuffer;
        if (std.mem.eql(u8, s, "blob")) return .blob;
        if (std.mem.eql(u8, s, "document")) return .document;
        if (std.mem.eql(u8, s, "json")) return .json;
        return null;
    }

    /// Convert to string value (as used in WebIDL)
    pub fn toString(self: ResponseType) []const u8 {
        return switch (self) {
            .empty => "",
            .text => "text",
            .arraybuffer => "arraybuffer",
            .blob => "blob",
            .document => "document",
            .json => "json",
        };
    }
};

/// Response object state (for caching parsed response)
///
/// Spec: "response object" - An object, failure, or null
pub const ResponseObject = union(enum) {
    null_value,
    failure,
    text: []const u8,
    array_buffer: []const u8,
    blob: []const u8, // Blob data (type stored separately)
    json: []const u8, // Parsed JSON string (actual parsing is JS-side)
    // document: *Document, // TODO: When DOM is implemented
};

/// XMLHttpRequest internal state
///
/// Spec: https://xhr.spec.whatwg.org/#xmlhttprequest
///
/// Each XMLHttpRequest object has the following associated state:
pub const XMLHttpRequestState = struct {
    // =========================================================================
    // Ready state
    // =========================================================================

    /// Ready state (UNSENT, OPENED, HEADERS_RECEIVED, LOADING, DONE)
    /// Spec: "state" - one of unsent, opened, headers received, loading, done
    ready_state: ReadyState,

    // =========================================================================
    // Flags
    // =========================================================================

    /// Send flag - set when send() has been invoked
    /// Spec: "send() flag"
    send_flag: bool,

    /// Upload complete flag
    /// Spec: "upload complete flag"
    upload_complete_flag: bool,

    /// Upload listener flag - true if upload has event listeners
    /// Spec: "upload listener flag"
    upload_listener_flag: bool,

    /// Timed out flag - set when request times out
    /// Spec: "timed out flag"
    timed_out_flag: bool,

    /// Synchronous flag - true for synchronous requests
    /// Spec: "synchronous flag"
    synchronous_flag: bool,

    // =========================================================================
    // Request state
    // =========================================================================

    /// Request method (GET, POST, etc.)
    /// Spec: "request method"
    request_method: ?[]const u8,

    /// Request URL (parsed)
    /// Spec: "request URL"
    request_url: ?[]const u8,

    /// Author request headers (using Fetch's HeaderList for spec compliance)
    /// Spec: "author request headers" - A header list
    author_request_headers: HeaderList,

    /// Request body
    /// Spec: "request body" - initially null
    request_body: ?[]const u8,

    // =========================================================================
    // Response state
    // =========================================================================

    /// Response (from Fetch)
    /// Spec: "response" - A response, initially a network error
    response: ?*InternalResponse,

    /// Received bytes (accumulated response body)
    /// Spec: "received bytes" - A byte sequence, initially empty
    received_bytes: std.ArrayListUnmanaged(u8),

    /// Response object (cached parsed response)
    /// Spec: "response object" - An object, failure, or null
    response_object: ResponseObject,

    /// Fetch controller
    /// Spec: "fetch controller" - A fetch controller, initially a new fetch controller
    fetch_controller: ?*FetchController,

    /// Override MIME type
    /// Spec: "override MIME type" - A MIME type or null
    override_mime_type: ?MimeType,

    // =========================================================================
    // Configuration
    // =========================================================================

    /// Timeout in milliseconds (0 = no timeout)
    /// Spec: "timeout" - An unsigned integer, initially 0
    timeout: u32,

    /// Cross-origin credentials flag (CORS)
    /// Spec: "cross-origin credentials" - A boolean, initially false
    cross_origin_credentials: bool,

    /// Response type
    /// Spec: "response type" - One of the empty string, "arraybuffer", etc.
    response_type: ResponseType,

    // =========================================================================
    // Internal
    // =========================================================================

    /// Allocator for memory management
    allocator: Allocator,

    /// Initialize state
    ///
    /// Spec: Constructor steps set initial values
    pub fn init(allocator: Allocator) XMLHttpRequestState {
        return .{
            // Ready state
            .ready_state = .UNSENT,

            // Flags (all initially unset)
            .send_flag = false,
            .upload_complete_flag = false,
            .upload_listener_flag = false,
            .timed_out_flag = false,
            .synchronous_flag = false,

            // Request state
            .request_method = null,
            .request_url = null,
            .author_request_headers = HeaderList.init(allocator),
            .request_body = null,

            // Response state (response is initially a network error per spec)
            .response = null, // Will be set to network error on first access if needed
            .received_bytes = .{},
            .response_object = .null_value,
            .fetch_controller = null,
            .override_mime_type = null,

            // Configuration
            .timeout = 0,
            .cross_origin_credentials = false,
            .response_type = .empty,

            // Internal
            .allocator = allocator,
        };
    }

    /// Clean up state
    pub fn deinit(self: *XMLHttpRequestState) void {
        // Free request state
        if (self.request_method) |m| self.allocator.free(m);
        if (self.request_url) |u| self.allocator.free(u);
        if (self.request_body) |b| self.allocator.free(b);

        // Free author request headers (using Fetch's HeaderList)
        self.author_request_headers.deinit();

        // Free response
        if (self.response) |r| r.deinit();

        // Free received bytes
        self.received_bytes.deinit(self.allocator);

        // Free response object data if allocated
        switch (self.response_object) {
            .text => |t| self.allocator.free(t),
            .array_buffer => |a| self.allocator.free(a),
            .blob => |b| self.allocator.free(b),
            .json => |j| self.allocator.free(j),
            else => {},
        }

        // Free fetch controller
        if (self.fetch_controller) |fc| fc.deinit();

        // Free override MIME type
        if (self.override_mime_type) |*m| m.deinit();
    }

    /// Change ready state
    ///
    /// Spec: When the ready state changes, fire readystatechange event
    /// Note: Event firing is handled by caller (requires access to XHR instance)
    pub fn changeState(self: *XMLHttpRequestState, new_state: ReadyState) void {
        if (self.ready_state != new_state) {
            self.ready_state = new_state;
            // Event firing handled by caller
        }
    }

    /// Reset state (called by open())
    ///
    /// Spec: Step 11 of open() - "Set variables associated with the object"
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

        // Empty author request headers
        // Spec: "Empty this's author request headers"
        self.author_request_headers.deinit();
        self.author_request_headers = HeaderList.init(self.allocator);

        // Set response to network error
        // Spec: "Set this's response to a network error"
        if (self.response) |r| r.deinit();
        self.response = null; // Will be set to network error on access

        // Clear received bytes
        // Spec: "Set this's received bytes to the empty byte sequence"
        self.received_bytes.clearRetainingCapacity();

        // Set response object to null
        // Spec: "Set this's response object to null"
        switch (self.response_object) {
            .text => |t| self.allocator.free(t),
            .array_buffer => |a| self.allocator.free(a),
            .blob => |b| self.allocator.free(b),
            .json => |j| self.allocator.free(j),
            else => {},
        }
        self.response_object = .null_value;

        // Reset flags
        // Spec: "Unset this's send() flag"
        self.send_flag = false;
        // Spec: "Unset this's upload listener flag"
        self.upload_listener_flag = false;
        // Note: upload complete flag, timed out flag are reset on send()
        self.upload_complete_flag = false;
        self.timed_out_flag = false;

        // Note: override_mime_type is NOT reset per spec:
        // "Override MIME type is not overridden here as the overrideMimeType()
        // method can be invoked before the open() method."
    }

    /// Get the response, creating a network error if null
    ///
    /// Per spec, response is "initially a network error"
    pub fn getResponse(self: *XMLHttpRequestState) !*InternalResponse {
        if (self.response) |r| {
            return r;
        }
        // Create network error on first access
        const err_response = try networkError(self.allocator);
        self.response = err_response;
        return err_response;
    }

    /// Check if response is a network error
    pub fn isNetworkError(self: *const XMLHttpRequestState) bool {
        if (self.response) |r| {
            return r.response_type == .@"error";
        }
        return true; // null response is treated as network error
    }
};

test "State - initialization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expectEqual(ReadyState.UNSENT, state.ready_state);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(!state.synchronous_flag);
    try std.testing.expectEqual(@as(u32, 0), state.timeout);
    try std.testing.expect(!state.cross_origin_credentials);
    try std.testing.expectEqual(ResponseType.empty, state.response_type);
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
    state.timed_out_flag = true;

    // Reset
    state.reset();

    // Verify cleared
    try std.testing.expect(state.request_method == null);
    try std.testing.expect(state.request_url == null);
    try std.testing.expect(!state.send_flag);
    try std.testing.expect(!state.timed_out_flag);
}

test "State - author request headers" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Add headers using Fetch's HeaderList
    try state.author_request_headers.append("Content-Type", "application/json");
    try state.author_request_headers.append("Accept", "application/json");

    try std.testing.expect(state.author_request_headers.contains("Content-Type"));
    try std.testing.expect(state.author_request_headers.contains("Accept"));
    try std.testing.expectEqual(@as(usize, 2), state.author_request_headers.len());

    // Reset should clear headers
    state.reset();
    try std.testing.expect(!state.author_request_headers.contains("Content-Type"));
    try std.testing.expectEqual(@as(usize, 0), state.author_request_headers.len());
}

test "State - response type conversion" {
    try std.testing.expectEqual(ResponseType.empty, ResponseType.fromString("").?);
    try std.testing.expectEqual(ResponseType.text, ResponseType.fromString("text").?);
    try std.testing.expectEqual(ResponseType.arraybuffer, ResponseType.fromString("arraybuffer").?);
    try std.testing.expectEqual(ResponseType.blob, ResponseType.fromString("blob").?);
    try std.testing.expectEqual(ResponseType.document, ResponseType.fromString("document").?);
    try std.testing.expectEqual(ResponseType.json, ResponseType.fromString("json").?);
    try std.testing.expect(ResponseType.fromString("invalid") == null);

    try std.testing.expectEqualStrings("", ResponseType.empty.toString());
    try std.testing.expectEqualStrings("text", ResponseType.text.toString());
    try std.testing.expectEqualStrings("arraybuffer", ResponseType.arraybuffer.toString());
}

test "State - isNetworkError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Initially null response is treated as network error
    try std.testing.expect(state.isNetworkError());

    // getResponse creates a network error
    _ = try state.getResponse();
    try std.testing.expect(state.isNetworkError());
}
