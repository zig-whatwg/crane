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
    // 2. allowNonHostOnlyCookieForPublicSuffix is false.
    // 3. isSecure: request's current URL's scheme is "https".
    // 4. httpOnlyAllowed is true.
    // 5. sameSiteStrictOrLaxAllowed: the same-site mode is
    //    "strict-or-less".
    const options: cookiestore.StoreOptions = .{
        .is_secure = url.secure,
        .host = url.host,
        .http_only_allowed = true,
        .same_site_strict_or_lax_allowed = sameSiteMode(request) == .strict_or_less,
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

/// Fetch "determine the same-site mode" for `request`.
///
/// TODO: steps 2, 4 and 5 compare sites - a top-level navigation's
/// initiator, the client's "has cross-site ancestor", a cross-site redirect
/// taint - and there is no "same site" (the registrable-domain comparison)
/// in fetch yet; until there is, every request is "strict-or-less".
fn sameSiteMode(request: *const InternalRequest) cookiestore.SameSiteMode {
    _ = request;
    // 6. Return "strict-or-less".
    return .strict_or_less;
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
