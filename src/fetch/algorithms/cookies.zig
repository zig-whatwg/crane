//! Fetch's cookie infrastructure (§3.1): "append a request `Cookie`
//! header", which HTTP-network-or-cache fetch step 8.21.1 runs, and "parse
//! and store response `Set-Cookie` headers", which HTTP-network fetch step 16
//! runs - both only when includeCredentials is true.
//!
//! The cookie store is the user agent's one jar (src/cookiestore), which a
//! request carries from its client (`InternalRequest.cookie_jar`). A request
//! with no jar is one the user agent is "configured to disable cookies for":
//! it neither sends nor stores any.
//!
//! Spec: https://fetch.spec.whatwg.org/#cookie-header

const std = @import("std");
const Allocator = std.mem.Allocator;
const cookiestore = @import("cookiestore");
const InternalRequest = @import("../internal/request.zig").InternalRequest;
const HeaderList = @import("../internal/header_list.zig").HeaderList;

/// Fetch "append a request `Cookie` header" for `request`: the value to
/// append, or null when there is nothing to send. OWNED.
pub fn requestCookieHeader(allocator: Allocator, request: *const InternalRequest) !?[]const u8 {
    // 1. If the user agent is configured to disable cookies for request,
    //    then it should return.
    const jar = request.cookie_jar orelse return null;
    const url = RequestUrl.of(request.currentUrl()) orelse return null;
    if (!cookiestore.http_integration.hasCookiesForHost(jar, url.host)) return null;
    // 2. Let sameSite be the result of determining the same-site mode for
    //    request.
    const same_site = try sameSiteMode(allocator, request);
    // 3. Let isSecure be true if request's current URL's scheme is "https".
    // 4. Let httpOnlyAllowed be true.
    // 5. Let cookies be the result of running retrieve cookies given
    //    isSecure, request's current URL's host and path, httpOnlyAllowed,
    //    and sameSite.
    // 6-7. If cookies is empty, return; otherwise serialize them.
    const value = try cookiestore.http_integration.generateCookieHeader(allocator, jar, .{
        .host = url.host,
        .path = url.path,
        .is_http = true,
        .is_secure = url.secure,
        .same_site = same_site,
    });
    if (value.len == 0) {
        allocator.free(value);
        return null;
    }
    // 8. Append (`Cookie`, value) to request's header list - the caller's.
    return value;
}

/// Fetch "parse and store response `Set-Cookie` headers" given `request`
/// and a response whose header list is `headers`.
pub fn storeResponseCookies(allocator: Allocator, request: *const InternalRequest, headers: *const HeaderList) !void {
    // 1. If the user agent is configured to disable cookies for request,
    //    then it should return.
    const jar = request.cookie_jar orelse return;
    const url = RequestUrl.of(request.currentUrl()) orelse return;
    // No cookie to store: avoid a site/PSL comparison on ordinary responses.
    if (!headers.contains("Set-Cookie")) return;
    // 2. allowNonHostOnlyCookieForPublicSuffix is false.
    // 3. isSecure: request's current URL's scheme is "https".
    // 4. httpOnlyAllowed is true.
    // RFC 6265bis 5.7 step 18.3: a top-level navigation's response may
    // create every SameSite kind even when its request could not send it.
    // Chromium ComputeSameSiteContextForResponse does the same (Q6).
    const top_level = isTopLevelNavigation(request);
    const options: cookiestore.StoreOptions = .{
        .is_secure = url.secure,
        .host = url.host,
        .http_only_allowed = true,
        .same_site_strict_or_lax_allowed = top_level or try sameSiteMode(allocator, request) == .strict_or_less,
    };
    // 6. For each header of response's header list whose name is
    //    `Set-Cookie` (each processed on its own - they never combine):
    //    6.2. parse and store a cookie given its value, isSecure, and
    //         request's current URL's host and path;
    //    6.3. garbage collect cookies for the host - the jar does, as it
    //         stores.
    for (headers.iterator()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "Set-Cookie")) continue;
        _ = try cookiestore.http_integration.parseAndStoreCookie(allocator, jar, header.value, url.path, options);
    }
}

/// A top-level navigation request, for SameSite cookies: mode "navigate"
/// and destination "document" (Fetch "determine the same-site mode" step 3),
/// or a Request constructor's copy of one - a service worker's
/// fetch(event.request), destination "" (InternalRequest.main_frame_navigation:
/// Chrome, Firefox and Safari keep it top-level; whatwg/fetch#1327).
fn isTopLevelNavigation(request: *const InternalRequest) bool {
    return request.mode == .navigate and (request.destination == .document or request.main_frame_navigation);
}

/// Browser-shaped replacement for Fetch's six "determine the same-site
/// mode" steps, not a literal transcription. The browsers retain Strict
/// on same-site top-level navigation and permit Lax on cross-site safe
/// top-level navigation (RFC 6265bis 5.8.3); Fetch steps 2-3 currently
/// order those decisions differently and step 1 only admits GET/POST.
/// Keep site and navigation separate, as Chromium does in
/// ComputeSameSiteContextForRequest:
/// https://github.com/chromium/chromium/blob/main/net/cookies/cookie_util.cc
/// The missing captured client/ancestor facts are tracked below.
fn sameSiteMode(allocator: Allocator, request: *const InternalRequest) !cookiestore.SameSiteMode {
    const top_level = isTopLevelNavigation(request);
    // TODO (cookies lane Q3, 2026-10-12): navigation must populate this
    // initiator, mode/destination and method. The settings/navigation lane
    // owns those captured facts; do not infer them from a live Window here.
    const origin = request.top_level_navigation_initiator_origin orelse switch (request.origin) {
        .origin => |origin| origin,
        // A user-agent request without a client starts at its own site.
        .client => request.getUrl(),
    };
    var sites = cookiestore.SiteComparison.init(allocator, origin);
    defer sites.deinit();
    var same_site = try sites.matches(request.currentUrl());
    // Fetch same-site mode step 5 / request redirect-taint:
    // https://fetch.spec.whatwg.org/#concept-request-tainted-origin
    // Preserve the origin-based site guard across the URL list. Browser
    // WPT failures stop at different assertions (row 24 Q6: no majority
    // evidence for a redirect exception); do not infer unreported results.
    if (same_site) {
        // currentUrl is the last entry, already checked above.
        for (request.url_list.items[0 .. request.url_list.items.len - 1]) |url| {
            if (!try sites.matches(url)) {
                same_site = false;
                break;
            }
        }
        // The hops a copy no longer lists - a service worker's request,
        // whose URL list is its current hop (InternalRequest.dropped_urls_site,
        // as Fetch Metadata reads it; whatwg/fetch#1335): a cross-site one
        // makes it cross-site too, as the request itself is. Its
        // fetch(event.request) after a cross-site redirect sends no Strict
        // cookies (same-site-cookies.https.html's "... with passthrough /
        // navpreload and cross-site redirect").
        if (request.dropped_urls_site == .cross_site) same_site = false;
    }
    // TODO (Q3): a client's cross-site ancestor makes its site for cookies
    // opaque, even for a fetch to its own origin. That captured client fact
    // does not yet exist on InternalRequest; settings/navigation owns it.
    if (same_site) return .strict_or_less;
    if (top_level) {
        // RFC 6265bis 5.8.3 step 3: safe top-level navigation permits Lax
        // and Default. Unsafe navigation uses the Default policy below.
        const method = request.method;
        if (std.mem.eql(u8, method, "GET") or std.mem.eql(u8, method, "HEAD") or
            std.mem.eql(u8, method, "OPTIONS") or std.mem.eql(u8, method, "TRACE")) return .lax_or_less;
    }
    // Browser deviation (2026-10-12), 2-1: default is None.
    // Firefox release network.cookie.sameSite.laxByDefault=false:
    // https://github.com/mozilla-firefox/firefox/blob/release/modules/libpref/init/StaticPrefList.yaml
    // WebKit coreSameSitePolicy(nil) -> None:
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/network/cocoa/CookieCocoa.mm
    // Chromium CookieBase::GetEffectiveSameSite -> Lax:
    // https://github.com/chromium/chromium/blob/main/net/cookies/cookie_base.cc
    // Keep .unset distinct: only explicit SameSite=None requires Secure.
    // Third-party privacy blocking is separate, with no policy state here.
    return .unset_or_less;
}

const RequestUrl = cookiestore.RequestUrl;

test "Set-Cookie on a response goes in the jar, and comes back as Cookie for that host alone" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    const request = try InternalRequest.init(allocator, "http://a.test/dir/page");
    defer request.deinit();
    request.cookie_jar = &jar;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Content-Type", "text/plain");
    try headers.append("Set-Cookie", "one=1; Path=/");
    try headers.append("set-cookie", "two=2; Path=/; HttpOnly");
    try storeResponseCookies(allocator, request, &headers);
    try std.testing.expectEqual(2, jar.count());

    const value = (try requestCookieHeader(allocator, request)).?;
    defer allocator.free(value);
    try std.testing.expectEqualStrings("one=1; two=2", value);

    // Host-only: another host - even a subdomain - gets nothing.
    const other = try InternalRequest.init(allocator, "http://sub.a.test/");
    defer other.deinit();
    other.cookie_jar = &jar;
    try std.testing.expect(try requestCookieHeader(allocator, other) == null);
}

test "a request without a jar neither sends nor stores cookies" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://a.test/");
    defer request.deinit();
    var headers = HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "one=1");
    try storeResponseCookies(allocator, request, &headers);
    try std.testing.expect(try requestCookieHeader(allocator, request) == null);
}
