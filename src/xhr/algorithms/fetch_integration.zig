//! XHR Fetch Integration
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/#the-send()-method step 6
//! WHATWG Fetch Spec: https://fetch.spec.whatwg.org/
//!
//! Builds the `req` of send() step 6 out of the XHR state, runs the real fetch
//! algorithm, and drives the `processResponse` / `processBodyChunk` /
//! `processEndOfBody` sequence from the result.
//!
//! ## What this replaced
//!
//! `simulateFetch`: a mock that appended the string "Mock response from Fetch
//! integration (fetch_integration.zig)" to received bytes and never touched the
//! network. Nothing called it either - `XMLHttpRequest.call_send` set the send
//! flag and returned, so the whole `algorithms/` tree was unreachable.
//!
//! ## Blocking, deliberately
//!
//! `fetch.algorithms.fetch` runs the exchange to completion and hands back a
//! finished response - the same call `src/html/navigation/fetch_integration.zig`
//! makes. There is no incremental read, so the body arrives as ONE chunk. That
//! gets event order and the final counts right and the number of intermediate
//! `progress` events wrong; see the header of `send.zig`.
//!
//! The caller decides when to block: directly for a sync request, from an
//! event-loop task for an async one.

const std = @import("std");
const Allocator = std.mem.Allocator;
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ResponseProcessor = @import("response.zig").ResponseProcessor;
const UploadTracker = @import("upload.zig").UploadTracker;
const clock = @import("clock");

// Fetch infrastructure - use module import to avoid cross-module file conflicts
const fetch_mod = @import("fetch");
const InternalRequest = fetch_mod.internal.InternalRequest;
const InternalResponse = fetch_mod.internal.InternalResponse;

const log = std.log.scoped(.xhr_fetch);

/// Run the fetch for this XHR and drive the response processor.
///
/// Spec: send() steps 6 through 11.10 (async) / 12 (sync).
pub fn fetch(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
    processor: *ResponseProcessor,
    upload_tracker: ?*UploadTracker,
) !void {
    const allocator = state.allocator;

    // Step 6: Let req be a new request, initialized from this's state.
    const request = try createRequest(allocator, state, body);
    defer request.deinit();

    var elapsed_timer = clock.Timer.start();

    // Steps 11.7-11.8: processRequestBodyChunkLength and
    // processRequestEndOfBody. The transfer is not observable from here, so
    // the whole body counts as transmitted the moment the fetch returns.
    // Firing these BEFORE the fetch would be a lie about ordering, so they run
    // below, once the request has actually gone out.

    var result = fetch_mod.algorithms.fetch(allocator, request, .{}) catch |err| {
        // The fetch algorithm reports transport failure IN-BAND, as a response
        // whose type is "error" - an error return here means it could not even
        // get that far.
        log.warn("fetch failed for {s}: {s}", .{ request.currentUrl(), @errorName(err) });
        if (err == error.AbortError) {
            processor.handleAbort();
        } else {
            processor.handleNetworkError();
        }
        return;
    };
    // The response outlives this function - the XHR state takes it. Only the
    // timing info is ours to free, so do NOT call `result.deinit()`, which
    // would free both.
    result.timing_info.deinit();
    const response = result.response;

    // Step 12.4 / step 11.12.2: the timed out flag.
    //
    // KNOWN GAP: there is no way to hand a deadline to the fetch algorithm -
    // `InternalRequest` has no timeout field, and the curl backend's
    // `timeout_ms` is not reachable from here. So the transfer is NOT cancelled
    // at the deadline; the flag is applied after the fact, from the elapsed
    // time. A request that overruns its timeout therefore reports `timeout`
    // late rather than on time.
    if (state.timeout > 0) {
        const elapsed_ms = elapsed_timer.read() / std.time.ns_per_ms;
        if (elapsed_ms >= state.timeout) {
            response.deinit();
            state.timed_out_flag = true;
            processor.handleTimeout();
            return;
        }
    }

    // Step 11.9.1: Set this's response to response. The state owns it now.
    state.setResponse(response);

    // Steps 11.7-11.8: the request body is fully transmitted by now.
    if (upload_tracker) |tracker| {
        if (body) |b| _ = tracker.onChunk(b.len);
        // processRequestEndOfBody step 1: set the upload complete flag.
        state.upload_complete_flag = true;
        // Steps 2-5: progress, load and loadend at the upload object - but only
        // while the upload listener flag is set, which is what `fireComplete`
        // checks by having been given a sink at all.
        if (state.upload_listener_flag) tracker.fireComplete();
    } else {
        state.upload_complete_flag = true;
    }

    // Step 11.9.2: Handle errors for this. A network error comes back as a
    // successful return carrying an error-typed response, so this predicate -
    // not the `catch` above - is what catches DNS failures, refused
    // connections and TLS errors.
    if (state.isNetworkError()) {
        processor.handleNetworkError();
        return;
    }

    // Step 12, a synchronous request: processResponseConsumeBody appends the
    // whole body to the received bytes, and "handle response end-of-body" is
    // the only step that fires anything - readystatechange at done, load and
    // loadend (its step 6 skips progress for a sync request). The
    // headers-received and loading transitions, with their readystatechange
    // and progress events, belong to the asynchronous path alone; running a
    // sync request through them fired two readystatechange events and a
    // progress event that no browser fires.
    if (state.synchronous_flag) {
        if (response.body) |response_body| {
            const bytes = response_body.getBytes();
            if (bytes.len > 0) try state.received_bytes.appendSlice(state.allocator, bytes);
        }
        processor.processResponseEndOfBody();
        return;
    }

    // Steps 11.9.3-11.9.9: move to headers received and read the length.
    if (!processor.processResponse()) return;

    // Re-read the response rather than unwrapping the one from before
    // `processResponse`: that call fires `readystatechange`, and a listener is
    // free to call `abort()` or `open()`, either of which sets the response to
    // a network error - which here means NULL. `processResponse` returning true
    // already rules that out via the state check, so this is belt and braces
    // against a `.?` that would panic rather than fail a subtest.
    const response_now = state.response orelse return;

    // Step 11.9.7: If this's response's body is null, run handle response
    // end-of-body and return. A 204/304 legitimately has no body.
    const response_body = response_now.body orelse {
        processor.processResponseEndOfBody();
        return;
    };

    // Step 11.9.13: incrementally read the body. One chunk, see the header.
    const bytes = response_body.getBytes();
    if (bytes.len > 0) {
        try processor.processResponseBodyChunk(bytes);
    }

    // Step 11.9.11: processEndOfBody.
    processor.processResponseEndOfBody();
}

/// Build `req` from the XHR state.
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method step 6
fn createRequest(
    allocator: Allocator,
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !*InternalRequest {
    // URL: this's request URL. `InternalRequest.init` takes it - the earlier
    // code called a one-argument `init` that does not exist and then `addUrl`,
    // which would have left url_list[0] empty.
    const url = state.request_url orelse return error.InvalidStateError;
    const request = try InternalRequest.init(allocator, url);
    errdefer request.deinit();

    // method: this's request method.
    if (state.request_method) |method| {
        try request.setMethod(method);
    }

    // header list: this's author request headers.
    for (state.author_request_headers.iterator()) |header| {
        try request.header_list.append(header.name, header.value);
    }

    // unsafe-request flag: set.
    request.unsafe_request = true;

    // body: this's request body. Borrowed - `InternalRequest.deinit` frees only
    // the `.body` arm of the union, never `.bytes`.
    if (body) |b| {
        if (b.len > 0) request.body = .{ .bytes = b };
    }

    // mode: "cors".
    request.mode = .cors;

    // use-CORS-preflight flag: set if this's upload listener flag is set.
    request.use_cors_preflight = state.upload_listener_flag;

    // credentials mode: "include" if this's cross-origin credentials is true,
    // otherwise "same-origin".
    request.credentials_mode = if (state.cross_origin_credentials) .include else .same_origin;

    // initiator type: "xmlhttprequest".
    request.initiator_type = .xmlhttprequest;

    return request;
}

// =============================================================================
// Tests
// =============================================================================

test "createRequest - mirrors send() step 6" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.request_method = try allocator.dupe(u8, "POST");
    state.request_url = try allocator.dupe(u8, "http://example.com/api");
    try state.author_request_headers.append("X-Test", "1");
    state.cross_origin_credentials = true;
    state.upload_listener_flag = true;

    const request = try createRequest(allocator, &state, "payload");
    defer request.deinit();

    try std.testing.expectEqualStrings("POST", request.method);
    try std.testing.expectEqualStrings("http://example.com/api", request.getUrl());
    try std.testing.expect(request.unsafe_request);
    try std.testing.expectEqual(fetch_mod.internal.RequestMode.cors, request.mode);
    try std.testing.expect(request.use_cors_preflight);
    try std.testing.expectEqual(fetch_mod.internal.CredentialsMode.include, request.credentials_mode);
    try std.testing.expectEqualStrings("payload", request.body.?.bytes);
    try std.testing.expectEqualStrings("1", request.header_list.getFirstValue("x-test").?);
}

test "createRequest - same-origin credentials by default, and no body arm for an empty body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.request_method = try allocator.dupe(u8, "GET");
    state.request_url = try allocator.dupe(u8, "http://example.com/");

    const request = try createRequest(allocator, &state, "");
    defer request.deinit();

    try std.testing.expectEqual(fetch_mod.internal.CredentialsMode.same_origin, request.credentials_mode);
    try std.testing.expect(!request.use_cors_preflight);
    try std.testing.expect(request.body == null);
}

test "createRequest - no request URL is an InvalidStateError, not a crash" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expectError(error.InvalidStateError, createRequest(allocator, &state, null));
}
