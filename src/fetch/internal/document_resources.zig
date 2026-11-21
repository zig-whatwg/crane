//! A Window's document's resources, as fetch reaches them: HTML's map of
//! preloaded resources - Fetch step 11 "consume a preloaded resource" - and
//! the document's reuse of a resource it loaded while it is still loading.
//!
//! The maps are the document's (dom.document_resources); fetch sees an
//! `Entry` per resource, shared between the map and every fetch that serves
//! or is served by it, and a `Route` on the request ("populate request from
//! client" sets it for a Window client) that the fetch asks once, at its
//! start (Fetch step 11): never later, when its client may be gone.
//!
//! - A preload's fetch (HTML "preload") puts a new entry in the preload map
//!   and fulfils it with its response once the whole body is in (its
//!   processResponseConsumeBody); a later fetch with the same preload key
//!   takes it out of the map and is answered with that response - now, or
//!   once it arrives ("on response available") - without a fetch of its own
//!   (main fetch step 12's preloaded response candidate).
//! - Every other subresource fetch of a loading document that reads its
//!   whole body (a style sheet, an @import, a classic script, an image)
//!   leaves its response in the document's loaded map, where a later fetch
//!   of the same URL, destination, mode and credentials mode reuses it while
//!   the document loads. No spec has this; all three browsers do it - Chrome
//!   (core/loader resource_fetcher.cc: DetermineRevalidationPolicyInternal
//!   returns kUse for a non-raw resource of the document's
//!   cached_resources_map_ while !IsLoadComplete(), or for one still
//!   loading), Firefox (layout/style/Loader.cpp: a document's style sheets
//!   of one URL share a load and its sheet - SharedStyleSheetCache) and
//!   Safari (loader/cache/CachedResourceLoader.cpp: the document's
//!   m_documentResources reused by determineRevalidationPolicy) - so golden
//!   rule 2 decides.
//!
//! A fetch served from an entry reports no Resource Timing entry of its
//! own: the resource has one, its first fetch's (Chrome reports a memory
//! cache hit only for a resource not yet in the document's map -
//! ResourceFetcher::DidLoadResourceFromMemoryCache - and Firefox and Safari
//! report a consumed preload once: preload/single-download-preload.html).
//!
//! Single-threaded: a document's fetches all run on its event loop's thread.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#map-of-preloaded-resources
//! Spec: https://fetch.spec.whatwg.org/#concept-fetch (step 11)
//! Spec: https://fetch.spec.whatwg.org/#concept-main-fetch (step 12)

const std = @import("std");
const Allocator = std.mem.Allocator;
const InternalRequest = @import("request.zig").InternalRequest;
const InternalResponse = @import("response.zig").InternalResponse;

/// One resource of a document: a preload entry (HTML) or a loaded one.
/// Counted: the document's map holds a reference, and so does each fetch
/// that fulfils it or waits on it.
pub const Entry = struct {
    allocator: Allocator,
    refs: u32 = 1,
    state: State = .pending,
    /// The response, once `done`: what the fetch that fetched it handed to
    /// its client, with its whole body. OWNED; each fetch it serves gets a
    /// clone.
    response: ?*InternalResponse = null,
    /// A preload's entry (HTML "preload"), not a loaded resource's.
    preload: bool,
    /// The preload is consumed by a render-blocking fetch while it is still
    /// in flight: its Resource Timing entry reports "blocking" (Chrome's
    /// ResourceFetcher::MakePreloadedResourceBlockIfNeeded upgrades the
    /// preload's pending timing info; Chrome alone ships renderBlockingStatus:
    /// resource-timing/render-blocking-status-link.html
    /// "link-style-preload-used-immediately").
    upgrade_render_blocking: bool = false,

    pub const State = enum {
        /// Its fetch is still under way: "on response available" waits.
        pending,
        /// The response is in.
        done,
        /// Its fetch ended with a network error: HTML stores those too, so
        /// that a failed preload is not fetched again.
        failed,
        /// Its fetch went with no response - terminated, its client gone (a
        /// link removed while its sheet loads): a fetch it was to serve
        /// fetches the resource itself, as a browser's load of a resource
        /// that is no longer in its memory cache does.
        abandoned,
    };

    pub fn create(allocator: Allocator, preload: bool) Allocator.Error!*Entry {
        const self = try allocator.create(Entry);
        self.* = .{ .allocator = allocator, .preload = preload };
        return self;
    }

    pub fn retain(self: *Entry) *Entry {
        self.refs += 1;
        return self;
    }

    pub fn release(self: *Entry) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        if (self.response) |response| response.deinit();
        self.allocator.destroy(self);
    }

    /// The fetch that fetched it has its response, with its whole body:
    /// `response` is taken. A response that is a network error fails it.
    pub fn fulfill(self: *Entry, response: *InternalResponse) void {
        if (self.state != .pending or response.response_type == .@"error") {
            response.deinit();
            if (self.state == .pending) self.state = .failed;
            return;
        }
        self.response = response;
        self.state = .done;
    }

    /// Its fetch went with no response to keep.
    pub fn abandon(self: *Entry) void {
        if (self.state == .pending) self.state = .abandoned;
    }

    /// Whether the response may serve a later fetch as a loaded resource:
    /// a response its server forbade keeping (`Cache-Control: no-store`) is
    /// fetched again (Chrome: DetermineRevalidationPolicyInternal reloads a
    /// resource with HasCacheControlNoStoreHeader).
    pub fn reusable(self: *const Entry) bool {
        return switch (self.state) {
            .pending => true,
            .failed, .abandoned => false,
            .done => !hasNoStore(self.response.?),
        };
    }

    /// The response a fetch it serves gets, once it is no longer pending:
    /// a clone of the response, or a network error. OWNED by the caller.
    pub fn responseFor(self: *const Entry, allocator: Allocator) !*InternalResponse {
        if (self.state == .done) return self.response.?.clone();
        return @import("response.zig").networkError(allocator);
    }
};

fn hasNoStore(response: *const InternalResponse) bool {
    const internal = response.internal orelse response;
    for (internal.header_list.entries.items) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "cache-control")) continue;
        var directives = std.mem.tokenizeAny(u8, header.value, ", \t");
        while (directives.next()) |directive| {
            if (std.ascii.eqlIgnoreCase(directive, "no-store")) return true;
        }
    }
    return false;
}

/// How a request reaches its Window client's document's resources.
/// BORROWED, and asked only at the fetch's start: the document is its
/// client's, alive then.
pub const Route = struct {
    context: *anyopaque,
    /// Fetch step 11 (and the document's reuse): the entry whose response
    /// answers `request` - a preload of its preload key, which leaves the
    /// preload map, or a resource the loading document loaded - retained for
    /// the caller. Null: the request is fetched.
    consume: *const fn (context: *anyopaque, request: *const InternalRequest) ?*Entry,
    /// A new pending entry for `request`'s response, which the document
    /// keeps - a preload's in its preload map (HTML "preload" step 12's
    /// commit), another subresource's while the document loads - retained
    /// for the caller, who fulfils it. Null: the document keeps nothing of
    /// it.
    register: *const fn (context: *anyopaque, request: *const InternalRequest) ?*Entry,
};

/// Fetch step 11's conditions: an HTTP(S) URL, a request mode of
/// "same-origin", "cors" or "no-cors", a GET, and the unsafe-request flag not
/// set or no headers. (Its client being a Window is the route's being set.)
pub fn step11Applies(request: *const InternalRequest) bool {
    const url = request.currentUrl();
    if (!std.ascii.startsWithIgnoreCase(url, "http:") and !std.ascii.startsWithIgnoreCase(url, "https:")) return false;
    switch (request.mode) {
        .same_origin, .cors, .no_cors => {},
        else => return false,
    }
    if (!std.mem.eql(u8, request.method, "GET")) return false;
    if (request.unsafe_request and request.header_list.entries.items.len != 0) return false;
    return true;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "an entry is fulfilled once, serves clones, and a network error or no-store response does not serve a reuse" {
    const entry = try Entry.create(testing.allocator, false);
    defer entry.release();
    try testing.expect(entry.reusable());
    const response = try InternalResponse.init(testing.allocator);
    response.status = 200;
    entry.fulfill(response);
    try testing.expectEqual(Entry.State.done, entry.state);
    try testing.expect(entry.reusable());
    const a = try entry.responseFor(testing.allocator);
    defer a.deinit();
    const b = try entry.responseFor(testing.allocator);
    defer b.deinit();
    try testing.expect(a != b);
    try testing.expectEqual(@as(u16, 200), a.status);

    const failed = try Entry.create(testing.allocator, true);
    defer failed.release();
    failed.fulfill(try @import("response.zig").networkError(testing.allocator));
    try testing.expectEqual(Entry.State.failed, failed.state);
    try testing.expect(!failed.reusable());
    const err = try failed.responseFor(testing.allocator);
    defer err.deinit();
    try testing.expect(err.response_type == .@"error");

    const gone = try Entry.create(testing.allocator, false);
    defer gone.release();
    gone.abandon();
    try testing.expect(!gone.reusable());

    const no_store = try Entry.create(testing.allocator, false);
    defer no_store.release();
    const kept = try InternalResponse.init(testing.allocator);
    try kept.header_list.append("Cache-Control", "max-age=0, no-store");
    no_store.fulfill(kept);
    try testing.expect(!no_store.reusable());
}
