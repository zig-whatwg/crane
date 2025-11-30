//! Response Processing Algorithms
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#response
//!
//! This module handles:
//! - Response processing callbacks (headers, body chunks, end of body)
//! - Response type conversion (text, arraybuffer, blob, json, document)
//! - Error and timeout handling
//!
//! Response Types (WHATWG XHR §4.3):
//! - "" (empty): Returns text or document based on MIME type
//! - "text": Returns decoded text string
//! - "arraybuffer": Returns ArrayBuffer with raw bytes
//! - "blob": Returns Blob object
//! - "json": Returns parsed JSON or null on parse error
//! - "document": Returns Document (stubbed - requires HTML/XML parsers)

const std = @import("std");
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ReadyState = xhr_root.state_machine.ReadyState;
const ResponseType = xhr_root.state_machine.ResponseType;
const ProgressTracker = @import("../internal/progress_tracker.zig").ProgressTracker;
const event_support = @import("../internal/event_support.zig");
const XHREventType = event_support.XHREventType;
const ProgressEventData = event_support.ProgressEventData;

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
        event_support.fireEvent(.readystatechange);

        // Transition to LOADING if body expected
        self.state.changeState(.LOADING);
        event_support.fireEvent(.readystatechange);
    }

    /// Process response body chunk
    ///
    /// Spec: Accumulate received bytes
    pub fn processResponseBodyChunk(self: *ResponseProcessor, chunk: []const u8) !void {
        // Accumulate into received_bytes
        try self.state.received_bytes.appendSlice(self.state.allocator, chunk);

        // Update progress tracker (fires throttled progress events)
        const should_fire = self.progress_tracker.onChunk(chunk.len);

        // Fire progress event if throttle passed
        if (should_fire) {
            const progress_info = self.progress_tracker.getProgress();
            event_support.fireProgressEvent(.progress, .{
                .lengthComputable = progress_info.length_computable,
                .loaded = progress_info.loaded,
                .total = progress_info.total orelse 0,
            });
        }
    }

    /// Process response end of body
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-response-end-of-body
    pub fn processResponseEndOfBody(self: *ResponseProcessor) void {
        // Fire final progress event
        self.progress_tracker.forceFire();
        const final_progress = self.progress_tracker.getProgress();
        event_support.fireProgressEvent(.progress, .{
            .lengthComputable = final_progress.length_computable,
            .loaded = final_progress.loaded,
            .total = final_progress.total orelse 0,
        });

        // Transition to DONE
        self.state.changeState(.DONE);
        event_support.fireEvent(.readystatechange);

        // Unset send flag
        self.state.send_flag = false;

        // Fire load event
        event_support.fireProgressEvent(.load, .{
            .lengthComputable = final_progress.length_computable,
            .loaded = final_progress.loaded,
            .total = final_progress.total orelse 0,
        });

        // Fire loadend event
        event_support.fireProgressEvent(.loadend, .{
            .lengthComputable = final_progress.length_computable,
            .loaded = final_progress.loaded,
            .total = final_progress.total orelse 0,
        });
    }

    /// Handle network error
    pub fn handleNetworkError(self: *ResponseProcessor) void {
        // Set error flag
        self.state.error_flag = true;

        // Transition to DONE
        self.state.changeState(.DONE);
        event_support.fireEvent(.readystatechange);

        // Unset send flag
        self.state.send_flag = false;

        // Fire error event
        const progress = self.progress_tracker.getProgress();
        event_support.fireProgressEvent(.@"error", .{
            .lengthComputable = progress.length_computable,
            .loaded = progress.loaded,
            .total = progress.total orelse 0,
        });

        // Fire loadend event
        event_support.fireProgressEvent(.loadend, .{
            .lengthComputable = progress.length_computable,
            .loaded = progress.loaded,
            .total = progress.total orelse 0,
        });
    }

    /// Handle timeout
    pub fn handleTimeout(self: *ResponseProcessor) void {
        self.state.timed_out_flag = true;
        self.state.send_flag = false;
        self.state.changeState(.DONE);
        event_support.fireEvent(.readystatechange);

        // Fire timeout event
        const progress = self.progress_tracker.getProgress();
        event_support.fireProgressEvent(.timeout, .{
            .lengthComputable = progress.length_computable,
            .loaded = progress.loaded,
            .total = progress.total orelse 0,
        });

        // Fire loadend event
        event_support.fireProgressEvent(.loadend, .{
            .lengthComputable = progress.length_computable,
            .loaded = progress.loaded,
            .total = progress.total orelse 0,
        });
    }
};

// =============================================================================
// Response Type Handling
// =============================================================================

/// Response value - result of getting .response property
///
/// Spec: https://xhr.spec.whatwg.org/#response
pub const ResponseValue = union(enum) {
    /// Empty (when state is not DONE or error occurred)
    empty,
    /// Text response (for responseType "" or "text")
    text: []const u8,
    /// ArrayBuffer response (raw bytes)
    arraybuffer: []const u8,
    /// Blob response (bytes with MIME type)
    blob: BlobValue,
    /// JSON response (parsed JSON as string, null on parse error)
    json: ?[]const u8,
    /// Document response (stubbed)
    document: void,
    /// Error case
    @"error": ResponseError,

    pub const BlobValue = struct {
        data: []const u8,
        mime_type: []const u8,
    };

    pub const ResponseError = enum {
        invalid_state,
        parse_error,
    };

    /// Free allocated memory
    pub fn deinit(self: *ResponseValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text => |text| allocator.free(text),
            .arraybuffer => |buf| allocator.free(buf),
            .blob => |blob| {
                allocator.free(blob.data);
                allocator.free(blob.mime_type);
            },
            .json => |maybe_json| {
                if (maybe_json) |json| allocator.free(json);
            },
            .empty, .document, .@"error" => {},
        }
    }
};

/// Get the response based on responseType
///
/// Spec: https://xhr.spec.whatwg.org/#the-response-attribute
///
/// Returns the response entity body based on the value of responseType:
/// - "" or "text": Text string (decoded using character encoding)
/// - "arraybuffer": ArrayBuffer containing response bytes
/// - "blob": Blob object containing response bytes
/// - "json": Parsed JSON object (or null on parse error)
/// - "document": Document (stubbed - requires HTML/XML parsers)
pub fn getResponse(state: *const XMLHttpRequestState) !ResponseValue {
    const allocator = state.allocator;

    // Step 1: If responseType is empty or text
    if (state.response_type == .empty or state.response_type == .text) {
        return getTextResponse(state);
    }

    // Step 2: If state is not DONE, return null
    if (state.ready_state != .DONE) {
        return .empty;
    }

    // Step 3: If error flag is set, return null
    if (state.error_flag) {
        return .{ .@"error" = .invalid_state };
    }

    // Handle based on responseType
    return switch (state.response_type) {
        .arraybuffer => getArrayBufferResponse(allocator, state),
        .blob => getBlobResponse(allocator, state),
        .json => getJsonResponse(allocator, state),
        .document => .document, // Stubbed
        .empty, .text => unreachable, // Handled above
    };
}

/// Get text response
///
/// Spec: https://xhr.spec.whatwg.org/#text-response
fn getTextResponse(state: *const XMLHttpRequestState) ResponseValue {
    // For text response, we can return during LOADING too
    if (state.ready_state != .LOADING and state.ready_state != .DONE) {
        return .{ .text = "" };
    }

    if (state.error_flag) {
        return .{ .text = "" };
    }

    // Return received bytes as text
    // TODO: Apply character encoding detection/conversion
    const text = state.received_bytes.items;
    return .{ .text = text };
}

/// Get ArrayBuffer response
///
/// Spec: https://xhr.spec.whatwg.org/#arraybuffer-response
fn getArrayBufferResponse(allocator: std.mem.Allocator, state: *const XMLHttpRequestState) !ResponseValue {
    // Copy received bytes into owned slice
    const data = try allocator.dupe(u8, state.received_bytes.items);
    return .{ .arraybuffer = data };
}

/// Get Blob response
///
/// Spec: https://xhr.spec.whatwg.org/#blob-response
fn getBlobResponse(allocator: std.mem.Allocator, state: *const XMLHttpRequestState) !ResponseValue {
    // Copy received bytes
    const data = try allocator.dupe(u8, state.received_bytes.items);
    errdefer allocator.free(data);

    // Get MIME type from response headers
    // TODO: Extract from actual response headers
    const mime_type = try allocator.dupe(u8, "application/octet-stream");

    return .{ .blob = .{
        .data = data,
        .mime_type = mime_type,
    } };
}

/// Get JSON response
///
/// Spec: https://xhr.spec.whatwg.org/#json-response
fn getJsonResponse(allocator: std.mem.Allocator, state: *const XMLHttpRequestState) !ResponseValue {
    const text = state.received_bytes.items;

    // Try to parse as JSON to validate
    // For now, just validate it's valid JSON and return the string
    if (text.len == 0) {
        return .{ .json = null };
    }

    // Validate JSON structure
    if (!isValidJson(text)) {
        return .{ .json = null };
    }

    // Return the JSON string (caller would parse in JS)
    const json = try allocator.dupe(u8, text);
    return .{ .json = json };
}

/// Basic JSON validation
///
/// Checks if the input looks like valid JSON.
/// This is a simplified check - real implementation would use a proper parser.
fn isValidJson(text: []const u8) bool {
    if (text.len == 0) return false;

    // Trim whitespace
    var start: usize = 0;
    var end: usize = text.len;

    while (start < end and isWhitespace(text[start])) : (start += 1) {}
    while (end > start and isWhitespace(text[end - 1])) : (end -= 1) {}

    if (start >= end) return false;

    const trimmed = text[start..end];

    // Check for valid JSON starting characters
    const first = trimmed[0];
    const last = trimmed[trimmed.len - 1];

    return switch (first) {
        '{' => last == '}', // Object
        '[' => last == ']', // Array
        '"' => last == '"', // String
        't' => std.mem.eql(u8, trimmed, "true"),
        'f' => std.mem.eql(u8, trimmed, "false"),
        'n' => std.mem.eql(u8, trimmed, "null"),
        '0'...'9', '-' => isValidJsonNumber(trimmed),
        else => false,
    };
}

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

fn isValidJsonNumber(text: []const u8) bool {
    if (text.len == 0) return false;

    var i: usize = 0;

    // Optional negative sign
    if (text[i] == '-') {
        i += 1;
        if (i >= text.len) return false;
    }

    // Integer part
    if (text[i] == '0') {
        i += 1;
    } else if (text[i] >= '1' and text[i] <= '9') {
        while (i < text.len and text[i] >= '0' and text[i] <= '9') : (i += 1) {}
    } else {
        return false;
    }

    // Fractional part
    if (i < text.len and text[i] == '.') {
        i += 1;
        if (i >= text.len or text[i] < '0' or text[i] > '9') return false;
        while (i < text.len and text[i] >= '0' and text[i] <= '9') : (i += 1) {}
    }

    // Exponent part
    if (i < text.len and (text[i] == 'e' or text[i] == 'E')) {
        i += 1;
        if (i >= text.len) return false;
        if (text[i] == '+' or text[i] == '-') i += 1;
        if (i >= text.len or text[i] < '0' or text[i] > '9') return false;
        while (i < text.len and text[i] >= '0' and text[i] <= '9') : (i += 1) {}
    }

    return i == text.len;
}

/// Get responseText
///
/// Spec: https://xhr.spec.whatwg.org/#the-responsetext-attribute
/// Legacy property - throws if responseType is not "" or "text"
pub fn getResponseText(state: *const XMLHttpRequestState) ![]const u8 {
    // Step 1: If responseType is not "" or "text", throw InvalidStateError
    if (state.response_type != .empty and state.response_type != .text) {
        return error.InvalidStateError;
    }

    // Step 2: If state is not LOADING or DONE, return empty string
    if (state.ready_state != .LOADING and state.ready_state != .DONE) {
        return "";
    }

    // Step 3: Return the text response
    return state.received_bytes.items;
}

/// Get responseXML
///
/// Spec: https://xhr.spec.whatwg.org/#the-responsexml-attribute
/// Stubbed - requires HTML/XML parser implementation
///
/// TODO: Implement when HTML/XML parsers are available
pub fn getResponseXML(state: *const XMLHttpRequestState) !?*anyopaque {
    // Step 1: If responseType is not "" or "document", throw InvalidStateError
    if (state.response_type != .empty and state.response_type != .document) {
        return error.InvalidStateError;
    }

    // Step 2: If state is not DONE, return null
    if (state.ready_state != .DONE) {
        return null;
    }

    // TODO: Parse and return Document when HTML/XML parser is available
    // For now, return null (stubbed)
    return null;
}

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

// =============================================================================
// Response Type Tests
// =============================================================================

test "getResponse - text response when DONE" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;
    try state.received_bytes.appendSlice(allocator, "Hello World");

    const response = try getResponse(&state);
    try std.testing.expectEqualStrings("Hello World", response.text);
}

test "getResponse - empty text for UNSENT state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.response_type = .text;

    const response = try getResponse(&state);
    try std.testing.expectEqualStrings("", response.text);
}

test "getResponse - arraybuffer response" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;
    try state.received_bytes.appendSlice(allocator, &[_]u8{ 0x01, 0x02, 0x03, 0x04 });

    var response = try getResponse(&state);
    defer response.deinit(allocator);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x01, 0x02, 0x03, 0x04 }, response.arraybuffer);
}

test "getResponse - blob response" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .blob;
    try state.received_bytes.appendSlice(allocator, "blob data");

    var response = try getResponse(&state);
    defer response.deinit(allocator);

    try std.testing.expectEqualStrings("blob data", response.blob.data);
    try std.testing.expectEqualStrings("application/octet-stream", response.blob.mime_type);
}

test "getResponse - json response valid" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .json;
    try state.received_bytes.appendSlice(allocator, "{\"key\":\"value\"}");

    var response = try getResponse(&state);
    defer response.deinit(allocator);

    try std.testing.expectEqualStrings("{\"key\":\"value\"}", response.json.?);
}

test "getResponse - json response invalid returns null" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .json;
    try state.received_bytes.appendSlice(allocator, "not valid json {");

    const response = try getResponse(&state);

    try std.testing.expect(response.json == null);
}

test "getResponse - empty when not DONE for non-text types" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .LOADING;
    state.response_type = .arraybuffer;

    const response = try getResponse(&state);

    try std.testing.expect(response == .empty);
}

test "getResponse - error when error flag set" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;
    state.error_flag = true;

    const response = try getResponse(&state);

    try std.testing.expect(response == .@"error");
}

test "getResponseText - returns text" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;
    try state.received_bytes.appendSlice(allocator, "Hello");

    const text = try getResponseText(&state);
    try std.testing.expectEqualStrings("Hello", text);
}

test "getResponseText - throws for arraybuffer type" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;

    const result = getResponseText(&state);
    try std.testing.expectError(error.InvalidStateError, result);
}

test "getResponseXML - returns null when stubbed" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .document;

    const xml = try getResponseXML(&state);
    try std.testing.expect(xml == null);
}

test "isValidJson - valid objects" {
    try std.testing.expect(isValidJson("{}"));
    try std.testing.expect(isValidJson("{\"key\": \"value\"}"));
}

test "isValidJson - valid arrays" {
    try std.testing.expect(isValidJson("[]"));
    try std.testing.expect(isValidJson("[1, 2, 3]"));
}

test "isValidJson - valid primitives" {
    try std.testing.expect(isValidJson("true"));
    try std.testing.expect(isValidJson("false"));
    try std.testing.expect(isValidJson("null"));
    try std.testing.expect(isValidJson("\"string\""));
}

test "isValidJson - valid numbers" {
    try std.testing.expect(isValidJson("0"));
    try std.testing.expect(isValidJson("42"));
    try std.testing.expect(isValidJson("-42"));
    try std.testing.expect(isValidJson("3.14"));
    try std.testing.expect(isValidJson("-3.14"));
    try std.testing.expect(isValidJson("1e10"));
    try std.testing.expect(isValidJson("1E+10"));
    try std.testing.expect(isValidJson("1e-10"));
}

test "isValidJson - invalid json" {
    try std.testing.expect(!isValidJson(""));
    try std.testing.expect(!isValidJson("{"));
    try std.testing.expect(!isValidJson("["));
    try std.testing.expect(!isValidJson("undefined"));
    try std.testing.expect(!isValidJson("NaN"));
}
