//! Fetch Algorithm - WHATWG Fetch Specification
//!
//! This module implements the top-level fetch algorithm that ties
//! everything together.
//!
//! Spec: https://fetch.spec.whatwg.org/#fetching
//!
//! The fetch algorithm:
//! 1. Create fetch params with request and timing info
//! 2. If request's URL is a local scheme, handle locally
//! 3. Otherwise dispatch to main fetch
//! 4. Handle response callbacks

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const InternalResponse = internal_response.InternalResponse;
const network = @import("../network/root.zig");
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const LibcurlBackend = network.LibcurlBackend;
const fetch_job = @import("fetch_job.zig");
const FetchJob = fetch_job.FetchJob;
const service_worker_fetch = @import("../internal/service_worker_fetch.zig");
const Body = @import("../internal/body.zig").Body;

pub const FetchError = fetch_job.FetchError;
pub const FetchResult = fetch_job.FetchResult;
pub const ProcessResponseCallback = fetch_job.ProcessResponseCallback;
pub const FetchOptions = fetch_job.FetchOptions;

/// Execute the top-level fetch algorithm, waiting for the network.
///
/// Every request HTTP-network fetch sends is performed there and then, so
/// this returns with the response - and nothing else on the thread runs until
/// it does. That is what navigation and synchronous XHR need; `fetch()`, the
/// method, runs the same algorithm on the event loop instead (see
/// `async_fetch.zig`). `request` is borrowed.
pub fn fetch(
    allocator: Allocator,
    request: *InternalRequest,
    options: FetchOptions,
) FetchError!FetchResult {
    const job = try FetchJob.create(allocator, request, false, options);
    defer job.destroy();

    var step = try job.start();
    while (true) switch (step) {
        .body => step = try job.resumeBody(),
        // A stream body still arriving: nothing here can wait for it (a
        // blocking fetch's request has a byte body), so it is a network
        // error.
        .request_body => step = try job.resumeRequestBody(),
        // A preloaded response candidate still pending: nothing here can wait
        // for it, so the request is fetched.
        .document_resource => step = try job.abandonDocumentResource(),
        .done => return job.takeResult(),
        .network => |needed| step = try job.resumeNetwork(sendObserved(allocator, job, needed)),
        // HTTP-network-or-cache fetch's prompt: the Browser's fetch observer
        // may answer it (CDP's Fetch.authRequired, from another thread while
        // this one waits); with nobody to, the default.
        .auth => |auth| {
            var hold: BlockingHold = .{ .allocator = allocator };
            defer hold.deinit();
            const answer: network.observer.AuthAnswer = if (hold.ask(.auth, job, null, .{ .challenge = &auth.challenge }, 0)) switch (hold.decision.?) {
                .auth => |a| a,
                else => .default,
            } else .default;
            step = try job.resumeAuth(answer);
        },
        .service_worker => |call| step = try job.resumeServiceWorker(try settleBlocking(abandonUpload(call).wait(service_worker_fetch.blocking_wait_limit_ms) orelse blk: {
            // No answer within the limit: given up on, a network error.
            call.abandon();
            break :blk .network_error;
        })),
    };
}

/// A stream body's relay writer, which a blocking fetch cannot pump (its
/// request's body is bytes, so none is made for it): let go, should there be
/// one. Returns `call`, for the wait.
fn abandonUpload(call: *service_worker_fetch.Call) *service_worker_fetch.Call {
    if (call.takeUpload()) |upload| {
        var u = upload;
        u.abandon();
    }
    return call;
}

/// A service worker's answer, waited for: a response's body is its relay's
/// whole body, collected as it is written. A body that fails is a network
/// error, as the network's does for a blocking fetch.
fn settleBlocking(answer: service_worker_fetch.Call.Answer) FetchError!FetchJob.ServiceWorkerAnswer {
    return switch (answer) {
        .fallback => .fallback,
        .network_error => .network_error,
        .response => |r| blk: {
            const relay = r.body orelse break :blk .{ .response = r.response };
            defer relay.release();
            const response = r.response;
            const bytes = relay.collect(response.allocator, service_worker_fetch.blocking_wait_limit_ms) catch |err| {
                relay.cancel();
                response.deinit();
                break :blk switch (err) {
                    error.OutOfMemory => FetchError.OutOfMemory,
                    error.NetworkError => .network_error,
                };
            };
            // The body takes the bytes (fromBytes would borrow them as its
            // source).
            const body = response.allocator.create(Body) catch {
                response.allocator.free(bytes);
                response.deinit();
                break :blk FetchError.OutOfMemory;
            };
            body.* = Body.init(response.allocator);
            body.data = .fromOwnedSlice(bytes);
            body.length = bytes.len;
            response.body = body;
            break :blk .{ .response = response };
        },
    };
}

/// HTTP-network fetch's request, with the Browser's fetch observer: it may
/// hold the request before it is sent (the request stage - every holder in
/// turn, each continue asking the next) and the network's answer before
/// fetch reads it (the response stage), and it hears what is sent and what
/// came (network/observer.zig). Where Chrome's DevToolsURLLoaderInterceptor
/// holds a synchronous XMLHttpRequest's loader while the renderer waits
/// (content/browser/devtools/devtools_url_loader_interceptor.cc): this
/// thread waits, and the holder answers from its own thread.
fn sendObserved(allocator: Allocator, job: *FetchJob, needed: FetchJob.NetworkStep) NetworkError!NetworkResponse {
    _ = needed;
    var chain: u32 = 0;
    while (true) {
        const request = job.pendingNetworkRequest() orelse return NetworkError.Unknown;
        if (job.isPreflight() or job.isRetry()) break;
        var hold: BlockingHold = .{ .allocator = allocator };
        defer hold.deinit();
        if (!hold.ask(.request, job, request, .none, chain)) break;
        switch (hold.decision.?) {
            .@"continue" => |overrides| job.overrideNetworkRequest(overrides) catch return NetworkError.OutOfMemory,
            .auth => {},
            .fulfill => |f| return network.observer.fulfilledResponse(allocator, job.request.currentUrl(), f) catch NetworkError.OutOfMemory,
            .fail => |reason| return reason.networkError(),
        }
        chain += 1;
    }
    const request = job.pendingNetworkRequest() orelse return NetworkError.Unknown;
    job.observeRequestSent();
    var answer = sendBlocking(allocator, .{ .request = request });
    if (answer) |*response| job.observeResponseHead(response) else |_| {}
    if (job.isPreflight()) return answer;
    var hold: BlockingHold = .{ .allocator = allocator };
    defer hold.deinit();
    const net_answer: network.observer.NetworkAnswer = if (answer) |*response| .{ .response = response } else |err| .{ .failed = err };
    if (answer) |*response| hold.response = response else |_| {}
    if (!hold.ask(.response, job, request, .{ .answer = net_answer }, 0)) return answer;
    switch (hold.decision.?) {
        .@"continue", .auth => return answer,
        .fulfill => |f| {
            // A new head, the body as it came (continueResponse).
            if (f.body == null) if (answer) |*response| {
                network.observer.replaceHead(response, f) catch {
                    response.deinit();
                    return NetworkError.OutOfMemory;
                };
                return response.*;
            } else |_| {};
            if (answer) |*response| response.deinit() else |_| {}
            return network.observer.fulfilledResponse(allocator, job.request.currentUrl(), f) catch NetworkError.OutOfMemory;
        },
        .fail => |reason| {
            if (answer) |*response| response.deinit() else |_| {}
            return reason.networkError();
        },
    }
}

/// One hold of a blocking fetch by its observer: this thread waits until
/// the holder decides - on whatever thread it decides (`any_thread`) - and
/// the decision is copied into the hold's arena before `decide` returns.
const BlockingHold = struct {
    allocator: Allocator,
    /// 1 once decided: the futex word the wait sleeps on.
    decided: std.atomic.Value(u32) = .init(0),
    arena: ?std.heap.ArenaAllocator = null,
    decision: ?network.observer.Decision = null,
    /// The response stage's answer, whole (this driver's network answers
    /// with the body): what readBody reads.
    response: ?*const NetworkResponse = null,

    const Asked = union(enum) {
        none,
        answer: network.observer.NetworkAnswer,
        challenge: *const network.observer.AuthChallenge,
    };

    /// Whether the observer holds the fetch at `stage`; when it does, this
    /// returns once it has decided (`decision`).
    fn ask(self: *BlockingHold, stage: network.observer.Stage, job: *FetchJob, request: ?*const network.NetworkRequest, asked: Asked, chain: u32) bool {
        const o = network.observer.of(job.request) orelse return false;
        const interception: network.observer.Interception = .{
            .context = self,
            .resume_fn = resumed,
            .request_id = job.request.request_id,
            .stage = stage,
            .any_thread = true,
            .chain = chain,
            .read_body_fn = if (stage == .response) readBody else null,
        };
        const held = switch (stage) {
            .request => if (o.intercept_request) |intercept| intercept(o.context, job.request, request.?, interception) else false,
            .response => if (o.intercept_response) |intercept| intercept(o.context, job.request, request.?, asked.answer, interception) else false,
            .auth => if (o.intercept_auth) |intercept| intercept(o.context, job.request, asked.challenge, interception) else false,
        };
        if (!held) return false;
        while (self.decided.load(.acquire) == 0) {
            futexIo().futexWaitTimeout(u32, &self.decided.raw, 0, .none) catch {};
        }
        return true;
    }

    /// Interception.decide, from the holder's thread.
    fn resumed(context: *anyopaque, decision: *const network.observer.Decision) void {
        const self: *BlockingHold = @ptrCast(@alignCast(context));
        if (self.decided.load(.acquire) != 0) return;
        self.arena = std.heap.ArenaAllocator.init(self.allocator);
        // Out of memory, the request goes on as it was.
        self.decision = network.observer.copyDecision(self.arena.?.allocator(), decision.*) catch .{ .@"continue" = .{} };
        self.decided.store(1, .release);
        futexIo().futexWake(u32, &self.decided.raw, 1);
    }

    /// Interception.readBody: the whole body is here already.
    fn readBody(context: *anyopaque, reader: network.observer.BodyReader) void {
        const self: *BlockingHold = @ptrCast(@alignCast(context));
        const response = self.response orelse return reader.done(reader.context, null);
        reader.done(reader.context, response.body orelse "");
    }

    fn deinit(self: *BlockingHold) void {
        if (self.arena) |*arena| arena.deinit();
    }
};

fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// Perform HTTP-network fetch's request now, blocking until it is answered.
fn sendBlocking(allocator: Allocator, needed: FetchJob.NetworkStep) NetworkError!NetworkResponse {
    const backend_impl = LibcurlBackend.init(allocator) catch {
        // A backend that cannot be made is a network error, not a lack of
        // memory the caller could act on.
        return NetworkError.Unknown;
    };
    defer backend_impl.deinit();
    return backend_impl.getBackend().send(allocator, needed.request);
}

/// Simplified fetch that just returns the response.
pub fn fetchSimple(
    allocator: Allocator,
    url: []const u8,
) FetchError!*InternalResponse {
    // Create a simple GET request
    const request = InternalRequest.init(allocator, url) catch {
        return FetchError.OutOfMemory;
    };
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    // Caller takes ownership of response
    const response = result.response;
    result.timing_info.deinit();
    return response;
}

/// Fetch with abort support.
pub fn fetchWithAbort(
    allocator: Allocator,
    request: *InternalRequest,
    abort_signal: ?*anyopaque,
    options: FetchOptions,
) FetchError!FetchResult {
    _ = abort_signal; // TODO: Implement abort signal integration
    return fetch(allocator, request, options);
}

// =============================================================================
// Tests
// =============================================================================

test "fetch - about:blank" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "about:blank");
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    try std.testing.expect(result.timing_info.start_time > 0);
    try std.testing.expect(result.timing_info.end_time >= result.timing_info.start_time);
}

test "fetch - data URL" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "data:text/plain,Hello");
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
}

test "fetch - unsupported scheme" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "ftp://example.com");
    defer request.deinit();

    var result = try fetch(allocator, request, .{});
    defer result.deinit();

    // Should return network error
    try std.testing.expectEqual(internal_response.ResponseType.@"error", result.response.response_type);
}

test "fetchSimple - about:blank" {
    const allocator = std.testing.allocator;

    const response = try fetchSimple(allocator, "about:blank");
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 200), response.status);
}

test "extractScheme" {
    const extractScheme = fetch_job.extractScheme;
    try std.testing.expectEqualStrings("https", extractScheme("https://example.com"));
    try std.testing.expectEqualStrings("http", extractScheme("http://example.com"));
    try std.testing.expectEqualStrings("data", extractScheme("data:text/plain,Hello"));
    try std.testing.expectEqualStrings("about", extractScheme("about:blank"));
    try std.testing.expectEqualStrings("", extractScheme("no-colon"));
}
