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
const InternalRequest = @import("../internal/request.zig").InternalRequest;
const InternalResponse = @import("../internal/response.zig").InternalResponse;
const backend = @import("backend.zig");
const NetworkRequest = backend.NetworkRequest;

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

    /// The response is handed over (Fetch "fetch response handover"), its
    /// body perhaps still arriving.
    response_received: ?*const fn (context: *anyopaque, request: *const InternalRequest, response: *const InternalResponse) void = null,

    /// The handed-over response's body ended: received whole, with
    /// `encoded_length` bytes of it as they came over the network.
    loading_finished: ?*const fn (context: *anyopaque, request: *const InternalRequest, encoded_length: u64) void = null,

    /// The fetch ended in a network error (`canceled`: its client went, or
    /// it was aborted).
    loading_failed: ?*const fn (context: *anyopaque, request: *const InternalRequest, error_text: []const u8, canceled: bool) void = null,

    /// HTTP-network fetch is about to hand `network_request` to the network.
    /// True: the observer holds it, and answers later - on the same thread,
    /// from a task of the agent's event loop - through `interception`. A
    /// driver that cannot wait (the blocking fetch) never asks.
    intercept_request: ?*const fn (context: *anyopaque, request: *const InternalRequest, network_request: *const NetworkRequest, interception: Interception) bool = null,

    /// A held request's fetch ended before the observer answered (its client
    /// went): the `Interception` it holds for `request_id` is dead.
    interception_dropped: ?*const fn (context: *anyopaque, request_id: u64) void = null,
};

/// What the observer decided for a request it held.
pub const Decision = union(enum) {
    /// Send it, with any of these changed (BORROWED for the call).
    @"continue": Overrides,
    /// Do not send it: this is the network's answer (BORROWED for the call).
    fulfill: Fulfillment,
    /// Do not send it: a network error.
    fail: FailReason,
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
    body: []const u8 = "",
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
};

/// The observer of the Browser `request`'s client belongs to, if any.
pub fn of(request: *const InternalRequest) ?*const Observer {
    const network = request.network orelse return null;
    return if (network.observer) |*o| o else null;
}

/// A held request's way back: `decide` resumes its fetch. Call it once, on
/// the fetch's own thread (a task of its event loop), and never after the
/// observer heard `interception_dropped` for its request.
pub const Interception = struct {
    context: *anyopaque,
    resume_fn: *const fn (context: *anyopaque, decision: *const Decision) void,
    request_id: u64,

    pub fn decide(self: Interception, decision: Decision) void {
        self.resume_fn(self.context, &decision);
    }
};
