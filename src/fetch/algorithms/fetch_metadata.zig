//! Fetch Metadata Request Headers 3, "append the Fetch metadata headers for
//! a request" - HTTP-network-or-cache fetch step 8.13 - and the four headers
//! it sets: `Sec-Fetch-Dest`, `Sec-Fetch-Mode`, `Sec-Fetch-Site` and
//! `Sec-Fetch-User` (2.1-2.4).
//!
//! A pure function of the request's URL list, origin, mode, destination and
//! user activation (`Input`), so HTTP-network-or-cache fetch and the CORS
//! preflight - itself an HTTP-network-or-cache fetch, in mode "cors" - ask
//! the same question. The headers go on the request SENT, recomputed at
//! every hop (http_fetch.httpRequestHeaders' `added` list), never on the
//! request's own header list: a service worker's event.request and a
//! preflight's Access-Control-Request-Headers never see them, and a hop to a
//! URL that is not potentially trustworthy sends none (Chromium's
//! MaybeRemoveSecHeaders makes the same true of its redirects).
//!
//! Spec: https://w3c.github.io/webappsec-fetch-metadata/#abstract-opdef-append-the-fetch-metadata-headers-for-a-request

const std = @import("std");
const cookiestore = @import("cookiestore");
const determine_referrer = @import("referrer_policy").determine_referrer;
const internal_request = @import("../internal/request.zig");
const origins = @import("../internal/origins.zig");
const csp_check = @import("csp_check.zig");

const Allocator = std.mem.Allocator;
const InternalRequest = internal_request.InternalRequest;
pub const SiteRelation = internal_request.SiteRelation;

/// What the headers are computed from: a request's, or a preflight's (its
/// request's, in mode "cors"). Every slice BORROWED for the call.
pub const Input = struct {
    /// The URL list; its last URL is the current URL.
    url_list: []const []const u8,
    /// The request's origin; "client" - none was ever set, the embedder's
    /// own request - has no initiator.
    origin: internal_request.RequestOrigin,
    /// What URLs the request's list no longer holds made of Sec-Fetch-Site
    /// (InternalRequest.dropped_urls_site): a service worker's copy keeps
    /// only its hop's URL.
    dropped_urls_site: SiteRelation = .same_origin,
    mode: internal_request.RequestMode,
    destination: internal_request.Destination,
    user_activation: bool = false,

    /// `request`'s own.
    pub fn of(request: *const InternalRequest) Input {
        return .{
            .url_list = request.url_list.items,
            .origin = request.origin,
            .dropped_urls_site = request.dropped_urls_site,
            .mode = request.mode,
            .destination = request.destination,
            .user_activation = request.user_activation,
        };
    }
};

/// The header values to set, each a static string.
pub const Headers = struct {
    /// `Sec-Fetch-Dest`: a token.
    dest: []const u8,
    /// `Sec-Fetch-Mode`: a token.
    mode: []const u8,
    /// `Sec-Fetch-Site`: a token.
    site: []const u8,
    /// `Sec-Fetch-User`: `?1`, or null when the header is not set.
    user: ?[]const u8,
};

/// "Append the Fetch metadata headers for a request" given `input`: the
/// headers to set, or null when none are (step 1).
pub fn headersFor(allocator: Allocator, input: Input) Allocator.Error!?Headers {
    // 1. If r's current URL is not a potentially trustworthy URL, return.
    if (input.url_list.len == 0) return null;
    if (!isPotentiallyTrustworthyUrl(input.url_list[input.url_list.len - 1])) return null;
    return .{
        // 2. Set the Sec-Fetch-Dest header for r.
        .dest = destToken(input.destination),
        // 3. Set the Sec-Fetch-Mode header for r.
        .mode = modeToken(input.mode),
        // 4. Set the Sec-Fetch-Site header for r.
        .site = siteToken(try secFetchSite(allocator, input)),
        // 5. Set the Sec-Fetch-User header for r.
        .user = if (isNavigation(input.destination) and input.user_activation) "?1" else null,
    };
}

/// Sec-Fetch-Site's value: "none" (null) or a relation.
pub const Site = ?SiteRelation;

/// 2.3 "Set the Sec-Fetch-Site header": the relation of every URL of the
/// URL list to the request's origin, the least related winning - which is
/// the spec's loop (a URL not same origin makes "cross-site", one the
/// origin is same site with "same-site"; once cross-site it stays), and
/// Chromium's GetRelationOfURLChainToOrigin.
fn secFetchSite(allocator: Allocator, input: Input) Allocator.Error!Site {
    // 4. "If r is a navigation request that was explicitly caused by a
    //    user's interaction with the user agent ... set header's value to
    //    none." Crane's equivalent is a request with no initiator origin: its
    //    origin is still "client" - no client ever resolved it, as Fetch
    //    asserts cannot happen for a web request - which only the embedder's
    //    own navigation makes (Browser.navigate: the address bar). Chromium
    //    sends none exactly for a request with no initiator
    //    (GetInitiatorRelation). "none" holds through redirects (4.1).
    const origin = switch (input.origin) {
        .client => return null,
        .origin => |o| o,
    };
    // 3. Set header's value to same-origin - or what the URLs the list no
    //    longer holds made of it.
    var relation = input.dropped_urls_site;
    if (relation == .cross_site) return relation;
    var sites = cookiestore.SiteComparison.init(allocator, origin);
    defer sites.deinit();
    // 5. For each url in r's url list:
    for (input.url_list) |url| {
        relation = @fromBackingInt(@intCast(@max(@backingInt(relation), @backingInt(try relationOf(allocator, &sites, origin, url)))));
        if (relation == .cross_site) break;
    }
    return relation;
}

/// 2.3 step 5's relation of `url` to `origin`: same origin, same site
/// (HTML's schemeful "same site"), or neither. `sites` is `origin`'s
/// comparison, which caches registrable domains for the request.
fn relationOf(allocator: Allocator, sites: *cookiestore.SiteComparison, origin: []const u8, url: []const u8) Allocator.Error!SiteRelation {
    // 5.1. If url is same origin with r's origin, continue.
    if (origins.sameOrigin(allocator, url, origin) catch false) return .same_origin;
    // 5.2-5.4. cross-site, unless r's origin is same site with url's origin.
    return if (sites.matches(url) catch false) .same_site else .cross_site;
}

/// What `urls` - the hops a copy of a request whose origin is `origin`
/// drops - make of Sec-Fetch-Site, from `start` (the original's own
/// dropped hops'): `InternalRequest.dropped_urls_site` for the copy.
pub fn droppedUrlsSite(allocator: Allocator, origin: internal_request.RequestOrigin, urls: []const []const u8, start: SiteRelation) Allocator.Error!SiteRelation {
    const serialized = switch (origin) {
        .client => return start,
        .origin => |o| o,
    };
    var relation = start;
    var sites = cookiestore.SiteComparison.init(allocator, serialized);
    defer sites.deinit();
    for (urls) |url| {
        if (relation == .cross_site) break;
        relation = @fromBackingInt(@intCast(@max(@backingInt(relation), @backingInt(try relationOf(allocator, &sites, serialized, url)))));
    }
    return relation;
}

/// Secure Contexts 3.2 "Is url potentially trustworthy?": about:blank and
/// about:srcdoc, a data: URL, or a URL whose origin is potentially
/// trustworthy (https, wss, file, a loopback host, localhost).
fn isPotentiallyTrustworthyUrl(url: []const u8) bool {
    // 1. "about:blank" or "about:srcdoc".
    if (std.mem.eql(u8, url, "about:blank") or std.mem.eql(u8, url, "about:srcdoc")) return true;
    const parts = csp_check.urlParts(url);
    // 2. A data: URL.
    if (std.ascii.eqlIgnoreCase(parts.scheme, "data")) return true;
    // 3. Its origin.
    return determine_referrer.isPotentiallyTrustworthyOrigin(parts.scheme, parts.host orelse "");
}

/// A navigation request: its destination is "document", "embed", "frame",
/// "iframe" or "object".
fn isNavigation(destination: internal_request.Destination) bool {
    return switch (destination) {
        .document, .embed, .frame, .iframe, .object => true,
        else => false,
    };
}

/// 2.1 step 3: the destination, or "empty" for the empty string.
fn destToken(destination: internal_request.Destination) []const u8 {
    return switch (destination) {
        .empty => "empty",
        else => @tagName(destination),
    };
}

/// 2.2 step 3: the mode, as Fetch spells it.
fn modeToken(mode: internal_request.RequestMode) []const u8 {
    return switch (mode) {
        .same_origin => "same-origin",
        .cors => "cors",
        .no_cors => "no-cors",
        .navigate => "navigate",
        .websocket => "websocket",
    };
}

fn siteToken(site: Site) []const u8 {
    const relation = site orelse return "none";
    return switch (relation) {
        .same_origin => "same-origin",
        .same_site => "same-site",
        .cross_site => "cross-site",
    };
}

// ============================================================================
// Tests: the algorithm's table
// ============================================================================

const testing = std.testing;
const wpt = "https://web-platform.test:8443";

fn expectHeaders(input: Input, want: ?Headers) !void {
    const got = try headersFor(testing.allocator, input);
    if (want == null) return testing.expect(got == null);
    const g = got orelse return error.TestExpectedHeaders;
    const w = want.?;
    try testing.expectEqualStrings(w.dest, g.dest);
    try testing.expectEqualStrings(w.mode, g.mode);
    try testing.expectEqualStrings(w.site, g.site);
    if (w.user) |u| try testing.expectEqualStrings(u, g.user orelse return error.TestExpectedUser) else try testing.expect(g.user == null);
}

test "step 1: only a potentially trustworthy current URL gets the headers" {
    const origin: internal_request.RequestOrigin = .{ .origin = wpt };
    for ([_][]const u8{ "https://web-platform.test:8443/x", "http://127.0.0.1:8000/x", "http://localhost/x", "http://a.localhost/x", "wss://web-platform.test/x", "data:,x", "about:blank" }) |url| {
        try testing.expect(try headersFor(testing.allocator, .{ .url_list = &.{url}, .origin = origin, .mode = .cors, .destination = .empty }) != null);
    }
    for ([_][]const u8{ "http://web-platform.test:8000/x", "http://127.0.0.1.example/x", "ws://web-platform.test/x" }) |url| {
        try testing.expect(try headersFor(testing.allocator, .{ .url_list = &.{url}, .origin = origin, .mode = .cors, .destination = .empty }) == null);
    }
    // The CURRENT URL decides: a trustworthy first hop redirected to http.
    try testing.expect(try headersFor(testing.allocator, .{ .url_list = &.{ wpt ++ "/a", "http://web-platform.test:8000/b" }, .origin = origin, .mode = .cors, .destination = .empty }) == null);
}

test "Sec-Fetch-Dest and Sec-Fetch-Mode spell the destination and mode" {
    const origin: internal_request.RequestOrigin = .{ .origin = wpt };
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .no_cors, .destination = .empty }, .{ .dest = "empty", .mode = "no-cors", .site = "same-origin", .user = null });
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .same_origin, .destination = .serviceworker }, .{ .dest = "serviceworker", .mode = "same-origin", .site = "same-origin", .user = null });
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .navigate, .destination = .iframe }, .{ .dest = "iframe", .mode = "navigate", .site = "same-origin", .user = null });
    // A WebSocket's handshake request: its URL is http(s) by then.
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .websocket, .destination = .empty }, .{ .dest = "empty", .mode = "websocket", .site = "same-origin", .user = null });
}

test "Sec-Fetch-Site: the least related URL of a mixed chain wins, and it does not recover" {
    const origin: internal_request.RequestOrigin = .{ .origin = wpt };
    const same_site = "https://www1.web-platform.test:8443";
    const cross_site = "https://not-web-platform.test:8443";
    const Case = struct { urls: []const []const u8, site: []const u8 };
    for ([_]Case{
        .{ .urls = &.{wpt ++ "/a"}, .site = "same-origin" },
        .{ .urls = &.{ wpt ++ "/a", wpt ++ "/b" }, .site = "same-origin" },
        .{ .urls = &.{ wpt ++ "/a", same_site ++ "/b" }, .site = "same-site" },
        .{ .urls = &.{ same_site ++ "/a", wpt ++ "/b" }, .site = "same-site" },
        .{ .urls = &.{ wpt ++ "/a", cross_site ++ "/b", same_site ++ "/c", wpt ++ "/d" }, .site = "cross-site" },
        .{ .urls = &.{ same_site ++ "/a", cross_site ++ "/b" }, .site = "cross-site" },
        // Another scheme is another site (HTML's schemeful same site).
        .{ .urls = &.{"wss://web-platform.test:8443/a"}, .site = "cross-site" },
    }) |case| {
        const got = (try headersFor(testing.allocator, .{ .url_list = case.urls, .origin = origin, .mode = .no_cors, .destination = .image })).?;
        try testing.expectEqualStrings(case.site, got.site);
    }
    // An opaque origin is same origin and same site with nothing.
    const opaque_got = (try headersFor(testing.allocator, .{ .url_list = &.{wpt ++ "/a"}, .origin = .{ .origin = "null" }, .mode = .cors, .destination = .empty })).?;
    try testing.expectEqualStrings("cross-site", opaque_got.site);
    // No initiator origin: none, through redirects too.
    const none = (try headersFor(testing.allocator, .{ .url_list = &.{ cross_site ++ "/a", wpt ++ "/b" }, .origin = .client, .mode = .navigate, .destination = .document })).?;
    try testing.expectEqualStrings("none", none.site);
}

test "a service worker's passthrough after a cross-site redirect: the dropped hops still count" {
    // navigation-headers.https.html "same-origin with cross-site redirect and
    // passthrough service worker": the worker's copy holds only the last
    // hop, same origin with the frame's initiator; the cross-site hop before
    // it was dropped (copyRequestForWorker), and makes it cross-site.
    const origin: internal_request.RequestOrigin = .{ .origin = wpt };
    const dropped = try droppedUrlsSite(testing.allocator, origin, &.{ wpt ++ "/redirect.py", "https://not-web-platform.test:8443/redirect.py" }, .same_origin);
    try testing.expectEqual(SiteRelation.cross_site, dropped);
    try expectHeaders(.{ .url_list = &.{wpt ++ "/target"}, .origin = origin, .dropped_urls_site = dropped, .mode = .navigate, .destination = .empty }, .{ .dest = "empty", .mode = "navigate", .site = "cross-site", .user = null });
    // A same-site hop only: same-site.
    const same_site = try droppedUrlsSite(testing.allocator, origin, &.{"https://www1.web-platform.test:8443/redirect.py"}, .same_origin);
    try testing.expectEqual(SiteRelation.same_site, same_site);
    try expectHeaders(.{ .url_list = &.{wpt ++ "/target"}, .origin = origin, .dropped_urls_site = same_site, .mode = .navigate, .destination = .empty }, .{ .dest = "empty", .mode = "navigate", .site = "same-site", .user = null });
    // A copy of a copy keeps what its original carried.
    try testing.expectEqual(SiteRelation.same_site, try droppedUrlsSite(testing.allocator, origin, &.{}, .same_site));
}

test "a preflight's headers: mode cors, the request's destination and URL list" {
    const origin: internal_request.RequestOrigin = .{ .origin = wpt };
    try expectHeaders(.{ .url_list = &.{"https://not-web-platform.test:8443/api"}, .origin = origin, .mode = .cors, .destination = .script }, .{ .dest = "script", .mode = "cors", .site = "cross-site", .user = null });
}

test "Sec-Fetch-User: ?1 only for a navigation request with user activation" {
    const origin: internal_request.RequestOrigin = .{ .origin = wpt };
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .navigate, .destination = .document, .user_activation = true }, .{ .dest = "document", .mode = "navigate", .site = "same-origin", .user = "?1" });
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .navigate, .destination = .iframe, .user_activation = false }, .{ .dest = "iframe", .mode = "navigate", .site = "same-origin", .user = null });
    try expectHeaders(.{ .url_list = &.{wpt ++ "/x"}, .origin = origin, .mode = .no_cors, .destination = .image, .user_activation = true }, .{ .dest = "image", .mode = "no-cors", .site = "same-origin", .user = null });
}
