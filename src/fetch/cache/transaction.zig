//! One HTTP-network-or-cache fetch's use of the HTTP cache (Fetch 4.6): the
//! lookup before the network (steps 24-26), and after it the invalidation,
//! the 304 and the store (steps 11.3-11.5). Chromium's name for it:
//! HttpCache::Transaction.
//!
//! `begin` runs where step 26 does - after steps 8.11-8.21 have made
//! httpRequest's header list, which a Vary-nominated field may be in (Origin,
//! Cookie, User-Agent...) - and says what happens next: the stored response
//! is the response, the network is asked (with the validators to send, when
//! revalidating), or only-if-cached found nothing. `afterNetwork` takes the
//! network's response.
//!
//! A response whose body is still arriving is stored when its body has
//! ended (Blink and Gecko store at the end too): a `Writer` observes the
//! body's PipeSource - each chunk, then the end - and publishes the stored
//! response once the body finished; a failure, an abort or every reader
//! leaving drops it. It is no reader of the body, so it never holds the
//! network back or keeps it going.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-network-or-cache-fetch
//!       https://www.rfc-editor.org/rfc/rfc9111 (sections cited per step)

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const CacheMode = internal_request.CacheMode;
const internal_response = @import("../internal/response.zig");
const InternalResponse = internal_response.InternalResponse;
const Body = @import("../internal/body.zig").Body;
const body_pipe = @import("../internal/body_pipe.zig");
const http_cache = @import("http_cache.zig");
const HttpCache = http_cache.HttpCache;
const stored_response = @import("stored_response.zig");
const StoredResponse = stored_response.StoredResponse;
const HeaderView = @import("header_view.zig").HeaderView;
const Directives = @import("cache_control.zig").Directives;
const freshness = @import("freshness.zig");

pub const Transaction = struct {
    /// The request's Browser's cache. BORROWED: the network context it is on
    /// outlives every fetch of the Browser.
    cache: *HttpCache,
    /// The key. BORROWED from the request, which outlives the transaction.
    partition: []const u8,
    url: []const u8,
    method: Method,
    /// The cache mode after steps 8.16 and 25.
    mode: CacheMode,
    /// Step 5's storedResponse, while the network decides about it (one
    /// reference). Null when there is none.
    stored: ?*StoredResponse = null,
    /// Step 7's revalidatingFlag.
    revalidating: bool = false,
    /// RFC 9111 4.2.3's request_time.
    request_time: i64,

    pub const Method = enum { get, other_safe, unsafe };

    pub const Begin = union(enum) {
        /// The cache has nothing to do with this request: no cache, no
        /// network partition key (step 25: "no-store"), cache mode
        /// "no-store", a request directive no-store, a range request, or a
        /// safe method other than GET.
        bypass,
        /// Step 26.2.2.3 (or 26.2.2.2's otherwise): the stored response is
        /// the response, its cache state "local". OWNED.
        response: *InternalResponse,
        /// Step 11.1: only-if-cached and no usable stored response.
        network_error,
        /// Step 11: to the network, then `afterNetwork`. The validators to
        /// send, if any, are BORROWED from the transaction's stored
        /// response, which it holds until `deinit`.
        network: Network,
    };

    pub const Network = struct {
        transaction: Transaction,
        if_none_match: ?[]const u8 = null,
        if_modified_since: ?[]const u8 = null,
    };

    /// Steps 24-26 for `request`, whose httpRequest header list is
    /// `headers`, at `now` (seconds since the epoch).
    pub fn begin(allocator: Allocator, request: *const InternalRequest, headers: HeaderView, now: i64) Allocator.Error!Begin {
        // 24-25: the HTTP cache partition of the request's network partition
        // key; none - no cache, or no key - is "no-store" (and 11.3 has no
        // cache to invalidate). A request without a key never shares a
        // partition (docs/lessons/architecture-a-missing-partition-key-is-
        // not-a-shared-cache-partition.md).
        const network = request.network orelse return .bypass;
        const cache = network.http_cache orelse return .bypass;
        const partition = request.network_partition_key orelse return .bypass;
        const method = methodOf(request.method);
        var transaction: Transaction = .{
            .cache = cache,
            .partition = partition,
            .url = http_cache.keyUrl(request.currentUrl()),
            .method = method,
            .mode = effectiveMode(request),
            .request_time = now,
        };
        // What this cache never answers, only-if-cached included: then there
        // is no stored response to use - a network error (11.1) - rather
        // than the network.
        const unanswerable: Begin = if (transaction.mode == .only_if_cached) .network_error else .bypass;
        switch (method) {
            // RFC 9111 4: "A cache MUST write through requests with methods
            // that are unsafe" - and invalidate after (11.3).
            .unsafe => return .{ .network = .{ .transaction = transaction } },
            // Only GET is stored or looked up: Chromium and Gecko key GET.
            // A stored GET answering HEAD (RFC 9111 4.3.5's freshening by
            // HEAD too) is not done here.
            .other_safe => return unanswerable,
            .get => {},
        }
        // Partial content is neither stored nor served (stated: RFC 9111
        // 3.3-3.4 are not implemented, and Fetch 4.6's note says it "is not
        // widely supported by browser caches").
        if (headers.contains("Range")) return unanswerable;
        const directives = requestDirectives(headers);
        // "no-store": "Fetch behaves as if there is no HTTP cache at all".
        if (transaction.mode == .no_store) return .bypass;
        // A request no-store directive likewise (RFC 9111 5.2.1.5): Firefox
        // 158 and Safari 27 pass fetch/http-cache/cc-request.any.html
        // "doesn't reuse fresh response when request contains
        // Cache-Control: no-store", Chrome 155 fails it (wpt.fyi 23b0b89b1a)
        // - the majority (golden rule 2).
        if (directives.no_store) return unanswerable;
        // 26: "If httpRequest's cache mode is neither "no-store" nor
        // "reload"" - reload goes to the network and stores (11.5).
        if (transaction.mode == .reload) return .{ .network = .{ .transaction = transaction } };

        // 26.1: select a stored response, possibly needing validation.
        const stored = cache.lookup(partition, transaction.url) orelse {
            if (transaction.mode == .only_if_cached) return .network_error;
            return .{ .network = .{ .transaction = transaction } };
        };
        // RFC 9111 4.1: a stored response whose Vary fields do not match
        // needs validation in every mode, and only its ETag can vouch for it
        // - a date cannot speak for another variant. Chromium's
        // HttpCache::Transaction::RequiresValidation (vary_mismatch_ ->
        // VALIDATION_SYNCHRONOUS, ahead of LOAD_SKIP_CACHE_VALIDATION) and
        // ConditionalizeRequest ("Can't rely on last-modified if vary is
        // different"). only-if-cached cannot validate: a network error.
        if (!stored.varyMatches(headers)) {
            if (transaction.mode == .only_if_cached) {
                stored.release();
                return .network_error;
            }
            const etag = stored.header("ETag") orelse {
                stored.release();
                return .{ .network = .{ .transaction = transaction } };
            };
            transaction.stored = stored;
            transaction.revalidating = true;
            return .{ .network = .{ .transaction = transaction, .if_none_match = etag } };
        }
        // 26.2.2.1: "If storedResponse is a stale response, then set the
        // revalidatingFlag" - stale, or not to be reused without validation.
        if (needsValidation(stored, directives, transaction.mode, now)) {
            // 26.2.2.2: unless the mode is force-cache or only-if-cached,
            // which use it as it is ("not paying attention to staleness").
            if (transaction.mode != .force_cache and transaction.mode != .only_if_cached) {
                transaction.stored = stored;
                transaction.revalidating = true;
                // RFC 9111 4.3.1: the entity tag (MUST) and the
                // Last-Modified value (SHOULD) of the response validated.
                return .{ .network = .{
                    .transaction = transaction,
                    .if_none_match = stored.header("ETag"),
                    .if_modified_since = stored.header("Last-Modified"),
                } };
            }
        }
        // 26.2.2.3: "set response to storedResponse and set response's cache
        // state to "local"".
        defer stored.release();
        return .{ .response = try responseOf(allocator, stored, request, .local) };
    }

    /// Steps 11.3-11.5 for `response`, HTTP-network fetch's forwardResponse
    /// (taken) to the request sent with `sent`'s header list, received at
    /// `now`: the response HTTP-network-or-cache fetch goes on with.
    pub fn afterNetwork(self: *Transaction, allocator: Allocator, request: *const InternalRequest, sent: HeaderView, response: *InternalResponse, now: i64) Allocator.Error!*InternalResponse {
        const network_error = response.response_type == .@"error" or response.status == 0;
        // 11.3: "If httpRequest's method is unsafe and forwardResponse's
        // status is in the range 200 to 399, inclusive, invalidate
        // appropriate stored responses in httpCache ... and set
        // storedResponse to null." RFC 9111 4.4 MUSTs the target URI; the
        // Location and Content-Location URIs it MAYs are not invalidated:
        // Chrome 155 and Safari 27 fail all of fetch/http-cache/
        // invalidate.any.html's Location and Content-Location cases, Firefox
        // 158 passes them (wpt.fyi 23b0b89b1a) - the majority (golden rule
        // 2; RFC 9111 made them MAY from 7234's MUST). An unknown method is
        // unsafe (Firefox and Safari invalidate for one; Chrome does not).
        if (self.method == .unsafe) {
            if (!network_error and response.status >= 200 and response.status <= 399) {
                self.cache.invalidate(self.partition, self.url);
            }
            self.dropStored();
            return response;
        }
        if (self.method != .get or network_error) return response;

        // 11.4: "If the revalidatingFlag is set and forwardResponse's status
        // is 304": the stored response's header list updated from the 304's
        // (RFC 9111 4.3.4, 3.2) - in the cache too - and it is the response,
        // its cache state "validated".
        if (self.revalidating and response.status == 304) {
            if (self.stored) |stored| {
                if (validatorsAgree(stored, response)) {
                    const updated = try stored.freshened(self.cache.allocator, response.header_list.iterator(), self.request_time, now);
                    defer updated.release();
                    updated.retain();
                    self.cache.replace(stored, updated);
                    const validated = try responseOf(allocator, updated, request, .validated);
                    // The 304's body is nobody's: its pipe goes with it.
                    response.deinit();
                    self.dropStored();
                    return validated;
                }
                // A 304 whose validator disagrees with the stored one does
                // not update it (RFC 9111 4.3.4's first two filters); Gecko
                // (nsHttpChannel::ProcessNotModified) dooms such an entry.
                self.cache.invalidate(self.partition, self.url);
            }
        }
        self.dropStored();

        // 11.5: "Store httpRequest and forwardResponse in httpCache, as per
        // the "Storing Responses in Caches" chapter of HTTP Caching."
        if (self.mode == .no_store or self.mode == .only_if_cached) return response;
        const headers = response.header_list.iterator();
        if (!storable(response.status, headers)) return response;
        try self.store(sent, response, now);
        return response;
    }

    /// The reference the transaction still holds, if any, goes.
    pub fn deinit(self: *Transaction) void {
        self.dropStored();
    }

    fn dropStored(self: *Transaction) void {
        if (self.stored) |s| s.release();
        self.stored = null;
    }

    /// Store `response` now if its body is all there - or nobody will read
    /// it (a redirect HTTP fetch follows) - or once it has ended.
    fn store(self: *Transaction, sent: HeaderView, response: *InternalResponse, now: i64) Allocator.Error!void {
        const cache = self.cache;
        const limit = cache.maxEntryBytes();
        if (declaredLength(response)) |length| if (length > limit) return;
        const coding = filteredContentCoding(response.header_list.iterator());
        // A redirect with a Location: HTTP fetch follows it or hands on a
        // filtered response with no body (opaque-redirect; a navigation
        // reads its location only), so its body is never read - stored now
        // without one, as Chromium ends the cache entry of a redirect it
        // follows without reading the body.
        const redirect = isRedirectStatus(response.status) and response.header_list.contains("Location");
        const pipe: ?*body_pipe.BodyPipe = if (response.body) |b| b.pipe else null;
        // A pipe that is no longer open at the head failed or was cancelled:
        // there is no whole body to store.
        if (!redirect and pipe != null and pipe.?.state != .open) return;
        const arriving = pipe != null and !redirect;
        const bytes: []const u8 = if (redirect or arriving) "" else if (response.body) |b| b.getBytes() else "";
        if (bytes.len > limit) return;
        const entry = try StoredResponse.create(cache.allocator, .{
            .partition = self.partition,
            .url = self.url,
            .status = response.status,
            .status_message = response.status_message,
            .headers = response.header_list.iterator(),
            .body = bytes,
            .body_info = .{ .encoded_size = bytes.len, .decoded_size = bytes.len, .content_encoding = coding },
            .request = sent,
            .request_time = self.request_time,
            .response_time = now,
        });
        if (!arriving) return cache.publish(entry);
        Writer.attach(cache, entry, pipe.?.source, limit, coding) catch {
            entry.release();
        };
    }
};

/// The cache's clock: RFC 9111's "now", seconds since the epoch - the wall
/// clock, which a response's Date and Expires are read against.
pub fn clockNow() i64 {
    return @import("platform").wallSeconds();
}

/// Writes a body still arriving into its stored response, and publishes it
/// once the body finished (Chromium: HttpCache::Writers). It observes the
/// body's PipeSource without being one of its readers.
pub const Writer = struct {
    cache: *HttpCache,
    entry: *StoredResponse,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    limit: usize,
    content_encoding: []const u8,
    /// The body grew past the entry cap, or a copy failed: nothing is
    /// stored.
    abandoned: bool = false,

    /// Observe `source` for `entry` (its reference taken on success).
    pub fn attach(cache: *HttpCache, entry: *StoredResponse, source: *body_pipe.PipeSource, limit: usize, content_encoding: []const u8) Allocator.Error!void {
        std.debug.assert(source.observer == null);
        const self = try cache.allocator.create(Writer);
        cache.retain();
        self.* = .{ .cache = cache, .entry = entry, .limit = limit, .content_encoding = content_encoding };
        source.observer = .{ .context = self, .data = data, .end = end };
    }

    fn data(context: *anyopaque, chunk: []const u8) void {
        const self: *Writer = @ptrCast(@alignCast(context));
        if (self.abandoned) return;
        if (self.bytes.items.len + chunk.len > self.limit) return self.abandon();
        self.bytes.appendSlice(self.cache.allocator, chunk) catch self.abandon();
    }

    fn abandon(self: *Writer) void {
        self.abandoned = true;
        self.bytes.clearAndFree(self.cache.allocator);
    }

    fn end(context: *anyopaque, complete: bool) void {
        const self: *Writer = @ptrCast(@alignCast(context));
        const cache = self.cache;
        defer {
            cache.allocator.destroy(self);
            cache.release();
        }
        if (!complete or self.abandoned) {
            self.bytes.deinit(cache.allocator);
            return self.entry.release();
        }
        const length = self.bytes.items.len;
        const owned = self.bytes.toOwnedSlice(cache.allocator) catch {
            self.bytes.deinit(cache.allocator);
            return self.entry.release();
        };
        self.entry.setBody(owned, .{ .encoded_size = length, .decoded_size = length, .content_encoding = self.content_encoding }) catch {
            return self.entry.release();
        };
        cache.publish(self.entry);
    }
};

/// Fetch 4.6 steps 8.16 and 25's cache mode, as httpRequest has it.
fn effectiveMode(request: *const InternalRequest) CacheMode {
    // 8.16: a "default" request the author made conditional is "no-store".
    if (request.cache_mode == .default) {
        for ([_][]const u8{ "If-Modified-Since", "If-None-Match", "If-Unmodified-Since", "If-Match", "If-Range" }) |name| {
            if (request.header_list.contains(name)) return .no_store;
        }
    }
    return request.cache_mode;
}

fn methodOf(method: []const u8) Transaction.Method {
    if (std.mem.eql(u8, method, "GET")) return .get;
    // RFC 9110 9.2.1's safe methods; anything else - unknown ones included
    // - is unsafe (RFC 9111 4.4: "including methods whose safety is
    // unknown").
    for ([_][]const u8{ "HEAD", "OPTIONS", "TRACE" }) |safe| {
        if (std.mem.eql(u8, method, safe)) return .other_safe;
    }
    return .unsafe;
}

/// The request's Cache-Control directives (RFC 9111 5.2.1) - the author's
/// and the `max-age=0` Fetch's "no-cache" mode appends (step 8.17). With no
/// Cache-Control, `Pragma: no-cache` is read as no-cache (RFC 7234 5.4; RFC
/// 9111 5.4 deprecates Pragma without a rule of its own).
fn requestDirectives(headers: HeaderView) Directives {
    var directives: Directives = .{};
    var lines = headers.iterate("Cache-Control");
    var any = false;
    while (lines.next()) |line| {
        directives.add(line);
        any = true;
    }
    if (!any) {
        var pragmas = headers.iterate("Pragma");
        while (pragmas.next()) |pragma| {
            var tokens = std.mem.splitScalar(u8, pragma, ',');
            while (tokens.next()) |token| {
                if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, token, " \t"), "no-cache")) directives.no_cache = true;
            }
        }
    }
    return directives;
}

/// Whether `stored` may not answer without validation (RFC 9111 4): stale
/// (4.2), or a no-cache response directive (5.2.2.4), or a request whose
/// directives refuse it (5.2.1): no-cache, a max-age it is older than, a
/// min-fresh it cannot meet - a max-stale may accept a stale one, unless
/// must-revalidate or no-cache forbid serving it stale (4.2.4). These
/// request directives are honoured as Firefox 158 and Safari 27 do: both
/// pass every case of fetch/http-cache/cc-request.any.html but the 504 one,
/// Chrome 155 fails max-age=1, max-stale and min-fresh (wpt.fyi
/// 23b0b89b1a) - the majority (golden rule 2).
fn needsValidation(stored: *const StoredResponse, request: Directives, mode: CacheMode, now: i64) bool {
    const response = stored.facts.directives;
    if (response.no_cache or request.no_cache or mode == .no_cache) return true;
    const lifetime = stored.lifetime();
    const age = stored.currentAge(now);
    switch (request.max_age) {
        // "max-age=0" always validates: the RFC's "age less than or equal to
        // 0" would let a response stored this very second (ages are whole
        // seconds) through, but Fetch's "no-cache" mode is that header
        // (step 8.17) and promises a conditional request whenever a response
        // is stored; Chromium's kForceValidateHeaders likewise always
        // validates on it (net/http/http_cache_util.cc: LOAD_VALIDATE_CACHE).
        .value => |max| if (max == 0 or age > max) return true,
        // An unreadable max-age asks for the strictest.
        .invalid => return true,
        .absent => {},
    }
    switch (request.min_fresh) {
        .value => |min| if (lifetime < age +| min) return true,
        .invalid, .absent => {},
    }
    if (lifetime > age) return false;
    // Stale: acceptable only if the client said so and the origin allows.
    if (response.must_revalidate) return true;
    const max_stale = request.max_stale orelse return true;
    return switch (max_stale) {
        .any => false,
        .seconds => |seconds| age - lifetime > seconds,
    };
}

/// RFC 9111 3: whether a response with `status` and `headers` (to a GET,
/// whose request did not say no-store) may be stored.
fn storable(status: u16, headers: []const stored_response.Header) bool {
    // "the response status code is final" - and not 206 or 304, which this
    // cache does not understand (no partial content; a 304 only updates).
    if (status < 200 or status == 206 or status == 304) return false;
    const facts = freshness.Facts.fromHeaders(status, headers);
    const d = facts.directives;
    // "the no-store cache directive is not present in the response" - which
    // must-understand overrides for a status the cache understands
    // (5.2.2.3).
    if (d.no_store and !d.must_understand) return false;
    // "the response contains at least one of": public, private (this cache
    // is not shared), Expires, max-age, or a heuristically cacheable status.
    return d.public or d.private or facts.hasExplicitFreshness() or freshness.heuristicallyCacheable(status);
}

/// RFC 9111 4.3.4: whether a 304 may update `stored`. A validator the 304
/// carries must match the stored one - its ETag by the weak comparison
/// (RFC 9110 8.8.3.2: a strong validator matches only itself, a weak one
/// its opaque tag), its Last-Modified exactly; one it lacks says nothing.
/// Chromium updates the stored response on every 304 to its own validation
/// request; Gecko (nsHttpChannel::ProcessNotModified) refuses one whose
/// validators disagree - a 304 without them, as cors/304.htm's server sends,
/// updates in both.
fn validatorsAgree(stored: *const StoredResponse, response: *const InternalResponse) bool {
    if (response.header_list.getFirstValue("ETag")) |etag| {
        const own = stored.header("ETag") orelse return false;
        if (!std.mem.eql(u8, opaqueTag(etag), opaqueTag(own))) return false;
    }
    if (response.header_list.getFirstValue("Last-Modified")) |modified| {
        const own = stored.header("Last-Modified") orelse return false;
        if (!std.mem.eql(u8, std.mem.trim(u8, modified, " \t"), std.mem.trim(u8, own, " \t"))) return false;
    }
    return true;
}

fn opaqueTag(etag: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, etag, " \t");
    return if (std.mem.startsWith(u8, trimmed, "W/")) trimmed[2..] else trimmed;
}

fn isRedirectStatus(status: u16) bool {
    return switch (status) {
        301, 302, 303, 307, 308 => true,
        else => false,
    };
}

/// The Content-Length a response declares, when it declares one.
fn declaredLength(response: *const InternalResponse) ?u64 {
    const value = response.header_list.getFirstValue("Content-Length") orelse return null;
    return std.fmt.parseInt(u64, std.mem.trim(u8, value, " \t"), 10) catch null;
}

/// HTTP-network fetch's body steps 1.2-1.6 filtered coding (as
/// http_fetch.filteredContentCoding): a static string.
fn filteredContentCoding(headers: []const stored_response.Header) []const u8 {
    var codings: usize = 0;
    var first: []const u8 = "";
    for (headers) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "Content-Encoding")) continue;
        var values = std.mem.splitScalar(u8, header.value, ',');
        while (values.next()) |raw| {
            if (codings == 0) first = std.mem.trim(u8, raw, " \t");
            codings += 1;
        }
    }
    if (codings == 0) return "";
    if (codings > 1) return "multiple";
    if (first.len == 0) return "";
    for ([_][]const u8{ "gzip", "deflate", "br", "zstd" }) |coding| {
        if (std.ascii.eqlIgnoreCase(first, coding)) return coding;
    }
    return "@unknown";
}

/// A response made from `stored` for `request` - its URL the request's
/// current URL (step 12: httpRequest's URL list), its status, headers and
/// body the stored response's, its body info the one stored alongside it
/// (11.5.2's note), its cache state `state`. OWNED by the caller.
fn responseOf(allocator: Allocator, stored: *const StoredResponse, request: *const InternalRequest, state: internal_response.CacheState) Allocator.Error!*InternalResponse {
    const response = try InternalResponse.init(allocator);
    errdefer response.deinit();
    try response.addUrl(request.currentUrl());
    response.status = stored.status;
    if (stored.status_message.len > 0) try response.setStatusMessage(stored.status_message);
    for (stored.headers) |h| try response.header_list.append(h.name, h.value);
    // The body's source is its own bytes, never the stored response's: the
    // stored response may go before the body does.
    const body = try Body.fromBytes(allocator, stored.body.bytes);
    body.source = .{ .bytes = body.data.items };
    response.body = body;
    response.body_info.encoded_size = stored.body_info.encoded_size;
    response.body_info.decoded_size = stored.body_info.decoded_size;
    response.body_info.content_encoding = stored.body_info.content_encoding;
    response.cache_state = state;
    return response;
}
