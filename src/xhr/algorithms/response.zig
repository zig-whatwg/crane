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
const fetch_mod = @import("fetch");
const mimesniff = @import("mimesniff");
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

// =============================================================================
// Response body MIME types (§3.6.6)
// =============================================================================

/// Fetch "extract a MIME type" from `headers`: the last `Content-Type` value
/// that parses (and is not */*), carrying an earlier same-essence value's
/// charset when it has none. Null is failure. OWNED: `deinit` it.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-extract-mime-type
pub fn extractMimeType(allocator: std.mem.Allocator, headers: *const fetch_mod.internal.HeaderList) !?mimesniff.MimeType {
    // 1-3. Let charset, essence and mimeType be null.
    var charset: ?[]u16 = null;
    defer if (charset) |c| allocator.free(c);
    var essence: ?[]const u16 = null;
    defer if (essence) |e| allocator.free(e);
    var mime_type: ?mimesniff.MimeType = null;
    errdefer if (mime_type) |*m| m.deinit();
    // 4. Let values be the result of getting, decoding, and splitting
    //    `Content-Type` from headers.
    // 5. If values is null, then return failure.
    const values = (try headers.getDecodeSplit(allocator, "Content-Type")) orelse return null;
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }
    // 6. For each value of values:
    for (values) |value| {
        // 1. Let temporaryMimeType be the result of parsing value.
        var temporary = (try mimesniff.parseMimeType(allocator, value)) orelse continue;
        // 2. If temporaryMimeType is failure or its essence is "*/*", then
        //    continue.
        const temporary_essence = temporary.essence(allocator) catch |err| {
            temporary.deinit();
            return err;
        };
        if (std.mem.eql(u16, temporary_essence, std.unicode.utf8ToUtf16LeStringLiteral("*/*"))) {
            allocator.free(temporary_essence);
            temporary.deinit();
            continue;
        }
        // 3. Set mimeType to temporaryMimeType.
        if (mime_type) |*m| m.deinit();
        mime_type = temporary;
        const current = &mime_type.?;
        // 4. If mimeType's essence is not essence, then:
        if (essence == null or !std.mem.eql(u16, essence.?, temporary_essence)) {
            // 1. Set charset to null.
            if (charset) |c| allocator.free(c);
            charset = null;
            // 2. If mimeType's parameters["charset"] exists, then set charset
            //    to it.
            if (parameterIndex(current.*, "charset")) |i| charset = try allocator.dupe(u16, current.parameters.entries.items()[i].value);
            // 3. Set essence to mimeType's essence.
            if (essence) |e| allocator.free(e);
            essence = temporary_essence;
        } else {
            allocator.free(temporary_essence);
            // 5. Otherwise, if mimeType's parameters["charset"] does not
            //    exist, and charset is non-null, set mimeType's
            //    parameters["charset"] to charset.
            if (parameterIndex(current.*, "charset") == null) if (charset) |c| {
                const key = try current.allocator.dupe(u16, std.unicode.utf8ToUtf16LeStringLiteral("charset"));
                errdefer current.allocator.free(key);
                const copy = try current.allocator.dupe(u16, c);
                errdefer current.allocator.free(copy);
                try current.parameters.set(key, copy);
            };
        }
    }
    // 7. If mimeType is null, then return failure.
    // 8. Return mimeType.
    return mime_type;
}

/// The index of `record`'s parameter `name` (ASCII), if it has it. (Its map
/// compares slice keys by address, so this compares the text.)
fn parameterIndex(record: mimesniff.MimeType, comptime name: []const u8) ?usize {
    const wide = std.unicode.utf8ToUtf16LeStringLiteral(name);
    for (record.parameters.entries.items(), 0..) |entry, i| {
        if (std.mem.eql(u16, entry.key, wide)) return i;
    }
    return null;
}

/// XHR "get a final MIME type" for `state`, serialized to bytes: this's
/// override MIME type, or else "get a response MIME type" - the response's
/// extracted MIME type, text/xml when that is failure. OWNED.
///
/// Spec: https://xhr.spec.whatwg.org/#final-mime-type
pub fn finalMimeTypeBytes(allocator: std.mem.Allocator, state: *const XMLHttpRequestState) ![]const u8 {
    // 1. If xhr's override MIME type is null, return the result of get a
    //    response MIME type for xhr.
    // 2. Return xhr's override MIME type.
    if (state.override_mime_type) |override| return mimesniff.serializeMimeTypeToBytes(allocator, override);
    // Get a response MIME type: 1. Let mimeType be the result of extracting
    // a MIME type from xhr's response's header list. 2. If mimeType is
    // failure, then set mimeType to text/xml. 3. Return mimeType.
    const response = state.response orelse return allocator.dupe(u8, "text/xml");
    var extracted = (try extractMimeType(allocator, &response.header_list)) orelse return allocator.dupe(u8, "text/xml");
    defer extracted.deinit();
    return mimesniff.serializeMimeTypeToBytes(allocator, extracted);
}

/// The label a text response decodes with - "get a text response" steps
/// 2-3 - for the caller to get an encoding from (steps 4-5: failure, or no
/// label, is UTF-8, and a BOM overrides it). OWNED; null for none.
///
/// Spec: https://xhr.spec.whatwg.org/#text-response
pub fn textResponseEncodingLabel(allocator: std.mem.Allocator, state: *const XMLHttpRequestState) !?[]u8 {
    // 2. Let charset be the result of get a final encoding for xhr.
    if (try finalEncodingLabel(allocator, state)) |label| return label;
    // 3. If xhr's response type is the empty string, charset is null, and
    //    the result of get a final MIME type for xhr is an XML MIME type,
    //    then use the rules set forth in the XML specifications to determine
    //    the encoding - its XML declaration's encoding.
    if (state.response_type != .empty) return null;
    const final_mime = try finalMimeTypeBytes(allocator, state);
    defer allocator.free(final_mime);
    if (!isXmlMimeType(final_mime)) return null;
    const declared = xmlDeclarationEncoding(state.received_bytes.items) orelse return null;
    return try allocator.dupe(u8, declared);
}

/// XHR "get a final encoding", up to its label (steps 1-5): the override MIME
/// type's charset if it has one, else the response MIME type's. OWNED; null
/// for none.
///
/// Spec: https://xhr.spec.whatwg.org/#final-charset
pub fn finalEncodingLabel(allocator: std.mem.Allocator, state: *const XMLHttpRequestState) !?[]u8 {
    // 4. If xhr's override MIME type's parameters["charset"] exists, then set
    //    label to it.
    if (state.override_mime_type) |override| {
        if (parameterIndex(override, "charset")) |i| return try isomorphicEncode(allocator, override.parameters.entries.items()[i].value);
    }
    // 2. Let responseMIME be the result of get a response MIME type for xhr.
    //    (text/xml, when extracting fails, has no charset.)
    // 3. If responseMIME's parameters["charset"] exists, then set label to it.
    const response = state.response orelse return null;
    var response_mime = (try extractMimeType(allocator, &response.header_list)) orelse return null;
    defer response_mime.deinit();
    const i = parameterIndex(response_mime, "charset") orelse return null;
    return try isomorphicEncode(allocator, response_mime.parameters.entries.items()[i].value);
}

/// A MIME type string's value, as the bytes it was isomorphic-decoded from.
fn isomorphicEncode(allocator: std.mem.Allocator, text: []const u16) ![]u8 {
    const bytes = try allocator.alloc(u8, text.len);
    for (text, bytes) |c, *b| b.* = @truncate(c);
    return bytes;
}

/// MIME Sniffing's XML MIME type, over a serialized MIME type: its essence
/// ends in "+xml", or is text/xml or application/xml.
fn isXmlMimeType(serialized: []const u8) bool {
    const essence = serialized[0 .. std.mem.indexOfScalar(u8, serialized, ';') orelse serialized.len];
    return std.mem.endsWith(u8, essence, "+xml") or std.mem.eql(u8, essence, "text/xml") or std.mem.eql(u8, essence, "application/xml");
}

/// The encoding an XML declaration at the start of `bytes` names (XML 1.0
/// 4.3.3: `<?xml ... encoding='name' ...?>`), or null.
fn xmlDeclarationEncoding(bytes: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, bytes, "<?xml")) return null;
    const end = std.mem.indexOf(u8, bytes, "?>") orelse return null;
    const declaration = bytes[0..end];
    const at = std.mem.indexOf(u8, declaration, "encoding") orelse return null;
    var i = at + "encoding".len;
    while (i < declaration.len and (declaration[i] == ' ' or declaration[i] == '\t' or declaration[i] == '\r' or declaration[i] == '\n')) i += 1;
    if (i >= declaration.len or declaration[i] != '=') return null;
    i += 1;
    while (i < declaration.len and (declaration[i] == ' ' or declaration[i] == '\t' or declaration[i] == '\r' or declaration[i] == '\n')) i += 1;
    if (i >= declaration.len or (declaration[i] != '"' and declaration[i] != '\'')) return null;
    const quote = declaration[i];
    const close = std.mem.indexOfScalarPos(u8, declaration, i + 1, quote) orelse return null;
    return declaration[i + 1 .. close];
}

test "an XML declaration's encoding" {
    try std.testing.expectEqualStrings("windows-1252", xmlDeclarationEncoding("<?xml version='1.0' encoding='windows-1252'?><x/>").?);
    try std.testing.expectEqualStrings("UTF-8", xmlDeclarationEncoding("<?xml version=\"1.0\" encoding = \"UTF-8\" ?>").?);
    try std.testing.expect(xmlDeclarationEncoding("<?xml version='1.0'?><x encoding='no'/>") == null);
    try std.testing.expect(xmlDeclarationEncoding("<x/>") == null);
}

fn labelFor(content_type: ?[]const u8, override: ?[]const u8, response_type: ResponseType, body: []const u8) !?[]u8 {
    const allocator = std.testing.allocator;
    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();
    const response = try fetch_mod.internal.InternalResponse.init(allocator);
    if (content_type) |t| try response.header_list.append("Content-Type", t);
    state.setResponse(response);
    if (override) |o| state.override_mime_type = (try mimesniff.parseMimeType(allocator, o)).?;
    state.response_type = response_type;
    try state.received_bytes.appendSlice(allocator, body);
    return textResponseEncodingLabel(allocator, &state);
}

fn expectLabel(expected: ?[]const u8, content_type: ?[]const u8, override: ?[]const u8, response_type: ResponseType, body: []const u8) !void {
    const label = try labelFor(content_type, override, response_type, body);
    defer if (label) |l| std.testing.allocator.free(l);
    if (expected) |e| try std.testing.expectEqualStrings(e, label orelse return error.NoLabel) else try std.testing.expect(label == null);
}

test "a text response's label: the override's charset, the response's, an XML declaration's, or none" {
    const xml = "<?xml version='1.0' encoding='windows-1252'?><x/>";
    try expectLabel("windows-1252", "text/plain;charset=windows-1252", null, .empty, "");
    try expectLabel(null, "text/plain", null, .empty, "");
    try expectLabel("shift_jis", "text/plain;charset=windows-1252", "text/plain;charset=shift_jis", .text, "");
    // The response's charset stands when the override has none.
    try expectLabel("windows-1252", "text/plain;charset=windows-1252", "text/plain", .text, "");
    // An XML response with no charset is sniffed - for responseType "" only.
    try expectLabel("windows-1252", "application/xml", null, .empty, xml);
    try expectLabel(null, "application/xml", null, .text, xml);
    try expectLabel(null, "text/html", null, .empty, xml);
    try expectLabel("utf-8", "application/xml;charset=utf-8", null, .empty, xml);
}

fn extractedFrom(values: []const []const u8) !?[]const u8 {
    const allocator = std.testing.allocator;
    var headers = fetch_mod.internal.HeaderList.init(allocator);
    defer headers.deinit();
    for (values) |v| try headers.append("Content-Type", v);
    var mime = (try extractMimeType(allocator, &headers)) orelse return null;
    defer mime.deinit();
    return try mimesniff.serializeMimeTypeToBytes(allocator, mime);
}

fn expectExtracted(expected: ?[]const u8, values: []const []const u8) !void {
    const actual = try extractedFrom(values);
    defer if (actual) |a| std.testing.allocator.free(a);
    if (expected) |e| try std.testing.expectEqualStrings(e, actual orelse return error.Failure) else try std.testing.expect(actual == null);
}

test "extract a MIME type: Fetch's examples" {
    // Headers as on the network -> the serialized result.
    try expectExtracted("text/html", &.{"text/plain;charset=gbk, text/html"});
    try expectExtracted("text/html;x=y;charset=gbk", &.{"text/html;charset=gbk;a=b, text/html;x=y"});
    try expectExtracted("text/html;x=y;charset=gbk", &.{ "text/html;charset=gbk;a=b", "text/html;x=y" });
    try expectExtracted("text/html;x=y", &.{ "text/html;charset=gbk", "x/x", "text/html;x=y" });
    try expectExtracted("text/html", &.{ "text/html", "cannot-parse" });
    try expectExtracted("text/html", &.{ "text/html", "*/*" });
    try expectExtracted("text/html", &.{ "text/html", "" });
    // No Content-Type, or none that parses: failure.
    try expectExtracted(null, &.{});
    try expectExtracted(null, &.{"*/*"});
    try expectExtracted(null, &.{"bogus"});
}

test "get a final MIME type: the override, else the response's, else text/xml" {
    const allocator = std.testing.allocator;
    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();
    const no_response = try finalMimeTypeBytes(allocator, &state);
    defer allocator.free(no_response);
    try std.testing.expectEqualStrings("text/xml", no_response);

    const response = try fetch_mod.internal.InternalResponse.init(allocator);
    try response.header_list.append("Content-Type", "Text/Plain;Charset=UTF-8");
    state.setResponse(response);
    const from_response = try finalMimeTypeBytes(allocator, &state);
    defer allocator.free(from_response);
    try std.testing.expectEqualStrings("text/plain;charset=UTF-8", from_response);

    state.override_mime_type = (try mimesniff.parseMimeType(allocator, "application/x-test")).?;
    const overridden = try finalMimeTypeBytes(allocator, &state);
    defer allocator.free(overridden);
    try std.testing.expectEqualStrings("application/x-test", overridden);
}
