//! Main Fetch Algorithm - WHATWG Fetch Specification
//!
//! This module implements the main fetch algorithm that orchestrates
//! the entire fetch process.
//!
//! Spec: https://fetch.spec.whatwg.org/#main-fetch
//!
//! The main fetch algorithm:
//! 1. Checks local-URLs-only flag
//! 2. Reports CSP violations (stubbed)
//! 3. Upgrades mixed content (stubbed)
//! 4. Checks bad ports
//! 5. Sets referrer policy
//! 6. Determines referrer
//! 7. Handles service worker interception
//! 8. Dispatches to scheme fetch
//! 9. Creates filtered responses
//! 10. Records timing info

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const InternalResponse = internal_response.InternalResponse;
const ResponseType = internal_response.ResponseType;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const fetch_params = @import("../internal/fetch_params.zig");
const FetchParams = fetch_params.FetchParams;
const scheme_fetch = @import("scheme_fetch.zig");
const validation = @import("../internal/validation.zig");
const referrer_policy = @import("referrer_policy");
const origins = @import("../internal/origins.zig");
const clock = @import("clock");

/// Bad ports that should be blocked per Fetch spec.
/// These are ports commonly associated with protocols that shouldn't
/// be accessed via HTTP/HTTPS.
const bad_ports = [_]u16{
    1, // tcpmux
    7, // echo
    9, // discard
    11, // systat
    13, // daytime
    15, // netstat
    17, // qotd
    19, // chargen
    20, // ftp-data
    21, // ftp
    22, // ssh
    23, // telnet
    25, // smtp
    37, // time
    42, // nameserver
    43, // nicname
    53, // domain
    69, // tftp
    77, // rje
    79, // finger
    87, // ttylink
    95, // supdup
    101, // hostname
    102, // iso-tsap
    103, // gppitnp
    104, // acr-nema
    109, // pop2
    110, // pop3
    111, // sunrpc
    113, // auth
    115, // sftp
    117, // uucp-path
    119, // nntp
    123, // ntp
    135, // epmap
    137, // netbios-ns
    139, // netbios-ssn
    143, // imap
    161, // snmp
    179, // bgp
    389, // ldap
    427, // svrloc
    465, // submissions
    512, // exec
    513, // login
    514, // shell
    515, // printer
    526, // tempo
    530, // courier
    531, // chat
    532, // netnews
    540, // uucp
    548, // afp
    554, // rtsp
    556, // remotefs
    563, // nntps
    587, // submission
    601, // syslog-conn
    636, // ldaps
    989, // ftps-data
    990, // ftps
    993, // imaps
    995, // pop3s
    1719, // h323gatestat
    1720, // h323hostcall
    1723, // pptp
    2049, // nfs
    3659, // apple-sasl
    4045, // npp
    5060, // sip
    5061, // sips
    6000, // x11
    6566, // sane-port
    6665, // irc
    6666, // irc
    6667, // irc
    6668, // irc
    6669, // irc
    6697, // ircs-u
    10080, // amanda
};

/// Error types for main fetch.
pub const MainFetchError = error{
    OutOfMemory,
    NetworkError,
};

/// Main fetch result.
pub const MainFetchResult = struct {
    response: *InternalResponse,
    timing_end: i64,
};

/// Where main fetch's steps up to its fetch leave it.
///
/// Main fetch runs in two halves around the fetch that produces its response,
/// because that fetch can wait on the network: `mainFetchStart` is steps 1-12
/// and `mainFetchFinish` is steps 14 onwards, and `fetch_job.zig` runs
/// whatever lies between - HTTP fetch, which may be a network round trip, or
/// is itself main fetch again for a redirect.
pub const MainFetchStart = union(enum) {
    /// Main fetch's response is already decided - a blocked request's network
    /// error, or what a non-HTTP(S) scheme fetch returned.
    response: *InternalResponse,
    /// Step 12's fetch is HTTP fetch.
    http_fetch,
    /// Step 12's fetch is HTTP fetch with makeCORSPreflight true: a request
    /// the CORS protocol lets out only once a CORS-preflight fetch agrees.
    http_fetch_with_cors_preflight,
};

/// Main fetch steps 1-12, as far as the fetch that produces its response.
///
/// Per Fetch spec §4.1:
/// 1. Let request be fetchParams's request
/// 2. Let response be null
/// 3. If request's local-URLs-only flag is set and request's current URL is not local, return network error
/// 4. Report CSP violations for request
/// 5. Upgrade mixed content request
/// 6. If should request be blocked due to a bad port, return network error
/// 7. If should request be blocked due to mime type, return network error
/// 8. Set request's referrer policy
/// 9. Set request's referrer
/// 10. (various preparation steps)
/// 11-13. Service worker and scheme fetch dispatch
pub fn mainFetchStart(
    allocator: Allocator,
    params: *FetchParams,
    recursive: bool,
) MainFetchError!MainFetchStart {
    const request = params.request;

    // Step 3: Check local-URLs-only
    if (request.local_urls_only) {
        const url_str = request.currentUrl();
        if (!isLocalUrlString(url_str)) {
            return .{ .response = try internal_response.networkError(allocator) };
        }
    }

    // Step 4: Report CSP violations (stubbed - requires CSP implementation)
    // TODO: Implement CSP violation reporting

    // Step 5: Upgrade mixed content (stubbed - requires mixed content spec)
    // TODO: Implement mixed content upgrading

    // Step 6: Check bad port
    if (shouldBlockDueToBadPort(request)) {
        return .{ .response = try internal_response.networkError(allocator) };
    }

    // Step 7: Check MIME type blocking (stubbed - requires nosniff implementation)
    // TODO: Implement MIME type blocking

    // Step 8: Set referrer policy if empty
    // Note: In full implementation, would get from policy container
    // For now, default to strict-origin-when-cross-origin
    if (request.referrer_policy == .empty) {
        request.referrer_policy = .strict_origin_when_cross_origin;
    }

    // Step 9: If request's referrer is not "no-referrer", set request's
    // referrer to the result of invoking determine request's referrer.
    // ("client" was resolved to its URL where the client is known - fetch()
    // and XMLHttpRequest's send() - and a request still carrying "client"
    // was made by the user agent itself, with no document to name.)
    switch (request.referrer) {
        .no_referrer, .client => {},
        .url => |source| {
            const determined = determineRequestReferrer(allocator, request.referrer_policy, source, request.currentUrl()) catch return MainFetchError.OutOfMemory;
            if (determined) |url| {
                defer allocator.free(url);
                request.setReferrerUrl(url) catch return MainFetchError.OutOfMemory;
            } else request.setReferrer(.no_referrer);
        },
    }

    // Step 10: Upgrade URL scheme if needed
    // TODO: Implement HTTPS upgrading

    // Step 11: If recursive is false, do main fetch preparation
    if (!recursive) {
        // Set timing info (DOMHighResTimeStamp in milliseconds)
        const now = getCurrentTimeMs();
        params.timing_info.start_time = now;
        params.timing_info.post_redirect_start_time = now;
    }

    // Step 12: set response to the result of the steps of the first
    // matching statement. (No preloaded response candidate reaches here.)
    const url_str = request.currentUrl();
    const scheme = extractScheme(url_str);
    const same_origin = request.currentUrlIsSameOrigin() catch return MainFetchError.OutOfMemory;

    // request's current URL's origin is same origin with request's origin
    // and its response tainting is "basic"; its current URL's scheme is
    // "data"; or its mode is "navigate" or "websocket":
    if ((same_origin and request.response_tainting == .basic) or
        std.ascii.eqlIgnoreCase(scheme, "data") or
        request.mode == .navigate or request.mode == .websocket)
    {
        // 1. Set request's response tainting to "basic".
        request.response_tainting = .basic;
        // 2. Return the result of running scheme fetch.
        return schemeFetch(allocator, request, scheme);
    }

    // request's mode is "same-origin": a network error.
    if (request.mode == .same_origin) return .{ .response = try internal_response.networkError(allocator) };

    // request's mode is "no-cors":
    if (request.mode == .no_cors) {
        // 1. If request's redirect mode is not "follow", then return a
        //    network error.
        if (request.redirect_mode != .follow) return .{ .response = try internal_response.networkError(allocator) };
        // 2. Set request's response tainting to "opaque".
        request.response_tainting = .@"opaque";
        // 3. Return the result of running scheme fetch.
        return schemeFetch(allocator, request, scheme);
    }

    // request's current URL's scheme is not an HTTP(S) scheme: a network
    // error.
    if (!scheme_fetch.isHttpScheme(scheme)) return .{ .response = try internal_response.networkError(allocator) };

    // request's use-CORS-preflight flag is set, or its unsafe-request flag
    // is set and either its method is not a CORS-safelisted method or the
    // CORS-unsafe request-header names with its header list is not empty:
    //   1. Set request's response tainting to "cors".
    //   2. Return the result of running HTTP fetch given fetchParams and
    //      true. (Steps 3-4 clear the CORS-preflight cache on a network
    //      error; there is no cache.)
    // Otherwise:
    //   1. Set request's response tainting to "cors".
    //   2. Return the result of running HTTP fetch given fetchParams.
    request.response_tainting = .cors;
    if (needsCorsPreflight(allocator, request) catch return MainFetchError.OutOfMemory) return .http_fetch_with_cors_preflight;
    return .http_fetch;
}

/// Main fetch step 12's condition for HTTP fetch with makeCORSPreflight.
fn needsCorsPreflight(allocator: Allocator, request: *const InternalRequest) !bool {
    if (request.use_cors_preflight) return true;
    if (!request.unsafe_request) return false;
    if (!isCorsSafelistedMethod(request.method)) return true;
    const unsafe_names = try validation.getCORSUnsafeRequestHeaderNames(allocator, &request.header_list);
    defer {
        for (unsafe_names) |name| allocator.free(name);
        allocator.free(unsafe_names);
    }
    return unsafe_names.len > 0;
}

/// A CORS-safelisted method: `GET`, `HEAD` or `POST`.
pub fn isCorsSafelistedMethod(method: []const u8) bool {
    return std.mem.eql(u8, method, "GET") or std.mem.eql(u8, method, "HEAD") or std.mem.eql(u8, method, "POST");
}

/// Referrer Policy "determine request's referrer" for a request whose
/// referrer is the URL `source`, going to `current_url`, under `policy`:
/// the owned referrer to set, or null for "no referrer". Step 4 strips the
/// source (`stripUrlForReferrer`); `referrer_policy.determineReferrer` does
/// steps 5-8 over the origins of the stripped URL and the current URL.
fn determineRequestReferrer(
    allocator: Allocator,
    policy: internal_request.ReferrerPolicy,
    source: []const u8,
    current_url: []const u8,
) !?[]const u8 {
    // 4. Let referrerURL be the result of stripping referrerSource for use
    //    as a referrer.
    const referrer_url = (try referrer_policy.stripUrlForReferrer(allocator, source)) orelse return null;
    defer allocator.free(referrer_url);
    const source_origin = try origins.serializedOriginOf(allocator, referrer_url);
    defer allocator.free(source_origin);
    // An opaque origin has no origin-only form to send.
    const source_parts = splitSerializedOrigin(source_origin) orelse return null;
    const target_origin = try origins.serializedOriginOf(allocator, current_url);
    defer allocator.free(target_origin);
    const target_parts = splitSerializedOrigin(target_origin) orelse OriginParts{ .scheme = "", .host = "", .port = null };

    const determined = try referrer_policy.determineReferrer(
        allocator,
        std.meta.stringToEnum(referrer_policy.ReferrerPolicy, @tagName(policy)) orelse .empty,
        .{ .scheme = source_parts.scheme, .host = source_parts.host, .port = source_parts.port, .full_url = referrer_url },
        .{ .scheme = target_parts.scheme, .host = target_parts.host, .port = target_parts.port },
        try origins.sameOrigin(allocator, referrer_url, current_url),
    );
    return switch (determined) {
        .no_referrer => null,
        .url => |url| url,
    };
}

const OriginParts = struct { scheme: []const u8, host: []const u8, port: ?u16 };

/// A serialized tuple origin's scheme, host and port ("scheme://host[:port]"
/// - the port only when it is not the scheme's default). Null for "null".
fn splitSerializedOrigin(origin: []const u8) ?OriginParts {
    const sep = std.mem.indexOf(u8, origin, "://") orelse return null;
    const authority = origin[sep + 3 ..];
    // An IPv6 host keeps its brackets; a port follows the last ':' after it.
    const host_end = if (authority.len > 0 and authority[0] == '[')
        (std.mem.indexOfScalar(u8, authority, ']') orelse return null) + 1
    else
        std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
    const port: ?u16 = if (host_end < authority.len and authority[host_end] == ':')
        std.fmt.parseInt(u16, authority[host_end + 1 ..], 10) catch return null
    else
        null;
    return .{ .scheme = origin[0..sep], .host = authority[0..host_end], .port = port };
}

/// Main fetch step 12's "run scheme fetch": HTTP fetch for an HTTP(S) URL
/// (scheme fetch's "HTTP(S) scheme" branch), the scheme's own steps
/// otherwise.
fn schemeFetch(allocator: Allocator, request: *const InternalRequest, scheme: []const u8) MainFetchError!MainFetchStart {
    if (scheme_fetch.isHttpScheme(scheme)) return .http_fetch;
    const scheme_result = scheme_fetch.schemeFetchRequest(allocator, request) catch |err| {
        switch (err) {
            error.OutOfMemory => return MainFetchError.OutOfMemory,
        }
    };
    return switch (scheme_result) {
        .response => |resp| .{ .response = resp },
        .network_error => .{ .response = try internal_response.networkError(allocator) },
    };
}

/// Main fetch steps 14 onwards, given the response its fetch produced.
/// Returns the response main fetch returns.
///
/// 14-18. Response filtering and callbacks
pub fn mainFetchFinish(
    params: *FetchParams,
    recursive: bool,
    response: *InternalResponse,
) *InternalResponse {
    const request = params.request;

    // Step 14: If recursive, return early
    if (recursive) {
        return response;
    }

    // Step 20: a response to HEAD or CONNECT, or with a null body status, has
    // a null body, "and disregard any enqueuing toward it" - a body still
    // arriving is let go, which stops its transfer.
    if (!isNetworkError(response)) {
        const method = request.method;
        const head_or_connect = std.mem.eql(u8, method, "HEAD") or std.mem.eql(u8, method, "CONNECT");
        if (head_or_connect or internal_response.isNullBodyStatus(response.status)) {
            if (response.body) |body| body.deinit();
            response.body = null;
        }
    }

    // Step 14: If response is not a network error and response is not a
    // filtered response - HTTP fetch's "manual" redirect mode made an
    // opaque-redirect filtered response, the only one that reaches here -
    // then:
    if (!isNetworkError(response) and response.response_type != .opaqueredirect) {
        // 1. If request's response tainting is "cors", its CORS-exposed
        //    header-name list: the `Access-Control-Expose-Headers` names, or -
        //    for a request without credentials that exposes `*` - every
        //    header name the response has.
        if (request.response_tainting == .cors) setCorsExposedHeaderNames(request, response) catch {};

        // 2. Response filtering based on tainting. The response is marked
        //    with its filter; the consumers script sees - a Response object,
        //    an XMLHttpRequest - apply it (InternalResponse.applyFilter),
        //    while the rest of the engine reads the response itself, as the
        //    spec's internal response.
        switch (request.response_tainting) {
            .cors => {
                response.response_type = .cors;
            },
            .basic => {
                response.response_type = .basic;
            },
            .@"opaque" => {
                response.response_type = .@"opaque";
            },
        }
    }

    // Step 16: Record end timing
    params.timing_info.end_time = getCurrentTimeMs();

    // Step 17-18: Process callbacks (handled by caller)

    return response;
}

/// Main fetch step 14.1, 2-3, for `response`, a response to `request`
/// tainted "cors".
fn setCorsExposedHeaderNames(request: *const internal_request.InternalRequest, response: *InternalResponse) !void {
    const allocator = response.allocator;
    // 1. Let headerNames be the result of extracting header list values given
    //    `Access-Control-Expose-Headers` and response's header list: its
    //    #field-name values, comma-separated. Null (no such header) and
    //    failure (a value that is not a list of tokens) both leave the list
    //    empty.
    const combined = (try response.header_list.get(allocator, "Access-Control-Expose-Headers")) orelse return;
    defer allocator.free(combined);
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer names.deinit(allocator);
    var wildcard = false;
    var it = std.mem.splitScalar(u8, combined, ',');
    while (it.next()) |raw| {
        const name = std.mem.trim(u8, raw, " \t");
        if (name.len == 0) continue;
        if (!validation.isValidHeaderName(name)) return;
        if (std.mem.eql(u8, name, "*")) wildcard = true;
        try names.append(allocator, name);
    }
    for (response.cors_exposed_header_name_list.items) |old| allocator.free(old);
    response.cors_exposed_header_name_list.clearRetainingCapacity();
    // 2. If request's credentials mode is not "include" and headerNames
    //    contains `*`, then set response's CORS-exposed header-name list to
    //    all unique header names in response's header list.
    if (request.credentials_mode != .include and wildcard) {
        for (response.header_list.entries.items) |header| {
            var seen = false;
            for (response.cors_exposed_header_name_list.items) |existing| {
                if (std.ascii.eqlIgnoreCase(existing, header.name)) seen = true;
            }
            if (!seen) try response.cors_exposed_header_name_list.append(allocator, try allocator.dupe(u8, header.name));
        }
        return;
    }
    // 3. Otherwise, if headerNames is neither null nor failure, then set
    //    response's CORS-exposed header-name list to headerNames.
    for (names.items) |name| try response.cors_exposed_header_name_list.append(allocator, try allocator.dupe(u8, name));
}

/// Extract scheme from URL string.
/// Returns everything before the first ':' or empty string.
fn extractScheme(url_str: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, url_str, ":");
    if (colon_pos) |pos| {
        return url_str[0..pos];
    }
    return "";
}

/// Check if URL string is local (about, blob, data schemes).
fn isLocalUrlString(url_str: []const u8) bool {
    const url_scheme = extractScheme(url_str);
    return std.ascii.eqlIgnoreCase(url_scheme, "about") or
        std.ascii.eqlIgnoreCase(url_scheme, "blob") or
        std.ascii.eqlIgnoreCase(url_scheme, "data");
}

/// Should request be blocked due to bad port?
fn shouldBlockDueToBadPort(request: *InternalRequest) bool {
    const url_str = request.currentUrl();

    // Only check for HTTP(S) schemes
    const url_scheme = extractScheme(url_str);
    if (!std.ascii.eqlIgnoreCase(url_scheme, "http") and
        !std.ascii.eqlIgnoreCase(url_scheme, "https"))
    {
        return false;
    }

    // Extract port from URL string
    // URL format: scheme://host:port/path
    const port = extractPort(url_str) orelse return false;

    // Check against bad ports
    for (bad_ports) |bad| {
        if (port == bad) return true;
    }

    return false;
}

/// Extract port from URL string.
/// Returns null if no explicit port or invalid.
fn extractPort(url_str: []const u8) ?u16 {
    // Find "://" to skip scheme
    const scheme_end = std.mem.indexOf(u8, url_str, "://") orelse return null;
    const authority_start = scheme_end + 3;

    if (authority_start >= url_str.len) return null;

    // Find end of authority (path start or end of string)
    const rest = url_str[authority_start..];
    const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
    const authority = rest[0..path_start];

    // Find port after last ':' (handle IPv6 addresses in brackets)
    // IPv6: [::1]:8080
    // IPv4: example.com:8080
    var port_start: ?usize = null;
    if (std.mem.indexOf(u8, authority, "]")) |bracket_end| {
        // IPv6 address - port is after the bracket
        if (bracket_end + 1 < authority.len and authority[bracket_end + 1] == ':') {
            port_start = bracket_end + 2;
        }
    } else {
        // Not IPv6 - find last colon
        port_start = std.mem.lastIndexOf(u8, authority, ":");
        if (port_start) |ps| {
            port_start = ps + 1;
        }
    }

    if (port_start) |ps| {
        if (ps < authority.len) {
            const port_str = authority[ps..];
            return std.fmt.parseInt(u16, port_str, 10) catch null;
        }
    }

    return null;
}

/// Check if response is a network error.
fn isNetworkError(response: *InternalResponse) bool {
    return response.response_type == .@"error" or response.status == 0;
}

/// Get current time in milliseconds (DOMHighResTimeStamp format).
fn getCurrentTimeMs() f64 {
    // clock.wallSeconds() returns seconds, convert to milliseconds
    return @as(f64, @floatFromInt(clock.wallSeconds())) * 1000.0;
}

// =============================================================================
// Tests
// =============================================================================

test "shouldBlockDueToBadPort - blocked ports" {
    // This test requires a mock InternalRequest
    // For now, just test the bad_ports array is populated
    try std.testing.expect(bad_ports.len > 0);
    // Verify array contains expected dangerous ports (don't check indices - they may shift)
    const contains = struct {
        fn check(port: u16) bool {
            for (bad_ports) |p| {
                if (p == port) return true;
            }
            return false;
        }
    };
    try std.testing.expect(contains.check(21)); // ftp
    try std.testing.expect(contains.check(22)); // ssh
    try std.testing.expect(contains.check(23)); // telnet
}

test "bad_ports contains common dangerous ports" {
    const contains = struct {
        fn check(port: u16) bool {
            for (bad_ports) |p| {
                if (p == port) return true;
            }
            return false;
        }
    };

    // FTP ports
    try std.testing.expect(contains.check(20));
    try std.testing.expect(contains.check(21));

    // SSH
    try std.testing.expect(contains.check(22));

    // Telnet
    try std.testing.expect(contains.check(23));

    // SMTP
    try std.testing.expect(contains.check(25));

    // IRC ports
    try std.testing.expect(contains.check(6667));

    // Common safe ports should not be blocked
    try std.testing.expect(!contains.check(80));
    try std.testing.expect(!contains.check(443));
    try std.testing.expect(!contains.check(8080));
    try std.testing.expect(!contains.check(3000));
}

test "isLocalUrlString helper" {
    try std.testing.expect(isLocalUrlString("about:blank"));
    try std.testing.expect(isLocalUrlString("blob:https://example.com/uuid"));
    try std.testing.expect(isLocalUrlString("data:text/plain,Hello"));
    try std.testing.expect(isLocalUrlString("ABOUT:blank")); // Case insensitive
    try std.testing.expect(!isLocalUrlString("http://example.com"));
    try std.testing.expect(!isLocalUrlString("https://example.com"));
    try std.testing.expect(!isLocalUrlString("file:///path/to/file"));
}

test "extractScheme helper" {
    try std.testing.expectEqualStrings("https", extractScheme("https://example.com"));
    try std.testing.expectEqualStrings("http", extractScheme("http://example.com"));
    try std.testing.expectEqualStrings("data", extractScheme("data:text/plain,Hello"));
    try std.testing.expectEqualStrings("about", extractScheme("about:blank"));
    try std.testing.expectEqualStrings("", extractScheme("no-colon-here"));
}

const StepTwelveOutcome = enum { http_fetch, http_fetch_with_cors_preflight, response, network_error };

/// Run main fetch steps 1-12 for a GET of `url` with `origin` (null: the
/// request's origin stays "client"), and say where step 12 left it.
fn runStepTwelve(
    url: []const u8,
    origin: ?[]const u8,
    mode: internal_request.RequestMode,
    redirect_mode: internal_request.RedirectMode,
) !struct { outcome: StepTwelveOutcome, tainting: internal_request.ResponseTainting } {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, url);
    defer request.deinit();
    if (origin) |o| try request.setOrigin(o);
    request.mode = mode;
    request.redirect_mode = redirect_mode;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    return switch (try mainFetchStart(allocator, params, false)) {
        .http_fetch => .{ .outcome = .http_fetch, .tainting = request.response_tainting },
        .http_fetch_with_cors_preflight => .{ .outcome = .http_fetch_with_cors_preflight, .tainting = request.response_tainting },
        .response => |response| blk: {
            defer response.deinit();
            break :blk .{
                .outcome = if (isNetworkError(response)) .network_error else .response,
                .tainting = request.response_tainting,
            };
        },
    };
}

test "main fetch step 12: same origin is basic, cross-origin cors is cors" {
    var r = try runStepTwelve("http://a.test:8000/x", "http://a.test:8000", .cors, .follow);
    try std.testing.expectEqual(.http_fetch, r.outcome);
    try std.testing.expectEqual(.basic, r.tainting);

    r = try runStepTwelve("http://b.test:8000/x", "http://a.test:8000", .cors, .follow);
    try std.testing.expectEqual(.http_fetch, r.outcome);
    try std.testing.expectEqual(.cors, r.tainting);

    // A request whose origin is still "client" - one no settings object
    // gave an origin - is the client's own: basic, as before this step.
    r = try runStepTwelve("http://b.test:8000/x", null, .cors, .follow);
    try std.testing.expectEqual(.http_fetch, r.outcome);
    try std.testing.expectEqual(.basic, r.tainting);
}

test "main fetch step 12: same-origin mode, no-cors and non-HTTP cross-origin requests" {
    // "same-origin" mode to another origin: a network error.
    var r = try runStepTwelve("http://b.test:8000/x", "http://a.test:8000", .same_origin, .follow);
    try std.testing.expectEqual(.network_error, r.outcome);

    // "no-cors": opaque, but only with redirect mode "follow".
    r = try runStepTwelve("http://b.test:8000/x", "http://a.test:8000", .no_cors, .follow);
    try std.testing.expectEqual(.http_fetch, r.outcome);
    try std.testing.expectEqual(.@"opaque", r.tainting);
    r = try runStepTwelve("http://b.test:8000/x", "http://a.test:8000", .no_cors, .manual);
    try std.testing.expectEqual(.network_error, r.outcome);

    // "data" is basic from any origin; "navigate" and "websocket" too.
    r = try runStepTwelve("data:,hi", "http://a.test:8000", .cors, .follow);
    try std.testing.expectEqual(.response, r.outcome);
    try std.testing.expectEqual(.basic, r.tainting);
    r = try runStepTwelve("http://b.test:8000/x", "http://a.test:8000", .navigate, .manual);
    try std.testing.expectEqual(.http_fetch, r.outcome);
    try std.testing.expectEqual(.basic, r.tainting);

    // Any other scheme, cross-origin in "cors" mode: a network error.
    // about:blank's origin is opaque, so never the request's.
    r = try runStepTwelve("about:blank", "http://a.test:8000", .cors, .follow);
    try std.testing.expectEqual(.network_error, r.outcome);
    r = try runStepTwelve("about:blank", null, .cors, .follow);
    try std.testing.expectEqual(.response, r.outcome);
}

test "main fetch step 14.1: the CORS-exposed header-name list" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();

    // Listed names, as the header gives them, whitespace trimmed.
    {
        const response = try InternalResponse.init(allocator);
        defer response.deinit();
        try response.header_list.append("Access-Control-Expose-Headers", " X-A ,, x-b");
        try response.header_list.append("X-A", "1");
        try setCorsExposedHeaderNames(request, response);
        try std.testing.expectEqual(2, response.cors_exposed_header_name_list.items.len);
        try std.testing.expectEqualStrings("X-A", response.cors_exposed_header_name_list.items[0]);
        try std.testing.expectEqualStrings("x-b", response.cors_exposed_header_name_list.items[1]);
    }
    // `*` without credentials: every name the response has, once.
    {
        const response = try InternalResponse.init(allocator);
        defer response.deinit();
        try response.header_list.append("Access-Control-Expose-Headers", "*");
        try response.header_list.append("X-A", "1");
        try response.header_list.append("x-a", "2");
        try setCorsExposedHeaderNames(request, response);
        try std.testing.expectEqual(2, response.cors_exposed_header_name_list.items.len);
        try std.testing.expectEqualStrings("Access-Control-Expose-Headers", response.cors_exposed_header_name_list.items[0]);
        try std.testing.expectEqualStrings("X-A", response.cors_exposed_header_name_list.items[1]);
    }
    // `*` with credentials "include" is only the name `*`.
    {
        request.credentials_mode = .include;
        defer request.credentials_mode = .same_origin;
        const response = try InternalResponse.init(allocator);
        defer response.deinit();
        try response.header_list.append("Access-Control-Expose-Headers", "*");
        try response.header_list.append("X-A", "1");
        try setCorsExposedHeaderNames(request, response);
        try std.testing.expectEqual(1, response.cors_exposed_header_name_list.items.len);
        try std.testing.expectEqualStrings("*", response.cors_exposed_header_name_list.items[0]);
    }
    // A value that is not a list of tokens is failure: nothing is exposed.
    {
        const response = try InternalResponse.init(allocator);
        defer response.deinit();
        try response.header_list.append("Access-Control-Expose-Headers", "X-A, not a token");
        try setCorsExposedHeaderNames(request, response);
        try std.testing.expectEqual(0, response.cors_exposed_header_name_list.items.len);
    }
}

test "main fetch step 14: tainting marks the response, and an opaque-redirect one is left alone" {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    request.response_tainting = .cors;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const ok = try InternalResponse.init(allocator);
    defer ok.deinit();
    ok.status = 200;
    try ok.header_list.append("Access-Control-Expose-Headers", "X-A");
    _ = mainFetchFinish(params, false, ok);
    try std.testing.expectEqual(ResponseType.cors, ok.response_type);
    try std.testing.expectEqual(1, ok.cors_exposed_header_name_list.items.len);

    const redirect = try InternalResponse.init(allocator);
    defer redirect.deinit();
    redirect.status = 302;
    redirect.response_type = .opaqueredirect;
    try redirect.header_list.append("Access-Control-Expose-Headers", "X-A");
    _ = mainFetchFinish(params, false, redirect);
    try std.testing.expectEqual(ResponseType.opaqueredirect, redirect.response_type);
    try std.testing.expectEqual(0, redirect.cors_exposed_header_name_list.items.len);
}

test "main fetch step 12: an unsafe cross-origin request needs a CORS-preflight" {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .cors;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    // Not an unsafe request (one the user agent made): no preflight,
    // whatever its method.
    try request.setMethod("PUT");
    try std.testing.expectEqual(.http_fetch, try mainFetchStart(allocator, params, false));

    // An unsafe request: a method that is not CORS-safelisted...
    request.unsafe_request = true;
    try std.testing.expectEqual(.http_fetch_with_cors_preflight, try mainFetchStart(allocator, params, false));

    // ...but a safelisted method with safelisted headers goes as it is...
    try request.setMethod("POST");
    try request.header_list.append("Content-Type", "text/plain");
    try std.testing.expectEqual(.http_fetch, try mainFetchStart(allocator, params, false));

    // ...until a header is not safelisted.
    try request.header_list.append("X-Custom", "1");
    try std.testing.expectEqual(.http_fetch_with_cors_preflight, try mainFetchStart(allocator, params, false));

    // The use-CORS-preflight flag asks for one outright.
    request.unsafe_request = false;
    request.use_cors_preflight = true;
    try std.testing.expectEqual(.http_fetch_with_cors_preflight, try mainFetchStart(allocator, params, false));
}

test "main fetch step 9: a URL referrer is replaced by the referrer its policy allows" {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    try request.setReferrerUrl("http://user:pw@a.test/page?q#frag");
    request.mode = .no_cors;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    // The default policy, strict-origin-when-cross-origin, to another
    // origin: the referrer's origin.
    _ = try mainFetchStart(allocator, params, false);
    try std.testing.expectEqualStrings("http://a.test/", request.referrer.url);

    // "no-referrer": none at all.
    request.referrer_policy = .no_referrer;
    _ = try mainFetchStart(allocator, params, true);
    try std.testing.expect(request.referrer == .no_referrer);
}

test "splitSerializedOrigin: scheme, host and a non-default port" {
    const a = splitSerializedOrigin("http://a.test:8000").?;
    try std.testing.expectEqualStrings("http", a.scheme);
    try std.testing.expectEqualStrings("a.test", a.host);
    try std.testing.expectEqual(@as(?u16, 8000), a.port);
    const b = splitSerializedOrigin("https://[::1]").?;
    try std.testing.expectEqualStrings("[::1]", b.host);
    try std.testing.expectEqual(@as(?u16, null), b.port);
    try std.testing.expect(splitSerializedOrigin("null") == null);
}
