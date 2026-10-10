//! Fire-and-forget fetches: a request whose response nobody waits for, which
//! frees itself when its fetch ends. `navigator.sendBeacon()`, Reporting's
//! uploads (dom.reporting) and hyperlink auditing's pings
//! (html.hyperlink_auditing) start their requests here; `fetch()` has a
//! promise to settle and is its own client (WindowOrWorkerGlobalScope).
//!
//! ## The API
//!
//! ```zig
//! const keepalive_fetch = @import("dom").keepalive_fetch;
//! // sendBeacon(): true when the request was accepted and started.
//! const accepted = try keepalive_fetch.send(global, request, .{});
//! ```
//!
//! - `global` is the request's client's global object - for sendBeacon,
//!   this's relevant global object. The dispatch runs in its realm: it is
//!   allocated with `global.ctx.allocator`, and it is terminated when that
//!   realm retires.
//! - `request` is already extracted (body, Content-Type, mode, credentials,
//!   initiator type) and populated from its client
//!   (`fetch.internal.populateRequestFromClient` with
//!   `dom.global_settings.requestClient(global)`). It is TAKEN on every path:
//!   freed when the dispatch is rejected or fails to start.
//! - `send` returns true when the fetch started. Its response is ignored
//!   ("User agents must ignore any entity bodies returned in the
//!   responses"). An error (out of memory) means nothing was sent.
//! - `start` is the same, with an `Observer` and a handle: the observer
//!   hears the response's status and the dispatch's end, and the handle
//!   can `cancel` the fetch until the end is heard. Hyperlink auditing
//!   cancels its pings when their document is aborted; Reporting reads
//!   its endpoint's status.
//!
//! ## Lifetime
//!
//! A dispatch holds nothing it does not own or cannot check: its request
//! is the fetch's (`AsyncFetch` owns it), and its realm is a
//! `runtime.Context`, which stays a valid, inert record after the realm
//! retires until its agent ends (engine_protocol.zig's Context contract;
//! context_manager retires entries rather than freeing them). It never
//! reaches the global or its document: "abort a document"
//! (dom.document_fetches) does not cancel it, which is keepalive's purpose,
//! and the document and its global may be freed while it is in flight. Like
//! `fetch({keepalive: true})` and Codex row 12's reporting uploads it is
//! still terminated when its realm retires (`alive`): the request's client
//! fields - its CSP violation and resource timing reporters - name the
//! global unguarded, and termination at the next sweep keeps the network
//! from reaching them after it goes. Surviving that needs an agent-level
//! owner and guarded client fields; retaining a dead global would not
//! provide one.
//!
//! Spec: https://fetch.spec.whatwg.org/#request-keepalive-flag
//! Spec: https://w3c.github.io/beacon/#sec-processing-model

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");

const AsyncFetch = fetch.algorithms.AsyncFetch;
pub const Error = fetch.algorithms.FetchError;

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
    observer: ?Observer = null,
};

/// One request in flight. Frees itself; see the module comment.
pub const Dispatch = struct {
    allocator: std.mem.Allocator,
    /// The realm of the global that started it. A page that ends retires
    /// its context - `engine_ctx` becomes null - and the fetch is
    /// terminated with it.
    ctx: runtime.Context,
    observer: ?Observer = null,
    /// The fetch, until it ends (`finished`, `gone`) or is canceled.
    active: ?*AsyncFetch = null,

    /// End the fetch now: its transfer is cancelled and the dispatch is
    /// freed. The observer hears nothing more, `ended` included.
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
        self.allocator.destroy(self);
    }
};

/// Start fetching `request` for `global`, ignoring its response. Takes
/// `request` on every path. Null means rejected: nothing was sent.
pub fn start(global: *runtime.Instance, request: *fetch.internal.InternalRequest, options: Options) Error!?*Dispatch {
    const allocator = global.ctx.allocator;
    var owns_request = true;
    defer if (owns_request) request.deinit();
    const self = try allocator.create(Dispatch);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .ctx = global.ctx, .observer = options.observer };
    // The fetch owns the request from here, and frees it if it fails.
    owns_request = false;
    self.active = try AsyncFetch.start(allocator, request, .{}, fetch.network.scheduler.threadScheduler(), self.client());
    return self;
}

/// `start` without a handle: true when the request was accepted and its
/// fetch started.
pub fn send(global: *runtime.Instance, request: *fetch.internal.InternalRequest, options: Options) Error!bool {
    return (try start(global, request, options)) != null;
}
