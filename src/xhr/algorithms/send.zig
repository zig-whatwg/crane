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
/// event loop by the WebIDL impl - has its outcome. The impl calls this from a
/// task, with the body `sendPrologue` returned. The timeout is the impl's: it
/// ends a fetch still running at the deadline, so an outcome here was in time.
pub fn sendAsyncFinish(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
    result: fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult,
) !void {
    var processor = ResponseProcessor.init(state);
    // As `sendAsync` does: the upload's accounting, when there is an upload
    // to report. Neither flag changes while the request is in flight - an
    // `abort()` or `open()` ends the fetch, and this never runs.
    var upload_tracker: ?UploadTracker = null;
    if (!state.upload_complete_flag and state.upload_listener_flag) {
        upload_tracker = UploadTracker.init(if (body) |b| b.len else 0, state.event_sink);
    }
    try FetchIntegration.processFetchResult(
        state,
        body,
        result,
        null,
        &processor,
        if (upload_tracker) |*ut| ut else null,
    );
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
        upload_tracker = UploadTracker.init(request_body_length, state.event_sink);
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
