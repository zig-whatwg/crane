//! Fire-and-forget fetches: a request whose response nobody waits for, which
//! frees itself when its fetch ends. `navigator.sendBeacon()`, Reporting's
//! uploads (dom.reporting) and hyperlink auditing's pings
//! (html.hyperlink_auditing) start their requests here; `fetch()` has a
//! promise to settle and is its own client (WindowOrWorkerGlobalScope), but
//! takes its keepalive budget the same way (`Reservation`).
//!
//! ## The API
//!
//! ```zig
//! const keepalive_fetch = @import("dom").keepalive_fetch;
//! // sendBeacon(): false for a mixed-content block or when the fetch
//! // group's keepalive budget cannot take the body (Beacon 3.2 step 6.2).
//! return keepalive_fetch.send(global, request, .{});
//! ```
//!
//! - `global` is the request's client's global object - for sendBeacon,
//!   this's relevant global object. Its fetch group is the one a counted
//!   load reserves against, and the dispatch runs in its realm: it is
//!   allocated with `global.ctx.allocator`, and it is terminated when that
//!   realm retires.
//! - `request` is already extracted (body, Content-Type, mode, credentials,
//!   initiator type, keepalive) and populated from its client
//!   (`fetch.internal.populateRequestFromClient` with
//!   `dom.global_settings.requestClient(global)`). It is TAKEN on every path:
//!   freed when the dispatch is rejected or fails to start.
//! - Rejected (false, or null from `start`): `request.keepalive` is set, its
//!   URL is HTTP(S), it has a body, and that body's length plus the bytes of
//!   the fetch group's keepalive requests in flight exceeds 64 KiB (Fetch
//!   HTTP-network-or-cache fetch step 8.10). Nothing is sent. Otherwise the
//!   body's bytes are in flight until the fetch ends, finished or
//!   terminated - once.
//! - `send`, for a `.fetch` load with empty destination, also returns false
//!   when mixed content would block it after upgrade-insecure-requests.
//!   A CSP block returns true, reports the violation and sends nothing,
//!   before consulting the budget. An accepted request reaches main fetch
//!   unchanged so report-only CSP still sees its original URL before UIR.
//!   `.ping` keeps its asynchronous policy checks. Other true results mean
//!   the fetch started; its response is ignored. An error (out of memory)
//!   means nothing was sent.
//! - `start` performs the budget check and dispatches with an `Observer`
//!   and a handle, without `send`'s acceptance precheck: the observer
//!   hears the response's status and the dispatch's end, and the handle
//!   can `cancel` the fetch until the end is heard. Hyperlink auditing
//!   cancels its pings when their document is aborted; Reporting reads
//!   its endpoint's status.
//! - `Options.load` says whether the request counts: `.fetch` (the
//!   default; sendBeacon) does, `.ping` (CSP reports, a-ping) does not -
//!   the browsers' majority, see `Load`.
//!
//! ## Lifetime
//!
//! A dispatch holds nothing it does not own or cannot check: its request
//! is the fetch's (`AsyncFetch` owns it), its realm is a `runtime.Context`,
//! which stays a valid, inert record after the realm retires until its
//! agent ends (engine_protocol.zig's Context contract; context_manager
//! retires entries rather than freeing them), and its global - for the
//! budget it reserved - is a slab-generation link, checked before the
//! fetch group is touched. It never reaches the document: "abort a
//! document" (dom.document_fetches) does not cancel it, which is
//! keepalive's purpose, and the document and its global may be freed
//! while it is in flight; the fetch group goes with its global, and so
//! does the reservation. Like `fetch({keepalive: true})` and Codex row
//! 12's reporting uploads it is still terminated when its realm retires
//! (`alive`): the request's client fields - its CSP violation and resource
//! timing reporters - name the global unguarded, and termination at the
//! next sweep keeps the network from reaching them after it goes.
//! Surviving that needs an agent-level owner and guarded client fields;
//! retaining a dead global would not provide one.
//!
//! Spec: https://fetch.spec.whatwg.org/#request-keepalive-flag
//! Spec: https://fetch.spec.whatwg.org/#http-network-or-cache-fetch
//! Spec: https://w3c.github.io/beacon/#sec-processing-model

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const global_settings = @import("global_settings.zig");
const FetchGroup = @import("document_fetches.zig").FetchGroup;

const AsyncFetch = fetch.algorithms.AsyncFetch;
pub const Error = fetch.algorithms.FetchError;

/// Whether a keepalive request counts against its fetch group's budget.
pub const Load = enum {
    /// A keepalive fetch: sendBeacon, fetch({keepalive: true}). Counted.
    fetch,
    /// A ping load - a legacy CSP report, a hyperlink-auditing ping. Not
    /// counted, although Fetch step 8.10 counts every keepalive request
    /// with a client. The browsers split 2-1: WebKit's CachedResource::load
    /// registers a keepalive load with the KeepaliveRequestTracker only
    /// when its type is not Ping, and PingLoader::startPingLoad makes CSP
    /// reports and pings Ping resources (CachedResource.cpp, the
    /// `type() != Type::Ping` check); Gecko's only caller of
    /// FetchUtil::IncrementPendingKeepaliveRequestSize is dom/fetch/Fetch.cpp,
    /// and its pings (nsDocShell) and CSP reports (nsCSPContext) open
    /// channels directly. Blink counts both: PingLoader::SendLinkAuditPing
    /// and SendViolationReport set keepalive and start through
    /// ResourceFetcher::StartLoad. No wpt.fyi file tests either.
    ping,
};

/// A slab-generation link to a global: whether `instance` is still the
/// object the link was taken on. The slab recycles addresses.
const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }
    fn isLive(self: Link) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// One counted keepalive request's body bytes in its client's fetch group,
/// from its start until it ends. Released exactly once, by its holder; a
/// release after the global went touches nothing - the fetch group went
/// with it.
pub const Reservation = struct {
    global: Link,
    bytes: u64,

    /// Fetch HTTP-network-or-cache fetch step 8.10, for a request starting:
    /// reserve its body's length in `global`'s fetch group. Null - nothing
    /// to hold - for a load that does not count: not keepalive, not
    /// HTTP(S), no body (contentLength null), an empty one, or a global
    /// that keeps no fetch group. error.OverQuota is step 8.10.5's network
    /// error.
    ///
    /// Taken once, as the request starts, and held across its redirects:
    /// the spec's check at each HTTP-network-or-cache fetch, summing the
    /// group's records, would count the request's own record too (see
    /// document_fetches.FetchGroup); the browsers count at start (Blink
    /// ResourceFetcher::StartLoad, WebKit CachedResource::load, Gecko
    /// FetchRequest via FetchUtil).
    pub fn take(global: *runtime.Instance, request: *const fetch.internal.InternalRequest, load: Load) error{OverQuota}!?Reservation {
        if (load == .ping or !request.keepalive) return null;
        // The check is HTTP-network-or-cache fetch's: a data:, blob: or
        // about: fetch never reaches it.
        const url = request.getUrl();
        if (!std.ascii.startsWithIgnoreCase(url, "http:") and !std.ascii.startsWithIgnoreCase(url, "https:")) return null;
        const length = contentLength(request) orelse return null;
        if (length == 0) return null;
        const group = global_settings.fetchGroupOf(global) orelse return null;
        if (!group.reserveKeepalive(length)) return error.OverQuota;
        return .{ .global = Link.to(global), .bytes = length };
    }

    /// The request is done or terminated.
    pub fn release(self: Reservation) void {
        if (!self.global.isLive()) return;
        const group = global_settings.fetchGroupOf(self.global.instance) orelse return;
        group.releaseKeepalive(self.bytes);
    }
};

/// HTTP-network-or-cache fetch step 8.3's contentLength: the body's
/// length, null without a body.
fn contentLength(request: *const fetch.internal.InternalRequest) ?u64 {
    const body = request.body orelse return null;
    return switch (body) {
        .bytes => |bytes| bytes.len,
        .body => |b| b.length orelse b.data.items.len,
    };
}

/// Who hears how a `start`ed dispatch goes. Both run from the event loop's
/// network step, never from inside `start`.
pub const Observer = struct {
    context: *anyopaque,
    /// The response's status, 0 for a network error. At most once, before
    /// `ended`; not at all when the fetch is terminated first.
    response: ?*const fn (context: *anyopaque, status: u16) void = null,
    /// The dispatch is over and freed: its handle is gone. Exactly once for
    /// an accepted dispatch that is not `cancel`ed.
    ended: ?*const fn (context: *anyopaque) void = null,
};

pub const Options = struct {
    load: Load = .fetch,
    observer: ?Observer = null,
};

/// One request in flight. Frees itself; see the module comment.
pub const Dispatch = struct {
    allocator: std.mem.Allocator,
    /// The realm of the global that started it. A page that ends retires
    /// its context - `engine_ctx` becomes null - and the fetch is
    /// terminated with it.
    ctx: runtime.Context,
    /// The body's bytes in the client's fetch group, until the end.
    reservation: ?Reservation = null,
    observer: ?Observer = null,
    /// The fetch, until it ends (`finished`, `gone`) or is canceled.
    active: ?*AsyncFetch = null,

    /// End the fetch now: its transfer is cancelled, its bytes leave the
    /// fetch group, and the dispatch is freed. The observer hears nothing
    /// more, `ended` included.
    pub fn cancel(self: *Dispatch) void {
        const active = self.active;
        self.active = null;
        // terminate calls neither gone nor finished.
        if (active) |f| f.terminate();
        self.destroy();
    }

    fn client(self: *Dispatch) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = over, .finished = over };
    }

    fn alive(context: *anyopaque) bool {
        const self: *Dispatch = @ptrCast(@alignCast(context));
        return self.ctx.hasEngine();
    }

    /// The response, with its whole body: only its status is heard.
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Dispatch = @ptrCast(@alignCast(context));
        const status: u16 = blk: {
            var result = outcome catch break :blk 0;
            defer result.deinit();
            break :blk result.response.status;
        };
        const observer = self.observer orelse return;
        if (observer.response) |response| response(observer.context, status);
    }

    /// The fetch is over: it finished, or was terminated with its realm.
    fn over(context: *anyopaque) void {
        const self: *Dispatch = @ptrCast(@alignCast(context));
        self.active = null;
        const observer = self.observer;
        self.destroy();
        if (observer) |o| if (o.ended) |ended| ended(o.context);
    }

    fn destroy(self: *Dispatch) void {
        if (self.reservation) |reservation| reservation.release();
        self.reservation = null;
        self.allocator.destroy(self);
    }
};

/// Start fetching `request` for `global`, ignoring its response. Takes
/// `request` on every path. Null means rejected: nothing was sent.
pub fn start(global: *runtime.Instance, request: *fetch.internal.InternalRequest, options: Options) Error!?*Dispatch {
    const allocator = global.ctx.allocator;
    var owns_request = true;
    defer if (owns_request) request.deinit();
    const reservation = Reservation.take(global, request, options.load) catch return null;
    errdefer if (reservation) |r| r.release();
    const self = try allocator.create(Dispatch);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .ctx = global.ctx, .observer = options.observer };
    // The fetch owns the request from here, and frees it if it fails.
    owns_request = false;
    self.active = try AsyncFetch.start(allocator, request, .{}, @import("agent_fetches.zig").of(global.ctx), self.client());
    // Held from here: the dispatch's end releases it.
    self.reservation = reservation;
    return self;
}

/// Beacon's immediate acceptance: false for mixed content or budget
/// rejection, true for a CSP block or a started fetch. Takes `request` on
/// every path. `.ping` callers keep `start`'s asynchronous policy checks.
pub fn send(global: *runtime.Instance, request: *fetch.internal.InternalRequest, options: Options) Error!bool {
    var owns_request = true;
    defer if (owns_request) request.deinit();
    if (options.load == .fetch) {
        std.debug.assert(request.destination == .empty);
        const csp_check = fetch.algorithms.csp_check;
        const container = switch (request.policy_container) {
            .client => null,
            .container => |*value| value,
        };
        // Blink SendBeaconCommon checks CSP before creating its fetch and
        // returns true on a block; otherwise it returns whether the resource
        // is not a LoadError. A CSP-blocked mixed request thus returns true,
        // without reserving quota. The silent probe precedes the one report.
        // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/ping_loader.cc
        if (container) |policy| {
            if (csp_check.isBlockedFor(policy, request.currentUrl(), .empty, null)) {
                csp_check.reportViolationsForRequest(request);
                _ = csp_check.shouldRequestBeBlocked(request);
                return true;
            }
        }
        // Main fetch steps 5-7, without changing the real request: step 4's
        // report-only CSP must still see the original URL. Mixed Content's
        // step 6 upgrade only touches image/audio/video, never this empty
        // destination. Reuse the same predicates as the mutating fetch path.
        // Beacon §3.2's final true differs from the browsers' synchronous
        // mixed-content rejection: at WPT revision 521d168d63, Chrome,
        // Firefox and Safari each pass all 8 HTTP/HTTPS cases in the four
        // beacon/headers/header-referrer-*.https.html files (run IDs
        // 5071749074124800, 5195569390944256, 5823052670828544). Blink's
        // SendBeaconCommon LoadError check above is the implementation model.
        const allocator = request.allocator;
        const upgraded: ?[]const u8 = if (fetch.algorithms.main_fetch.wouldUpgradeToPotentiallyTrustworthyUrl(request))
            try std.mem.concat(allocator, u8, &.{ "https", request.currentUrl()[4..] })
        else
            null;
        defer if (upgraded) |url| allocator.free(url);
        if (try fetch.mixed_content.shouldBlockRequestAt(request, upgraded orelse request.currentUrl())) {
            // Main fetch will not run; perform its preceding report-only
            // step once before releasing this rejected request.
            csp_check.reportViolationsForRequest(request);
            return false;
        }
    }
    owns_request = false; // start takes the request, including on failure.
    return (try start(global, request, options)) != null;
}

test "a reservation counts only a keepalive HTTP(S) request with a body, and only as a fetch load" {
    const request = try fetch.internal.InternalRequest.init(std.testing.allocator, "https://example.test/beacon");
    defer request.deinit();
    try std.testing.expectEqual(@as(?u64, null), contentLength(request));
    request.body = .{ .bytes = "12345" };
    try std.testing.expectEqual(@as(?u64, 5), contentLength(request));
    // A global no kind owns keeps no fetch group, but every exemption is
    // decided before the group is looked up: never dereferenced.
    var global: runtime.Instance = undefined;
    try std.testing.expectEqual(@as(?Reservation, null), try Reservation.take(&global, request, .fetch));
    request.keepalive = true;
    try std.testing.expectEqual(@as(?Reservation, null), try Reservation.take(&global, request, .ping));
    request.body = .{ .bytes = "" };
    try std.testing.expectEqual(@as(?Reservation, null), try Reservation.take(&global, request, .fetch));
}
