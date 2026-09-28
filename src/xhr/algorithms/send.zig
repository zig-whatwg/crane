//! XMLHttpRequest send() Algorithm
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#the-send()-method
//!
//! ## Sync and async share their steps, not their wait
//!
//! A synchronous request waits for its response inside `send()`
//! (`sendDispatch`, through `fetch_integration.fetch`), which is what sync
//! means. An asynchronous one fetches in parallel: the WebIDL impl
//! (`src/webidl/impls/XMLHttpRequest.zig`) builds the request with
//! `fetch_integration.createRequest`, runs it on the event loop, and hands the
//! outcome to `sendAsyncFinish` from a task - so `send()` returns before any
//! of the response's events fire, the loop keeps turning while the response
//! is on its way, and a timeout or `abort()` can end a request that has not
//! been answered. Both paths run the same `processFetchResult`, so the
//! readyState/event sequence is identical either way - which is what the WPT
//! event-order tests check.
//!
//! The remaining deviation is that `progress` fires once rather than per
//! 50ms window, because the body arrives in one piece. Event ORDER and the
//! final `loaded`/`total` are spec-correct; the number of intermediate
//! `progress` events is not, and needs the response body streamed.

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
const fetch_mod = @import("fetch");

/// send() step 6: req, for the WebIDL impl to fetch on the event loop.
pub const createRequest = FetchIntegration.createRequest;

/// Errors `send()` can report to script.
pub const SendError = error{
    /// Spec steps 1-2: state is not opened, or the send() flag is set.
    InvalidStateError,
    /// A synchronous request whose response is a network error.
    NetworkError,
    /// A synchronous request that timed out.
    TimeoutError,
    OutOfMemory,
};

/// Is this a method for which send() discards the body?
///
/// Spec: step 3 - "If this's request method is GET or HEAD, set body to null."
fn methodIgnoresBody(method: ?[]const u8) bool {
    const m = method orelse return false;
    return std.mem.eql(u8, m, "GET") or std.mem.eql(u8, m, "HEAD");
}

/// Send request
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
///
/// Steps 1-10 then 11/12 in one call. The WebIDL impl splits them - see
/// `sendPrologue` - because steps 1-10 must be observable to script the moment
/// `send()` returns while the transfer itself is deferred to a task.
pub fn send(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    const effective_body = try sendPrologue(state, body);
    if (!state.synchronous_flag and !sendStart(state, effective_body)) return;
    try sendDispatch(state, effective_body);
}

/// Steps 1-10 of send(): validate, normalise the body, and set the flags.
///
/// Returns the body the request will actually carry - null when step 3 has
/// discarded it. Everything this does is SYNCHRONOUSLY OBSERVABLE: after it
/// returns, `xhr.send()` a second time throws, because step 10 has set the
/// send() flag. That is why it is separable from step 11.
pub fn sendPrologue(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !?[]const u8 {
    // Step 1: If this's state is not opened, throw an "InvalidStateError".
    if (state.ready_state != .OPENED) {
        return error.InvalidStateError;
    }

    // Step 2: If this's send() flag is set, throw an "InvalidStateError".
    if (state.send_flag) {
        return error.InvalidStateError;
    }

    // Step 3: If this's request method is GET or HEAD, set body to null.
    //
    // This is not a nicety: `xhr.open("GET", url); xhr.send("ignored")` must
    // send no body at all, and `xhr/send-entity-body-get-head.htm` checks it.
    var request_body = body;
    if (methodIgnoresBody(state.request_method)) {
        request_body = null;
    }

    // Step 4: If body is non-null, extract it. The impl has already turned the
    // JS value into bytes; the Content-Type default it implies is applied in
    // `fetch_integration.createRequest`.

    // Step 5: The upload listener flag is set by the impl, which is the only
    // thing that can see whether the upload object has listeners.

    // Step 6: Let req be a new request. Built in `fetch_integration`.

    // Step 7: Unset this's upload complete flag.
    state.upload_complete_flag = false;

    // Step 8: Unset this's timed out flag.
    state.timed_out_flag = false;

    // Step 9: If req's body is null, then set this's upload complete flag.
    if (request_body == null or request_body.?.len == 0) {
        state.upload_complete_flag = true;
    }

    // Step 10: Set this's send() flag.
    state.send_flag = true;

    return request_body;
}

/// What send()'s body was, as step 4's Content-Type rules tell bodies
/// apart. (A Document joins USVString in 4.5 and has 4.6's own types, once
/// send() takes one.)
pub const BodyKind = enum { usvstring, other };

/// Steps 4.4-4.6 of send(): the Content-Type for a request body of `kind`,
/// whose bodyWithType's type is `extracted_type`, in this's author request
/// headers.
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
pub fn setRequestContentType(allocator: Allocator, state: *XMLHttpRequestState, kind: BodyKind, extracted_type: ?[]const u8) !void {
    const headers = &state.author_request_headers;
    // 4.4. Let originalAuthorContentType be the result of getting
    //      `Content-Type` from this's author request headers.
    const original = try headers.get(allocator, "Content-Type");
    defer if (original) |o| allocator.free(o);
    // 4.5. If originalAuthorContentType is non-null, then:
    if (original) |author_type| {
        // 4.5.1. If body is a Document or a USVString, then:
        if (kind != .usvstring) return;
        // 1. Let contentTypeRecord be the result of parsing
        //    originalAuthorContentType.
        const mimesniff = @import("mimesniff");
        var record = (try mimesniff.parseMimeType(allocator, author_type)) orelse return;
        defer record.deinit();
        // 2. If contentTypeRecord is not failure, its parameters["charset"]
        //    exists, and it is not an ASCII case-insensitive match for
        //    "UTF-8", then:
        const index = charsetParameter(record) orelse return;
        const entry = record.parameters.entries.items()[index];
        if (isUtf8Label(entry.value)) return;
        // 1. Set contentTypeRecord's parameters["charset"] to "UTF-8" (the
        //    record owns its parameter strings).
        const utf8 = try record.allocator.dupe(u16, std.unicode.utf8ToUtf16LeStringLiteral("UTF-8"));
        const old = record.parameters.entries.replace(index, .{ .key = entry.key, .value = utf8 }) catch unreachable;
        record.allocator.free(old.value);
        // 2. Let newContentTypeSerialized be the result of serializing
        //    contentTypeRecord.
        const serialized = try mimesniff.serializeMimeTypeToBytes(allocator, record);
        defer allocator.free(serialized);
        // 3. Set (`Content-Type`, newContentTypeSerialized) in this's author
        //    request headers.
        try headers.set("Content-Type", serialized);
        return;
    }
    // 4.6.3. Otherwise, if extractedContentType is not null, set
    //        (`Content-Type`, extractedContentType).
    if (extracted_type) |content_type| try headers.set("Content-Type", content_type);
}

/// The index of `record`'s "charset" parameter, if it has one. (Its map
/// compares slice keys by address, so this compares the text.)
fn charsetParameter(record: anytype) ?usize {
    const name = std.unicode.utf8ToUtf16LeStringLiteral("charset");
    for (record.parameters.entries.items(), 0..) |entry, i| {
        if (std.mem.eql(u16, entry.key, name)) return i;
    }
    return null;
}

/// An ASCII case-insensitive match for "UTF-8".
fn isUtf8Label(text: []const u16) bool {
    const utf8 = "UTF-8";
    if (text.len != utf8.len) return false;
    for (text, utf8) |c, a| {
        if (c > 0x7F or std.ascii.toLower(@intCast(c)) != std.ascii.toLower(a)) return false;
    }
    return true;
}

/// The upload's progress accounting for a request whose upload `loadstart`
/// send() step 11.5 has already fired (`sendStart`): marked started, so the
/// first chunk does not fire it a second time - one `loadstart` at the
/// upload object, however many requests a redirect makes.
fn startedUploadTracker(body_length: usize, sink: ?event_support.EventSink) UploadTracker {
    var tracker = UploadTracker.init(body_length, sink);
    tracker.started = true;
    return tracker;
}

/// Steps 11.1-11.6 of send(): fire loadstart.
///
/// SYNCHRONOUS, and that is the point. `loadstart` is a step of `send()`, not
/// of the fetch, so it fires before `send()` returns. Deferring it with the
/// rest of step 11 put it AFTER anything the caller did next:
///
///     xhr.send();
///     xhr.abort();     // fires readystatechange(4), abort, loadend
///
/// emitted `readystatechange(4)` first and `loadstart` never, which is what
/// `xhr/abort-after-send.any.js` reported as
/// `expected "loadstart(0,0,false)" but got "readystatechange(4)"`.
///
/// Returns false when step 11.6 says to stop - a `loadstart` listener called
/// `abort()` or `open()` - in which case the fetch must not run.
pub fn sendStart(state: *XMLHttpRequestState, body: ?[]const u8) bool {
    // Step 11.3: requestBodyLength is req's body's length, or 0.
    const request_body_length: u64 = if (body) |b| b.len else 0;

    // Step 11.1: Fire a progress event named loadstart at this with 0 and 0.
    event_support.fireProgressEvent(state.event_sink, .loadstart, .{
        .lengthComputable = false,
        .loaded = 0,
        .total = 0,
    });

    // Step 11.5: If this's upload complete flag is unset and this's upload
    // listener flag is set, fire loadstart at this's upload object with
    // requestBodyTransmitted (0) and requestBodyLength.
    if (!state.upload_complete_flag and state.upload_listener_flag) {
        event_support.fireUploadProgressEvent(state.event_sink, .loadstart, .{
            .lengthComputable = true,
            .loaded = 0,
            .total = request_body_length,
        });
    }

    // Step 11.6: If this's state is not opened or this's send() flag is unset,
    // then return.
    return state.ready_state == .OPENED and state.send_flag;
}

/// Steps 11.7-11.10 (async) or step 12 (sync) of send(): run the fetch,
/// waiting for it.
///
/// For an async request the caller has already run `sendStart`. The impl
/// waits like this only for a synchronous request, or an asynchronous one in
/// a realm with no event loop; otherwise it runs the fetch on the loop and
/// finishes with `sendAsyncFinish`.
pub fn sendDispatch(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    if (!state.synchronous_flag) {
        try sendAsync(state, body);
    } else {
        try sendSync(state, body);
    }
}

/// Steps 11.7-11.10 of an asynchronous send(), once req's fetch - run on the
/// event loop by the WebIDL impl - has its response. The impl calls this
/// from a task, with the body `sendPrologue` returned and a processor it
/// keeps for the body's pieces. The timeout is the impl's: it ends a fetch
/// still running at the deadline, so an outcome here was in time.
///
/// The response is handed on at its headers, so its body is usually still
/// arriving: that pipe comes back, to read with `sendAsyncBodyChunk` as
/// pieces arrive and `sendAsyncEndOfBody` or `sendAsyncBodyFailed` at its
/// end. Null: there is nothing left to read.
pub fn sendAsyncFinish(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
    result: fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult,
    processor: *ResponseProcessor,
) !?*fetch_mod.internal.BodyPipe {
    // As `sendAsync` does: the upload's accounting, when there is an upload
    // to report. Neither flag changes while the request is in flight - an
    // `abort()` or `open()` ends the fetch, and this never runs.
    var upload_tracker: ?UploadTracker = null;
    if (!state.upload_complete_flag and state.upload_listener_flag) {
        upload_tracker = startedUploadTracker(if (body) |b| b.len else 0, state.event_sink);
    }
    return FetchIntegration.processFetchResult(
        state,
        body,
        result,
        null,
        processor,
        if (upload_tracker) |*ut| ut else null,
    );
}

/// Step 11.9.13's processBodyChunk: another piece of the body.
pub fn sendAsyncBodyChunk(state: *XMLHttpRequestState, processor: *ResponseProcessor, bytes: []const u8) !void {
    _ = state;
    try processor.processResponseBodyChunk(bytes);
}

/// Step 11.9.11's processEndOfBody: "handle response end-of-body".
pub fn sendAsyncEndOfBody(state: *XMLHttpRequestState, processor: *ResponseProcessor) void {
    _ = state;
    processor.processResponseEndOfBody();
}

/// Step 11.9.12's processBodyError: the body failed while arriving -
/// "set this's response to a network error", then "run handle errors",
/// which finds the network error and runs the request error steps.
pub fn sendAsyncBodyFailed(state: *XMLHttpRequestState, processor: *ResponseProcessor) void {
    state.setResponseToNetworkError();
    processor.handleNetworkError();
}

/// Send request asynchronously, waiting for the response - for a realm with
/// no event loop to run the fetch on.
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method steps 11.7-11.10
fn sendAsync(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    var processor = ResponseProcessor.init(state);

    const request_body_length: usize = if (body) |b| b.len else 0;

    // The tracker carries the upload's progress accounting. It exists only when
    // there is an upload to report, which is the same condition step 11.5 used
    // to decide whether to fire `loadstart` at the upload object.
    var upload_tracker: ?UploadTracker = null;
    if (!state.upload_complete_flag and state.upload_listener_flag) {
        upload_tracker = startedUploadTracker(request_body_length, state.event_sink);
    }

    // Steps 11.7-11.10: run the fetch, feeding the processor.
    //
    // `&upload_tracker` is a `*?UploadTracker`; the callee wants an optional
    // POINTER. Writing the former where the latter is expected is what
    // `expected type '?*T', found '*?T'` was reporting - and it type-checks
    // nowhere, so the whole tree had never been compiled.
    try FetchIntegration.fetch(
        state,
        body,
        &processor,
        if (upload_tracker) |*ut| ut else null,
    );
}

/// Send request synchronously
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method step 12
///
/// A sync request fires no progress events and reports failure by THROWING,
/// which is why `requestErrorSteps` returns after step 3 when the synchronous
/// flag is set. The throw is here.
fn sendSync(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    var processor = ResponseProcessor.init(state);

    // Step 12: no upload events at all for a sync request, so no tracker.
    try FetchIntegration.fetch(state, body, &processor, null);

    // Step 12.4: If this's timed out flag is set, throw a "TimeoutError".
    if (state.timed_out_flag) {
        return error.TimeoutError;
    }

    // Step 12.5: If this's response is a network error, throw a "NetworkError".
    if (state.isNetworkError()) {
        return error.NetworkError;
    }
}

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

test "send() - a second send() while the flag is set is an InvalidStateError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .OPENED;
    state.send_flag = true;

    try std.testing.expectError(error.InvalidStateError, send(&state, null));
}

test "send() - GET discards the body, per step 3" {
    try std.testing.expect(methodIgnoresBody("GET"));
    try std.testing.expect(methodIgnoresBody("HEAD"));
    try std.testing.expect(!methodIgnoresBody("POST"));
    try std.testing.expect(!methodIgnoresBody("PUT"));
    try std.testing.expect(!methodIgnoresBody(null));

    // The comparison is against the ALREADY-NORMALISED method, which open()
    // upper-cases, so a lowercase spelling never reaches here.
    try std.testing.expect(!methodIgnoresBody("get"));
}

fn contentTypeAfter(author: ?[]const u8, kind: BodyKind, extracted: ?[]const u8) !?[]const u8 {
    const allocator = std.testing.allocator;
    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();
    if (author) |a| try state.author_request_headers.append("Content-Type", a);
    try setRequestContentType(allocator, &state, kind, extracted);
    const value = try state.author_request_headers.get(allocator, "Content-Type") orelse return null;
    return value;
}

fn expectContentType(expected: ?[]const u8, author: ?[]const u8, kind: BodyKind, extracted: ?[]const u8) !void {
    const actual = try contentTypeAfter(author, kind, extracted);
    defer if (actual) |a| std.testing.allocator.free(a);
    if (expected) |e| try std.testing.expectEqualStrings(e, actual orelse return error.NoContentType) else try std.testing.expect(actual == null);
}

test "send() step 4.6: with no author Content-Type, the extracted type is set" {
    try expectContentType("text/plain;charset=UTF-8", null, .usvstring, "text/plain;charset=UTF-8");
    try expectContentType("application/x-www-form-urlencoded;charset=UTF-8", null, .other, "application/x-www-form-urlencoded;charset=UTF-8");
    // A body with no type (a BufferSource) sets none.
    try expectContentType(null, null, .other, null);
}

test "send() step 4.5: a USVString body's author charset becomes UTF-8, and nothing else changes" {
    try expectContentType("text/plain;charset=UTF-8", "text/plain;charset=shift-jis", .usvstring, "text/plain;charset=UTF-8");
    try expectContentType("text/x-thepiano;charset=UTF-8", "text/x-thepiano;charset= waddup", .usvstring, "text/plain;charset=UTF-8");
    // A UTF-8 label in any case is left as the author wrote it.
    try expectContentType("text/plain;charset=utf-8", "text/plain;charset=utf-8", .usvstring, "text/plain;charset=UTF-8");
    // No charset, or no parse: left alone.
    try expectContentType("text/plain", "text/plain", .usvstring, "text/plain;charset=UTF-8");
    try expectContentType("charset=bogus", "charset=bogus", .usvstring, "text/plain;charset=UTF-8");
    // Not a USVString: the author's type stands whatever its charset.
    try expectContentType("text/plain;charset=shift-jis", "text/plain;charset=shift-jis", .other, "application/octet-stream");
}

test "the upload tracker send() makes has fired loadstart already" {
    const tracker = startedUploadTracker(12000, null);
    try std.testing.expect(tracker.started);
}
