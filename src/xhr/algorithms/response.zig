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

    /// `processResponse`, given a response.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#the-send()-method step 11.9
    ///
    /// Returns whether the caller should go on to read the body. The earlier
    /// version of this went straight from *headers received* to *loading* and
    /// fired readystatechange twice before a single byte had arrived. The spec
    /// moves to *loading* from the FIRST BODY CHUNK (step 11.9.10.3), and
    /// `xhr/xmlhttprequest-*-order` counts those events.
    pub fn processResponse(self: *ResponseProcessor) bool {
        // Step 1 ("set this's response to response") and step 2 ("handle
        // errors") are the caller's - it is the one holding the response.

        // Step 3: If this's response is a network error, then return.
        if (self.state.isNetworkError()) return false;

        // Step 4: Set this's state to headers received.
        self.state.changeState(.HEADERS_RECEIVED);

        // Step 5: Fire an event named readystatechange at this.
        event_support.fireEvent(self.state.event_sink, .readystatechange);

        // Step 6: If this's state is not headers received, then return. A
        // readystatechange listener can have called abort() or open().
        if (self.state.ready_state != .HEADERS_RECEIVED) return false;

        // Step 8-9: extract a length from the response's header list.
        if (self.contentLength()) |length| {
            self.progress_tracker.setContentLength(length);
        }

        // Step 7 is the caller's: a null body means end-of-body right away.
        return true;
    }

    /// `length`, from send() step 11.9.8: "the result of extracting a length
    /// from this's response's header list". Null when there is no usable
    /// Content-Length, which step 9 turns into 0 - but a 0 total is reported as
    /// `lengthComputable: false`, so keep the distinction here.
    fn contentLength(self: *const ResponseProcessor) ?usize {
        const response = self.state.response orelse return null;
        const raw = response.header_list.getFirstValue("content-length") orelse return null;
        const trimmed = std.mem.trim(u8, raw, " \t");
        return std.fmt.parseInt(usize, trimmed, 10) catch null;
    }

    /// `processBodyChunk`, given bytes.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#the-send()-method step 11.9.10
    pub fn processResponseBodyChunk(self: *ResponseProcessor, chunk: []const u8) !void {
        // Step 1: Append bytes to this's received bytes.
        try self.state.received_bytes.appendSlice(self.state.allocator, chunk);

        // Step 2: If not roughly 50ms have passed since these steps were last
        // invoked, then return.
        const should_fire = self.progress_tracker.onChunk(chunk.len);
        if (!should_fire) return;

        // Step 3: If this's state is headers received, set it to loading.
        if (self.state.ready_state == .HEADERS_RECEIVED) {
            self.state.changeState(.LOADING);
        }

        // Step 4: Fire an event named readystatechange at this.
        //
        // Spec note: "Web compatibility is the reason readystatechange fires
        // more often than this's state changes." It is fired on every
        // un-throttled chunk, not only on the transition.
        event_support.fireEvent(self.state.event_sink, .readystatechange);

        // Step 5: Fire a progress event named progress at this with this's
        // received bytes's length and length.
        const progress_info = self.progress_tracker.getProgress();
        event_support.fireProgressEvent(self.state.event_sink, .progress, .{
            .lengthComputable = progress_info.length_computable,
            .loaded = self.state.received_bytes.items.len,
            .total = progress_info.total orelse 0,
        });
    }

    /// Handle response end-of-body.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-response-end-of-body
    pub fn processResponseEndOfBody(self: *ResponseProcessor) void {
        // Steps 1-2: handle errors, and return if the response is a network
        // error. `handleNetworkError` is the caller's route for that, so
        // reaching here with one means only that there is nothing to report.
        if (self.state.isNetworkError()) return;

        // Step 3: Let transmitted be this's received bytes's length.
        const transmitted = self.state.received_bytes.items.len;

        // Steps 4-5: Let length be the extracted length, 0 if not an integer.
        const length = self.contentLength() orelse 0;
        const computable = length > 0;

        const progress = event_support.ProgressEventData{
            .lengthComputable = computable,
            .loaded = transmitted,
            .total = length,
        };

        // Step 6: If this's synchronous flag is unset, fire progress.
        //
        // A sync request fires NO progress event here - it fires only load and
        // loadend below. Firing it unconditionally, as this used to, gives a
        // sync XHR one event too many.
        if (!self.state.synchronous_flag) {
            event_support.fireProgressEvent(self.state.event_sink, .progress, progress);
        }

        // Step 7: Set this's state to done.
        self.state.changeState(.DONE);

        // Step 8: Unset this's send() flag.
        self.state.send_flag = false;

        // Step 9: Fire an event named readystatechange at this.
        event_support.fireEvent(self.state.event_sink, .readystatechange);

        // Step 10: Fire a progress event named load at this.
        event_support.fireProgressEvent(self.state.event_sink, .load, progress);

        // Step 11: Fire a progress event named loadend at this.
        event_support.fireProgressEvent(self.state.event_sink, .loadend, progress);
    }

    /// The request error steps.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#request-error-steps
    ///
    /// `event` is the event name for step 7 - `timeout`, `abort` or `error`.
    /// The spec fires it with 0 and 0, NOT with the bytes transferred so far,
    /// which is why the progress tracker is deliberately not consulted here.
    ///
    /// Steps 4 and 5 fork on the synchronous flag: a sync request throws the
    /// exception and fires NOTHING, so this returns after step 3 and leaves the
    /// throw to the caller (`send.sendSync`).
    pub fn requestErrorSteps(self: *ResponseProcessor, event: XHREventType) void {
        // Step 1: Set state to done.
        self.state.changeState(.DONE);

        // Step 2: Unset the send() flag.
        self.state.send_flag = false;

        // Step 3: Set response to a network error.
        self.state.setResponseToNetworkError();

        // Step 4: If the synchronous flag is set, throw exception. The throw is
        // the caller's; what matters here is that steps 5-8 do not run.
        if (self.state.synchronous_flag) return;

        // Step 5: Fire an event named readystatechange.
        event_support.fireEvent(self.state.event_sink, .readystatechange);

        // Step 6: If the upload complete flag is unset, then:
        if (!self.state.upload_complete_flag) {
            // Step 6.1
            self.state.upload_complete_flag = true;

            // Step 6.2: If the upload listener flag is set, then:
            if (self.state.upload_listener_flag) {
                const zero = ProgressEventData{ .lengthComputable = false, .loaded = 0, .total = 0 };
                // Step 6.2.1 and 6.2.2
                event_support.fireUploadProgressEvent(self.state.event_sink, event, zero);
                event_support.fireUploadProgressEvent(self.state.event_sink, .loadend, zero);
            }
        }

        const zero = ProgressEventData{ .lengthComputable = false, .loaded = 0, .total = 0 };

        // Step 7: Fire a progress event named event at xhr with 0 and 0.
        event_support.fireProgressEvent(self.state.event_sink, event, zero);

        // Step 8: Fire a progress event named loadend at xhr with 0 and 0.
        event_support.fireProgressEvent(self.state.event_sink, .loadend, zero);
    }

    /// Handle a network error.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-errors step 4 - run the
    /// request error steps for `error`.
    pub fn handleNetworkError(self: *ResponseProcessor) void {
        self.requestErrorSteps(.@"error");
    }

    /// Handle a timeout.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-errors step 2 - run the
    /// request error steps for `timeout`.
    pub fn handleTimeout(self: *ResponseProcessor) void {
        self.state.timed_out_flag = true;
        self.requestErrorSteps(.timeout);
    }

    /// Handle an abort.
    ///
    /// Spec: https://xhr.spec.whatwg.org/#handle-errors step 3 - run the
    /// request error steps for `abort`.
    pub fn handleAbort(self: *ResponseProcessor) void {
        self.requestErrorSteps(.abort);
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

    // Step 3: If this's response object is failure, then return null.
    //
    // There is no "error flag" in the XHR Standard - the earlier code read one
    // off the state and the field did not exist, which is the whole reason this
    // file never compiled. "response object is failure" is the actual spec
    // condition, set when an ArrayBuffer allocation throws (step 5).
    if (state.response_object == .failure) {
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

    // Text response step 1: if xhr's response's body is null, return the
    // empty string. A network error has a null body, so this subsumes the
    // "error flag" check the earlier code wanted - and unlike that check it
    // also covers 204/205/304, which legitimately have no body.
    if (state.isNetworkError()) {
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

/// Give `state` a 200 response whose body is `bytes`, and accumulate `bytes`
/// into received bytes - the pair the fetch path always produces together.
///
/// The text response algorithm's step 1 is "if xhr's response's body is null,
/// return the empty string", so a state that has received bytes but no response
/// is not a state the algorithms can reach, and a test that builds one is
/// testing nothing. This helper builds the reachable one.
fn installOkResponse(state: *XMLHttpRequestState, bytes: []const u8) !void {
    const fetch = @import("fetch");
    const response = try fetch.internal.InternalResponse.init(state.allocator);
    response.status = 200;
    response.body = try fetch.internal.Body.fromBytes(state.allocator, bytes);
    state.setResponse(response);
    try state.received_bytes.appendSlice(state.allocator, bytes);
}

test "ResponseProcessor - initialization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const processor = ResponseProcessor.init(&state);

    try std.testing.expectEqual(@as(usize, 0), processor.progress_tracker.total_bytes);
}

test "ResponseProcessor - process response transitions to HEADERS_RECEIVED, not LOADING" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    try installOkResponse(&state, "");

    var processor = ResponseProcessor.init(&state);
    try std.testing.expect(processor.processResponse());

    // Step 4 stops at *headers received*. The old assertion expected LOADING,
    // matching an implementation that jumped both transitions at once and fired
    // readystatechange twice before a byte had arrived; the spec moves to
    // *loading* from the first body chunk (send() step 11.9.10.3).
    try std.testing.expectEqual(ReadyState.HEADERS_RECEIVED, state.ready_state);
}

test "ResponseProcessor - the first chunk is what moves to LOADING" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    try installOkResponse(&state, "");

    var processor = ResponseProcessor.init(&state);
    try std.testing.expect(processor.processResponse());
    try processor.processResponseBodyChunk("body");

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
    // Handle response end-of-body step 2 returns when the response is a network
    // error, and the response is INITIALLY a network error - so this needs a
    // real one to reach step 7.
    try installOkResponse(&state, "body");

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

    try std.testing.expect(state.isNetworkError());
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
    try installOkResponse(&state, "Hello World");

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
    state.response_object = .failure;

    const response = try getResponse(&state);

    try std.testing.expect(response == .@"error");
}

test "getResponseText - returns text" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;
    try installOkResponse(&state, "Hello");

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
