//! A Browser's fetch observer: one listener told of each fetch's progress at
//! Fetch's steps, and given the chance to hold a request before it goes to
//! the network.
//!
//! A generic host hook, not a CDP one: a host's network log, a proxy UI, an
//! automation protocol (CDP's Network events and its Fetch interception;
//! tmp/plans/cdp-part1-design.md 3.9-3.10), a test. One slot per Browser, on
//! its network context (`NetworkContext.observer`); nobody observing costs
//! one null check at each step. Chromium has the same two layers: Blink's
//! probe points in the loader (probe::WillSendRequest,
//! DidReceiveResourceResponse, DidFinishLoading, DidFailLoading -
//! third_party/blink/renderer/core/loader/resource_fetcher.cc and
//! inspector_network_agent.cc) for the events, and the network service's
//! DevToolsURLLoaderInterceptor (content/browser/devtools/
//! devtools_url_loader_interceptor.cc) for interception, which sits below
//! the page and its service worker, where the request is final and before
//! the transfer starts - here, HTTP-network fetch's hand-over to the
//! network.
//!
//! The observer is called on the thread of the agent whose fetch it is (a
//! Browser's window agent, or one of its workers' threads): it checks which
//! before touching anything of its own. It must not run script, re-enter
//! fetch or keep what a call lends it (everything is BORROWED for the
//! call), except the `Interception` it was handed for a request it holds.

const std = @import("std");
const Allocator = std.mem.Allocator;
const InternalRequest = @import("../internal/request.zig").InternalRequest;
const InternalResponse = @import("../internal/response.zig").InternalResponse;
const backend = @import("backend.zig");
const NetworkRequest = backend.NetworkRequest;
const NetworkResponse = backend.NetworkResponse;

pub const Observer = struct {
    context: *anyopaque,

    /// Fetch begins (main fetch), and again for each redirect it follows
    /// (`redirect_received` told of the response first). Answers the id it
    /// names the fetch by (InternalRequest.request_id), kept across its
    /// redirects; 0 names none.
    will_send_request: ?*const fn (context: *anyopaque, request: *const InternalRequest) u64 = null,

    /// HTTP fetch is about to follow `response`, a redirect, with
    /// HTTP-redirect fetch: `will_send_request` comes next, for its new URL.
    redirect_received: ?*const fn (context: *anyopaque, request: *const InternalRequest, response: *const InternalResponse) void = null,

    /// Whether the fetch goes past the HTTP cache (its cache mode becomes
    /// "no-store"): a host's "disable cache" (DevTools' Network
    /// .setCacheDisabled, Chrome's LOAD_BYPASS_CACHE). Asked as fetch begins.
    bypass_cache: ?*const fn (context: *anyopaque, request: *const InternalRequest) bool = null,

    /// HTTP-network-or-cache fetch answered from the Browser's HTTP cache.
    served_from_cache: ?*const fn (context: *anyopaque, request: *const InternalRequest) void = null,

    /// HTTP-network fetch hands `network_request` to the network now - the
    /// transfer starts, its headers final (what HTTP-network-or-cache fetch
    /// added included): CDP's Network.requestWillBeSentExtraInfo, which
    /// Chrome's network service reports below the page (services/network/
    /// url_loader.cc OnConnected -> DevToolsObserver::OnRawRequest).
    request_sent: ?*const fn (context: *anyopaque, request: *const InternalRequest, network_request: *const NetworkRequest) void = null,

    /// The network's answer to the request `request_sent` named, its head as
    /// it came - before Fetch reads it, before anything holds it: CDP's
    /// Network.responseReceivedExtraInfo (DevToolsObserver::OnRawResponse).
    /// The body may still be arriving.
    response_head_received: ?*const fn (context: *anyopaque, request: *const InternalRequest, network_response: *const NetworkResponse) void = null,

    /// The response is handed over (Fetch "fetch response handover"), its
    /// body perhaps still arriving.
    response_received: ?*const fn (context: *anyopaque, request: *const InternalRequest, response: *const InternalResponse) void = null,

    /// More of the response's body, its content codings undone, as it
    /// arrives (Blink's probe::DidReceiveData) - from the network, a
    /// service worker, or all at once for a body that was whole when it was
    /// handed over. May come before `response_received` for a body fetch
    /// waits for (main fetch step 23). BORROWED for the call.
    data_received: ?*const fn (context: *anyopaque, request: *const InternalRequest, bytes: []const u8) void = null,

    /// The handed-over response's body ended: received whole, with
    /// `encoded_length` bytes of it as they came over the network.
    loading_finished: ?*const fn (context: *anyopaque, request: *const InternalRequest, encoded_length: u64) void = null,

    /// The fetch ended in a network error (`canceled`: its client went, or
    /// it was aborted).
    loading_failed: ?*const fn (context: *anyopaque, request: *const InternalRequest, error_text: []const u8, canceled: bool) void = null,

    /// HTTP-network fetch is about to hand `network_request` to the network
    /// (the REQUEST stage). True: the observer holds it, and answers later
    /// through `interception` (Decision: continue, fulfill or fail). Both
    /// drivers ask: the event loop's parks the fetch, the blocking one
    /// (synchronous XHR, a navigation's own) waits on its thread, which
    /// lets the observer answer from ANY thread (`Interception.any_thread`)
    /// - as Chrome's DevToolsURLLoaderInterceptor answers in the browser
    /// process while the renderer waits. `interception.chain` holders have
    /// let it go already (each continue asks again: Chrome chains one
    /// interceptor per session).
    intercept_request: ?*const fn (context: *anyopaque, request: *const InternalRequest, network_request: *const NetworkRequest, interception: Interception) bool = null,

    /// The network answered - a response head, or no response at all
    /// (`NetworkAnswer.failed`) - and nothing has read it yet (the RESPONSE
    /// stage, Chrome's kResponse: "HeadersReceived"). True: the observer
    /// holds it, and answers through `interception` - continue (hand it on),
    /// fulfill (a head of its own and the original body, or another answer
    /// whole) or fail; `Interception.readBody` reads its whole body first.
    intercept_response: ?*const fn (context: *anyopaque, request: *const InternalRequest, network_request: *const NetworkRequest, answer: NetworkAnswer, interception: Interception) bool = null,

    /// HTTP-network-or-cache fetch is at "prompt the end user for a username
    /// and password" (steps 15-16: a 401's challenge, a 407's) - Chrome's
    /// URLLoader OnAuthRequired, where DevTools' handleAuthRequests holds
    /// it (Fetch.authRequired). True: the observer answers through
    /// `interception` with Decision.auth.
    intercept_auth: ?*const fn (context: *anyopaque, request: *const InternalRequest, challenge: *const AuthChallenge, interception: Interception) bool = null,

    /// A held request's fetch ended before the observer answered (its client
    /// went): the `Interception` it holds for `request_id` is dead.
    interception_dropped: ?*const fn (context: *anyopaque, request_id: u64) void = null,
};

/// What the network gave a request held at the response stage.
pub const NetworkAnswer = union(enum) {
    /// The head (the blocking driver's: with the whole body). BORROWED.
    response: *const NetworkResponse,
    /// No response: the transfer failed.
    failed: backend.NetworkError,
};

/// Where a request is held.
pub const Stage = enum { request, response, auth };

/// An authentication challenge (HTTP-network-or-cache fetch 15-16).
pub const AuthChallenge = struct {
    /// A 401's (the origin server's) or a 407's (the proxy's).
    source: enum { server, proxy },
    /// The challenger's origin, serialized.
    origin: []const u8,
    /// Its scheme, lowercase ("basic").
    scheme: []const u8,
    /// Its realm, possibly empty.
    realm: []const u8,
};

/// What the observer decided for a request it held.
pub const Decision = union(enum) {
    /// Request stage: send it, with any of these changed. Response stage:
    /// hand the response on as it came (Chrome drops a continue's request
    /// changes there). Auth stage: as `.auth = .default`. BORROWED.
    @"continue": Overrides,
    /// Do not send it (request stage), or replace the response (response
    /// stage): this is the network's answer. BORROWED.
    fulfill: Fulfillment,
    /// Do not send it / drop the response: a network error.
    fail: FailReason,
    /// Auth stage: the answer to the challenge. BORROWED.
    auth: AuthAnswer,
};

pub const Overrides = struct {
    url: ?[]const u8 = null,
    method: ?[]const u8 = null,
    /// Replaces the request's headers whole.
    headers: ?[]const NetworkRequest.Header = null,
    body: ?[]const u8 = null,
};

pub const Fulfillment = struct {
    status: u16,
    status_message: []const u8 = "",
    headers: []const backend.NetworkResponse.Header = &.{},
    /// Null: at the response stage the original body (Chrome's
    /// continueResponse with a new head - "only the head is replaced, the
    /// original body loads"), at the request stage an empty one.
    body: ?[]const u8 = "",
};

/// Fetch.continueWithAuth's answer.
pub const AuthAnswer = union(enum) {
    /// The default with no prompt UI: as the fetch would go on with nobody
    /// asked (URL credentials, else the challenge's response handed on).
    default,
    /// No credentials: the challenge's response is handed on.
    cancel,
    /// Send the request again with these credentials. BORROWED.
    provide: struct { username: []const u8, password: []const u8 },
};

/// CDP's Network.ErrorReason, as the network answers each.
pub const FailReason = enum {
    failed,
    aborted,
    timed_out,
    access_denied,
    connection_closed,
    connection_reset,
    connection_refused,
    connection_aborted,
    connection_failed,
    name_not_resolved,
    internet_disconnected,
    address_unreachable,
    blocked_by_client,
    blocked_by_response,

    /// The network error a driver resumes with for `reason`.
    pub fn networkError(reason: FailReason) backend.NetworkError {
        return switch (reason) {
            .timed_out => error.RequestTimeout,
            .name_not_resolved => error.DnsResolutionFailed,
            .connection_refused => error.ConnectionRefused,
            .connection_reset => error.ConnectionReset,
            .address_unreachable => error.HostUnreachable,
            .internet_disconnected => error.NetworkUnreachable,
            .aborted, .blocked_by_client, .blocked_by_response => error.Aborted,
            .failed, .access_denied, .connection_closed, .connection_aborted, .connection_failed => error.ConnectionRefused,
        };
    }
};

/// The observer of the Browser `request`'s client belongs to, if any.
pub fn of(request: *const InternalRequest) ?*const Observer {
    const network = request.network orelse return null;
    return if (network.observer) |*o| o else null;
}

/// Where a held response's whole body goes (`Interception.readBody`):
/// `done` once, with the bytes (BORROWED for the call), or null when the
/// body failed.
pub const BodyReader = struct {
    context: *anyopaque,
    done: *const fn (context: *anyopaque, body: ?[]const u8) void,
};

/// A held request's way back: `decide` resumes its fetch. Call it once -
/// on the fetch's own thread (a task of its event loop), or on any thread
/// when `any_thread` - and never after the observer heard
/// `interception_dropped` for its request.
pub const Interception = struct {
    context: *anyopaque,
    resume_fn: *const fn (context: *anyopaque, decision: *const Decision) void,
    request_id: u64,
    stage: Stage = .request,
    /// The driver waits on its own thread (the blocking fetch): `decide`
    /// and `readBody` may be called from any thread, and the decision's
    /// data are copied before `decide` returns.
    any_thread: bool = false,
    /// How many holders let this request go before this one (chained
    /// observers' sessions: the next asks with one more).
    chain: u32 = 0,
    /// Response stage: read the held response's whole body. On the fetch's
    /// thread (or any, with `any_thread`); `reader.done` once, perhaps
    /// later, when the body has all arrived. A later `continue` hands on
    /// what was read.
    read_body_fn: ?*const fn (context: *anyopaque, reader: BodyReader) void = null,

    pub fn decide(self: Interception, decision: Decision) void {
        self.resume_fn(self.context, &decision);
    }

    /// False: no body to read at this stage (`reader` is not called).
    pub fn readBody(self: Interception, reader: BodyReader) bool {
        const read = self.read_body_fn orelse return false;
        read(self.context, reader);
        return true;
    }
};

/// The NetworkResponse a fulfillment makes: what the transfer would have
/// made of a response with this head and body (`body` null: empty), its
/// URL `url`. OWNED by `allocator`.
pub fn fulfilledResponse(allocator: Allocator, url: []const u8, f: Fulfillment) Allocator.Error!NetworkResponse {
    const headers = try allocator.alloc(NetworkResponse.Header, f.headers.len);
    var made: usize = 0;
    errdefer {
        for (headers[0..made]) |h| {
            allocator.free(h.name);
            allocator.free(h.value);
        }
        allocator.free(headers);
    }
    for (f.headers, 0..) |h, i| {
        const name = try allocator.dupe(u8, h.name);
        errdefer allocator.free(name);
        headers[i] = .{ .name = name, .value = try allocator.dupe(u8, h.value) };
        made += 1;
    }
    const body = try allocator.dupe(u8, f.body orelse "");
    errdefer allocator.free(body);
    const final_url = try allocator.dupe(u8, url);
    errdefer allocator.free(final_url);
    const status_message = if (f.status_message.len > 0) try allocator.dupe(u8, f.status_message) else "";
    return .{
        .allocator = allocator,
        .status = f.status,
        .status_message = status_message,
        .http_version = .http_1_1,
        .headers = headers,
        .body = body,
        .encoded_body_size = body.len,
        .final_url = final_url,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

/// `response`'s head replaced by a fulfillment's (status, message,
/// headers), its body kept: Chrome's continueResponse with a new head.
/// The old head's strings are freed.
pub fn replaceHead(response: *NetworkResponse, f: Fulfillment) Allocator.Error!void {
    const allocator = response.allocator;
    const headers = try allocator.alloc(NetworkResponse.Header, f.headers.len);
    var made: usize = 0;
    errdefer {
        for (headers[0..made]) |h| {
            allocator.free(h.name);
            allocator.free(h.value);
        }
        allocator.free(headers);
    }
    for (f.headers, 0..) |h, i| {
        const name = try allocator.dupe(u8, h.name);
        errdefer allocator.free(name);
        headers[i] = .{ .name = name, .value = try allocator.dupe(u8, h.value) };
        made += 1;
    }
    const status_message = if (f.status_message.len > 0) try allocator.dupe(u8, f.status_message) else "";
    for (response.headers) |h| {
        allocator.free(h.name);
        allocator.free(h.value);
    }
    allocator.free(response.headers);
    if (response.status_message.len > 0) allocator.free(response.status_message);
    response.headers = headers;
    response.status = f.status;
    response.status_message = status_message;
}

/// A copy of `decision` whose strings are `allocator`'s - an arena's: the
/// decision a holder on another thread made, kept past its call.
pub fn copyDecision(allocator: Allocator, decision: Decision) Allocator.Error!Decision {
    return switch (decision) {
        .@"continue" => |o| .{ .@"continue" = .{
            .url = if (o.url) |v| try allocator.dupe(u8, v) else null,
            .method = if (o.method) |v| try allocator.dupe(u8, v) else null,
            .headers = if (o.headers) |headers| blk: {
                const list = try allocator.alloc(NetworkRequest.Header, headers.len);
                for (headers, 0..) |h, i| list[i] = .{ .name = try allocator.dupe(u8, h.name), .value = try allocator.dupe(u8, h.value) };
                break :blk list;
            } else null,
            .body = if (o.body) |v| try allocator.dupe(u8, v) else null,
        } },
        .fulfill => |f| .{ .fulfill = .{
            .status = f.status,
            .status_message = try allocator.dupe(u8, f.status_message),
            .headers = blk: {
                const list = try allocator.alloc(NetworkResponse.Header, f.headers.len);
                for (f.headers, 0..) |h, i| list[i] = .{ .name = try allocator.dupe(u8, h.name), .value = try allocator.dupe(u8, h.value) };
                break :blk list;
            },
            .body = if (f.body) |v| try allocator.dupe(u8, v) else null,
        } },
        .fail => |reason| .{ .fail = reason },
        .auth => |answer| .{ .auth = switch (answer) {
            .default => .default,
            .cancel => .cancel,
            .provide => |given| .{ .provide = .{ .username = try allocator.dupe(u8, given.username), .password = try allocator.dupe(u8, given.password) } },
        } },
    };
}

test "copyDecision copies every string, so the original may go" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    var url = "https://a.test/x".*;
    var name = "x-a".*;
    var value = "1".*;
    const headers = [_]NetworkRequest.Header{.{ .name = &name, .value = &value }};
    const copied = try copyDecision(arena_state.allocator(), .{ .@"continue" = .{ .url = &url, .headers = &headers } });
    @memset(&url, 'z');
    @memset(&name, 'z');
    try std.testing.expectEqualStrings("https://a.test/x", copied.@"continue".url.?);
    try std.testing.expectEqualStrings("x-a", copied.@"continue".headers.?[0].name);
    const auth = try copyDecision(arena_state.allocator(), .{ .auth = .{ .provide = .{ .username = "u", .password = "p" } } });
    try std.testing.expectEqualStrings("u", auth.auth.provide.username);
}

test "FailReason: each reason is the network error Chrome's net error is" {
    try std.testing.expectEqual(backend.NetworkError.DnsResolutionFailed, FailReason.name_not_resolved.networkError());
    try std.testing.expectEqual(backend.NetworkError.Aborted, FailReason.blocked_by_client.networkError());
    try std.testing.expectEqual(backend.NetworkError.ConnectionRefused, FailReason.failed.networkError());
}
