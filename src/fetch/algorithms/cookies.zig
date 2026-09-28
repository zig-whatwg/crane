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
    const url = UrlParts.of(request.currentUrl()) orelse return null;
    // 2. Let sameSite be the result of determining the same-site mode for
    //    request.
    const same_site = sameSiteMode(request);
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
        .same_site_context = same_site,
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
    const url = UrlParts.of(request.currentUrl()) orelse return;
    // 2. allowNonHostOnlyCookieForPublicSuffix is false. 3. isSecure.
    // 4. httpOnlyAllowed is true.
    // 5. sameSiteStrictOrLaxAllowed: the same-site mode is "strict-or-less".
    // TODO: pass it on once the jar's parse and store takes it; today every
    //       SameSite cookie is stored, as in "strict-or-less".
    // 6. For each header of response's header list whose name is
    //    `Set-Cookie` (each processed on its own - they never combine):
    //    parse and store a cookie given its value, isSecure, and request's
    //    current URL's host and path. 6.3: garbage collect cookies for the
    //    host - the jar removes expired cookies as it goes.
    var values: std.ArrayListUnmanaged([]const u8) = .empty;
    defer values.deinit(allocator);
    for (headers.iterator()) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "Set-Cookie")) try values.append(allocator, header.value);
    }
    if (values.items.len == 0) return;
    try cookiestore.http_integration.processSetCookieHeaders(allocator, jar, values.items, url.host, url.path, url.secure);
}

/// Fetch "determine the same-site mode" for `request`, as the jar's
/// retrieval context: "strict-or-less" sends every cookie, "lax-or-less"
/// all but SameSite=Strict ones, "unset-or-less" neither Strict nor Lax.
///
/// TODO: steps 2, 4 and 5 compare sites - a top-level navigation's
/// initiator, the client's "has cross-site ancestor", a cross-site redirect
/// taint - and there is no "same site" (the registrable-domain comparison)
/// in fetch yet; until there is, every request is "strict-or-less".
fn sameSiteMode(request: *const InternalRequest) cookiestore.SameSiteContext {
    _ = request;
    // 6. Return "strict-or-less".
    return .same_site;
}

/// The parts of a request's current URL the cookie store is keyed on. The
/// URL is a serialized one from the request's URL list, so it is already
/// canonical: an http(s) URL is "scheme://[userinfo@]host[:port]/path..."
/// with a lowercase host, and userinfo's own `@` and `/` percent-encoded.
const UrlParts = struct {
    host: []const u8,
    path: []const u8,
    secure: bool,

    fn of(url: []const u8) ?UrlParts {
        const secure = std.ascii.startsWithIgnoreCase(url, "https://");
        if (!secure and !std.ascii.startsWithIgnoreCase(url, "http://")) return null;
        const after_scheme = url[(std.mem.indexOf(u8, url, "://") orelse return null) + 3 ..];
        const authority_end = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
        var authority = after_scheme[0..authority_end];
        if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];
        // An IPv6 host keeps its brackets, as the host serializer writes it.
        const host_end = if (authority.len > 0 and authority[0] == '[')
            (std.mem.indexOfScalar(u8, authority, ']') orelse return null) + 1
        else
            std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
        const rest = after_scheme[authority_end..];
        const path_end = std.mem.indexOfAny(u8, rest, "?#") orelse rest.len;
        return .{
            .host = authority[0..host_end],
            .path = if (path_end == 0) "/" else rest[0..path_end],
            .secure = secure,
        };
    }
};

test "a cookie's URL parts: host without port or userinfo, path without query" {
    const Case = struct { url: []const u8, host: []const u8, path: []const u8, secure: bool };
    const cases = [_]Case{
        .{ .url = "http://example.com/a/b?q#f", .host = "example.com", .path = "/a/b", .secure = false },
        .{ .url = "https://u:p@example.com:8443/", .host = "example.com", .path = "/", .secure = true },
        .{ .url = "http://[::1]:8000/x", .host = "[::1]", .path = "/x", .secure = false },
        .{ .url = "http://127.0.0.1?q", .host = "127.0.0.1", .path = "/", .secure = false },
    };
    for (cases) |case| {
        const parts = UrlParts.of(case.url).?;
        try std.testing.expectEqualStrings(case.host, parts.host);
        try std.testing.expectEqualStrings(case.path, parts.path);
        try std.testing.expectEqual(case.secure, parts.secure);
    }
    try std.testing.expect(UrlParts.of("data:text/plain,x") == null);
}

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
