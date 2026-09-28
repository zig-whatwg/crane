//! HTTP Fetch Algorithm - WHATWG Fetch Specification
//!
//! This module implements the HTTP fetch algorithm that handles
//! HTTP(S) requests.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-fetch
//!
//! The HTTP fetch algorithm:
//! 1. Let request be fetchParams's request
//! 2. Let response be null
//! 3. If request's service-workers mode is 'all', handle service worker
//! 4. If response is null, run HTTP-redirect fetch or HTTP-network-or-cache fetch
//! 5. If CORS flag and response is not a network error, run CORS check

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const origins = @import("../internal/origins.zig");
const validation = @import("../internal/validation.zig");
const referrer_policy = @import("referrer_policy");
const InternalResponse = internal_response.InternalResponse;
const ResponseType = internal_response.ResponseType;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const RedirectMode = internal_request.RedirectMode;
const CredentialsMode = internal_request.CredentialsMode;
const fetch_params = @import("../internal/fetch_params.zig");
const FetchParams = fetch_params.FetchParams;
const network = @import("../network/root.zig");
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const CurlCookieManager = network.curl_cookies.CurlCookieManager;
const clock = @import("clock");
const BodyPipe = @import("../internal/body_pipe.zig").BodyPipe;

// URL Standard, for a redirect's location URL. The same three modules `xhr`
// takes for `open()` - `url`'s root re-exports neither the serializer nor a
// plain `parse`.
const url_record = @import("url_record");
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");

/// Error types for HTTP fetch.
pub const HttpFetchError = error{
    OutOfMemory,
    NetworkError,
    CorsError,
};

/// HTTP fetch result.
pub const HttpFetchResult = struct {
    response: *InternalResponse,
};

/// Options for HTTP fetch.
pub const HttpFetchOptions = struct {
    /// Cookie manager for credentials handling (optional)
    /// If null, LibcurlBackend creates its own cookie manager.
    /// Cookies are handled automatically by libcurl when attached.
    cookie_manager: ?*CurlCookieManager = null,
};

/// What HTTP fetch does with the response HTTP-network-or-cache fetch gave it.
pub const HttpFetchNext = union(enum) {
    /// HTTP fetch returns this response.
    response: *InternalResponse,
    /// HTTP-redirect fetch reached its steps 20-22: run main fetch again with
    /// recursive true, then `httpRedirectFetchFinish` on what it returns -
    /// which HTTP fetch then returns.
    recursive_main_fetch,
};

/// HTTP fetch, from the point HTTP-network-or-cache fetch has returned
/// `response`, whose ownership passes in.
///
/// HTTP fetch runs in two halves around the network: before it is
/// `httpNetworkOrCacheFetchStart`, and between them `fetch_job.zig` performs
/// the request, blocking or on the event loop, and hands the result to
/// `httpNetworkFetchFinish`.
///
/// Per Fetch spec §4.6:
/// 1. Let request be fetchParams's request
/// 2. Let response be null
/// 3. If request's service-workers mode is 'all'...
/// 4. If response is null:
///    - If request's redirect mode is 'follow', set response to the result of
///      running HTTP-redirect fetch
///    - Otherwise, set response to the result of running HTTP-network-or-cache fetch
/// 5. If CORS flag is set and response is not a network error, run CORS check
pub fn httpFetchFinish(
    allocator: Allocator,
    params: *FetchParams,
    options: HttpFetchOptions,
    response: *InternalResponse,
) HttpFetchError!HttpFetchNext {
    const request = params.request;
    var final_response = response;

    // Step 3: Service worker handling
    // If request's service-workers mode is "all", handle service worker interception
    // TODO: Implement service worker interception when service worker module is available
    // For now, skip service worker and proceed directly to network fetch

    // Step 4.4: If request's response tainting is "cors" and a CORS check
    // for request and response returns failure, then return a network
    // error. Here, not in HTTP-network fetch, because it covers a 304 the
    // cache revalidated too - and before step 8's redirect handling, since a
    // redirect is checked like any response.
    _ = options;
    if (request.response_tainting == .cors and !isNetworkError(final_response)) {
        const cors_result = corsCheck(allocator, request, final_response) catch return HttpFetchError.OutOfMemory;
        if (cors_result == .failure) {
            final_response.deinit();
            return HttpFetchError.CorsError;
        }
    }

    // Step 5: If response's status is a redirect status, handle based on redirect mode
    // Per WHATWG Fetch spec: check redirect status AFTER getting response
    if (!isNetworkError(final_response) and internal_response.isRedirectStatus(final_response.status)) {
        switch (request.redirect_mode) {
            .@"error" => {
                // Return a network error
                final_response.deinit();
                return .{ .response = try internal_response.networkError(allocator) };
            },
            .manual => {
                // Return an opaque-redirect filtered response
                // For manual mode, we return the redirect response as-is
                // but mark it as opaque-redirect type
                final_response.response_type = .opaqueredirect;
                return .{ .response = final_response };
            },
            .follow => {
                // Step 6.2 "follow": "Set response to the result of running
                // HTTP-redirect fetch given fetchParams and response." The
                // response in hand IS the redirect - it is not fetched again.
                return httpRedirectFetchStart(allocator, params, final_response);
            },
        }
    }

    return .{ .response = final_response };
}

/// HTTP-redirect fetch, up to its recursive main fetch: steps 1-19.
///
/// Spec: https://fetch.spec.whatwg.org/#http-redirect-fetch
///
/// Takes ownership of `response`, the redirect being followed. The previous
/// version took no response at all: it fetched the redirecting URL a SECOND
/// time, appended the raw `Location` value to the URL list without parsing it,
/// and then read `response.status` after `response.deinit()` - a use-after-free
/// that crashed `fetch/api/redirect/redirect-{location,mode,to-dataurl}.any.js`
/// and `fetch/api/cors/cors-redirect.any.js`.
///
/// `.response` is what HTTP-redirect fetch returns without fetching again;
/// `.recursive_main_fetch` means steps 20-22 are next.
pub fn httpRedirectFetchStart(
    allocator: Allocator,
    params: *FetchParams,
    response: *InternalResponse,
) HttpFetchError!HttpFetchNext {
    // Step 1: Let request be fetchParams's request.
    const request = params.request;

    // Step 2: Let internalResponse be response. Nothing at this layer is a
    // filtered response yet.

    // Step 3: Let locationURL be internalResponse's location URL given
    // request's current URL's fragment.
    const location = locationUrl(allocator, response, request.currentUrl()) catch |err| {
        response.deinit();
        return switch (err) {
            error.OutOfMemory => HttpFetchError.OutOfMemory,
            // Step 5: If locationURL is failure, return a network error.
            error.InvalidLocation => .{ .response = try internal_response.networkError(allocator) },
        };
    };

    // Step 4: If locationURL is null, then return response.
    const location_url = location orelse return .{ .response = response };
    defer allocator.free(location_url);

    // Everything below needs only the status and step 19's policy, so read
    // them before letting the redirect response go.
    const status = response.status;
    const redirect_policy = referrerPolicyOf(allocator, response) catch {
        response.deinit();
        return HttpFetchError.OutOfMemory;
    };
    response.deinit();

    // Step 6: If locationURL's scheme is not an HTTP(S) scheme, return a
    // network error.
    if (!std.mem.startsWith(u8, location_url, "http:") and !std.mem.startsWith(u8, location_url, "https:")) {
        return .{ .response = try internal_response.networkError(allocator) };
    }

    // Step 7: If request's redirect count is 20, return a network error.
    if (request.redirect_count >= 20) {
        return .{ .response = try internal_response.networkError(allocator) };
    }

    // Step 8: Increase request's redirect count by 1.
    request.redirect_count += 1;

    // Steps 9-10: a CORS request is not redirected to a URL with
    // credentials - unless, in cors mode, to its own origin while its
    // tainting is not yet "cors".
    if (request.mode == .cors or request.response_tainting == .cors) {
        const has_credentials = urlIncludesCredentials(allocator, location_url) catch return HttpFetchError.OutOfMemory;
        if (has_credentials) {
            // 9. If request's mode is "cors", locationURL includes
            //    credentials, and request's origin is not same origin with
            //    locationURL's origin, then return a network error.
            const same = switch (request.origin) {
                .client => true,
                .origin => |o| origins.sameOrigin(allocator, location_url, o) catch return HttpFetchError.OutOfMemory,
            };
            if (request.mode == .cors and !same) return .{ .response = try internal_response.networkError(allocator) };
            // 10. If request's response tainting is "cors" and locationURL
            //     includes credentials, then return a network error.
            if (request.response_tainting == .cors) return .{ .response = try internal_response.networkError(allocator) };
        }
    }

    // Step 11: If internalResponse's status is not 303, request's body is
    // non-null, and request's body's source is null, return a network error.
    // A byte body always has a source; only a stream body can lack one.
    if (status != 303) {
        if (request.body) |b| switch (b) {
            .bytes => {},
            .body => |body| if (body.source == .none) {
                return .{ .response = try internal_response.networkError(allocator) };
            },
        };
    }

    // Step 12: POST under 301/302, or anything but GET/HEAD under 303, becomes
    // a GET without a body or its body headers.
    if (redirectBecomesGet(status, request.method)) {
        // Step 12.1
        request.setMethod("GET") catch return HttpFetchError.OutOfMemory;
        if (request.body) |b| switch (b) {
            .body => |body| body.deinit(),
            .bytes => {}, // borrowed, never owned by the request
        };
        request.body = null;

        // Step 12.2: delete each request-body-header name.
        for (request_body_header_names) |name| request.header_list.delete(name);
    }

    // Step 13: crossing to another origin drops `Authorization`, the one CORS
    // non-wildcard request-header name.
    if (!sameHttpOrigin(request.currentUrl(), location_url)) {
        request.header_list.delete("Authorization");
    }

    // Step 14: re-extracting a byte body from its source yields the same
    // bytes, so there is nothing to do for the bodies this layer carries.

    // Steps 15-17: timing info.
    const now = getCurrentTimeMs();
    params.timing_info.redirect_end_time = now;
    params.timing_info.post_redirect_start_time = now;
    if (params.timing_info.redirect_start_time == 0) {
        params.timing_info.redirect_start_time = params.timing_info.start_time;
    }

    // Step 18: Append locationURL to request's URL list.
    request.addUrl(location_url) catch return HttpFetchError.OutOfMemory;

    // Step 19: set request's referrer policy on redirect: "If policy is not
    // the empty string, then set request's referrer policy to policy."
    if (redirect_policy) |policy| request.referrer_policy = policy;

    // Steps 20-22: recursive main fetch. Redirect mode "manual" only reaches
    // here for a navigation, which this layer does not do, so recursive stays
    // true.
    return .recursive_main_fetch;
}

/// HTTP-redirect fetch after its recursive main fetch returned `response`,
/// whose ownership passes in. Returns what HTTP-redirect fetch returns.
pub fn httpRedirectFetchFinish(
    allocator: Allocator,
    params: *FetchParams,
    response: *InternalResponse,
) HttpFetchError!*InternalResponse {
    const request = params.request;

    // A response's URL list is the request's: it is what makes `redirected`
    // true and `url` the final URL. Network errors keep theirs empty.
    if (response.response_type != .@"error") {
        for (response.url_list.items) |u| allocator.free(u);
        response.url_list.clearRetainingCapacity();
        for (request.url_list.items) |u| {
            response.addUrl(u) catch {
                response.deinit();
                return HttpFetchError.OutOfMemory;
            };
        }
    }

    return response;
}

/// Request-body-header names.
///
/// Spec: https://fetch.spec.whatwg.org/#request-body-header-name
const request_body_header_names = [_][]const u8{
    "Content-Encoding",
    "Content-Language",
    "Content-Location",
    "Content-Type",
};

/// Referrer Policy "parse a referrer policy from a Referrer-Policy header"
/// on `response`: the last of its `Referrer-Policy` values that is a
/// referrer policy, or null for the empty string (none is).
fn referrerPolicyOf(allocator: Allocator, response: *InternalResponse) !?internal_request.ReferrerPolicy {
    const value = (try response.header_list.get(allocator, "Referrer-Policy")) orelse return null;
    defer allocator.free(value);
    const parsed = referrer_policy.parseReferrerPolicyHeader(value) orelse return null;
    return std.meta.stringToEnum(internal_request.ReferrerPolicy, @tagName(parsed));
}

/// URL "includes credentials": a non-empty username or password.
fn urlIncludesCredentials(allocator: Allocator, url: []const u8) !bool {
    var record = basic_parser.parse(allocator, url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer record.deinit();
    return record.username().len > 0 or record.password().len > 0;
}

/// HTTP-redirect fetch step 12: does following this redirect turn the request
/// into a GET?
fn redirectBecomesGet(status: u16, method: []const u8) bool {
    if ((status == 301 or status == 302) and std.mem.eql(u8, method, "POST")) return true;
    if (status == 303 and !std.mem.eql(u8, method, "GET") and !std.mem.eql(u8, method, "HEAD")) return true;
    return false;
}

/// Are two SERIALIZED HTTP(S) URLs same origin?
///
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin - the
/// tuple (scheme, host, port). Comparing text is exact here because both sides
/// come out of the same serializer: scheme and host are canonical, a default
/// port is already elided, and userinfo - the only thing between `//` and the
/// host - ends at the one `@` the serializer leaves unescaped.
fn sameHttpOrigin(a: []const u8, b: []const u8) bool {
    const pa = splitOrigin(a) orelse return false;
    const pb = splitOrigin(b) orelse return false;
    return std.mem.eql(u8, pa.scheme, pb.scheme) and std.mem.eql(u8, pa.host_port, pb.host_port);
}

const OriginParts = struct { scheme: []const u8, host_port: []const u8 };

fn splitOrigin(serialized: []const u8) ?OriginParts {
    const sep = std.mem.indexOf(u8, serialized, "://") orelse return null;
    const rest = serialized[sep + 3 ..];
    const authority = rest[0 .. std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len];
    const host_start = if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| at + 1 else 0;
    return .{ .scheme = serialized[0..sep], .host_port = authority[host_start..] };
}

const LocationError = error{ OutOfMemory, InvalidLocation };

/// A response's location URL.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-response-location-url
///
/// Returns null when there is no `Location` header, an owned serialized URL
/// otherwise, and `error.InvalidLocation` for the spec's "failure": more than
/// one `Location` value, or one that does not parse against the response's URL.
fn locationUrl(allocator: Allocator, response: *InternalResponse, request_url: []const u8) LocationError!?[]u8 {
    // Step 1: If response's status is not a redirect status, return null.
    if (!internal_response.isRedirectStatus(response.status)) return null;

    // Step 2: Let location be the result of extracting header list values
    // given `Location` and response's header list. `Location` is a
    // single-value header, so two of them are failure.
    var value: ?[]const u8 = null;
    for (response.header_list.iterator()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "Location")) continue;
        if (value != null) return error.InvalidLocation;
        value = header.value;
    }
    const raw = value orelse return null;

    // Step 3: parse location with response's URL.
    var base_record: ?url_record.URLRecord = null;
    defer if (base_record) |*b| b.deinit();
    if (response.url()) |base| {
        base_record = basic_parser.parse(allocator, base, null) catch null;
    }

    var parsed = basic_parser.parse(
        allocator,
        std.mem.trim(u8, raw, " \t"),
        if (base_record) |*b| b else null,
    ) catch return error.InvalidLocation;
    defer parsed.deinit();

    const serialized = url_serializer.serialize(allocator, &parsed, false) catch return error.OutOfMemory;

    // Step 4: If location is a URL whose fragment is null, set location's
    // fragment to requestFragment - the request's current URL's fragment.
    // Appending `#fragment` to the serialization is the same URL.
    if (parsed.fragment() == null) {
        if (std.mem.indexOfScalar(u8, request_url, '#')) |hash| {
            defer allocator.free(serialized);
            return std.mem.concat(allocator, u8, &.{ serialized, request_url[hash..] }) catch error.OutOfMemory;
        }
    }

    // Step 5: Return location.
    return @constCast(serialized);
}

/// Where HTTP-network-or-cache fetch's steps before the network leave it.
pub const HttpNetworkStart = union(enum) {
    /// Its response is already decided, with no request sent.
    response: *InternalResponse,
    /// HTTP-network fetch has built this request; it is the network's to
    /// answer. Its header list is owned - `freeNetworkRequest` releases it.
    network: NetworkRequest,
};

/// HTTP-network-or-cache fetch, up to the request HTTP-network fetch sends.
///
/// Per Fetch spec §4.8:
/// This algorithm handles both cached and network responses.
/// For now, we skip caching and go directly to network fetch.
pub fn httpNetworkOrCacheFetchStart(
    allocator: Allocator,
    params: *FetchParams,
    options: HttpFetchOptions,
) HttpFetchError!HttpNetworkStart {
    const request = params.request;

    // TODO: Implement full cache lookup logic per spec
    // For now, skip cache and go directly to network

    // Check cache mode
    if (request.cache_mode == .only_if_cached) {
        // Only-if-cached requires a cached response
        // Since we don't have cache yet, return network error
        return .{ .response = try internal_response.networkError(allocator) };
    }

    _ = options;

    // HTTP-network fetch, step 8.3: "If connection is an HTTP/1.x
    // connection, request's body is non-null, and request's body's source is
    // null, then return a network error." A body with no source was made
    // from a ReadableStream, and cannot be sent twice; only HTTP/2 and later
    // send one. A cleartext connection is always HTTP/1.x here (there is no
    // h2c), so an http: URL's is refused now; an https: one's connection is
    // HTTP/2 only if ALPN chooses h2, which the network layer checks before
    // sending anything (NetworkRequest.require_http2).
    var require_http2 = false;
    if (request.body) |b| switch (b) {
        .bytes => {},
        .body => |body| if (body.source == .none) {
            if (!std.ascii.startsWithIgnoreCase(request.currentUrl(), "https:")) return .{ .response = try internal_response.networkError(allocator) };
            require_http2 = true;
        },
    };

    // Steps 8.7-8.19 add headers to httpRequest - here, to the request
    // sent, not to request itself: httpRequest is its clone, and a redirect's
    // main fetch adds its own.
    var added: std.ArrayListUnmanaged(NetworkRequest.Header) = .empty;
    defer added.deinit(allocator);
    errdefer for (added.items) |header| allocator.free(header.value);
    httpRequestHeaders(allocator, request, &added) catch return HttpFetchError.OutOfMemory;

    // HTTP-network fetch, step 1: Build NetworkRequest from InternalRequest
    var network_request = buildNetworkRequest(allocator, request, added.items) catch {
        return HttpFetchError.OutOfMemory;
    };
    network_request.require_http2 = require_http2;
    return .{ .network = network_request };
}

/// HTTP-network-or-cache fetch, once HTTP-network fetch has returned
/// `response` (ownership passes in and out): step 14, a 401.
///
/// "If response's status is 401, httpRequest's response tainting is not
/// "cors", includeCredentials is true, and request's traversable for user
/// prompts is a traversable navigable", a request whose body has a null
/// source - a stream, which cannot be sent again - is a network error
/// (14.2.1). The rest of the step prompts the end user for a username and
/// password and fetches again; there is no one to prompt here, so the
/// prompt is as good as cancelled and the 401 is the response.
pub fn httpNetworkOrCacheFetchFinish(allocator: Allocator, request: *const InternalRequest, response: *InternalResponse) HttpFetchError!*InternalResponse {
    if (response.status != 401) return response;
    if (request.response_tainting == .cors or !httpNetworkFetchUsesCookies(request)) return response;
    if (request.traversable_for_user_prompts != .traversable) return response;
    const body = request.body orelse return response;
    switch (body) {
        .bytes => return response,
        .body => |b| if (b.source != .none) return response,
    }
    response.deinit();
    return internal_response.networkError(allocator) catch HttpFetchError.OutOfMemory;
}

/// HTTP-network-or-cache fetch step 8's headers for httpRequest: those it
/// appends to the request's header list, gathered for the request sent (each
/// value owned). curl adds `Host`, and `Content-Length` for a body, itself.
fn httpRequestHeaders(allocator: Allocator, request: *InternalRequest, added: *std.ArrayListUnmanaged(NetworkRequest.Header)) !void {
    const list = &request.header_list;
    // 8.5-8.9: a null body's Content-Length is `0` for POST and PUT.
    // (A body's own length curl sends with it.)
    if (request.body == null and (std.mem.eql(u8, request.method, "POST") or std.mem.eql(u8, request.method, "PUT"))) {
        try addHeader(allocator, added, "Content-Length", "0");
    }
    // 8.11. If httpRequest's referrer is a URL, append (`Referer`, it
    //       serialized and isomorphic encoded).
    if (request.referrer == .url) try addHeader(allocator, added, "Referer", request.referrer.url);
    // 8.12. Append a request `Origin` header for httpRequest.
    if (try requestOriginHeader(allocator, request)) |origin_value| {
        added.append(allocator, .{ .name = "Origin", .value = origin_value }) catch |err| {
            allocator.free(origin_value);
            return err;
        };
    }
    // 8.15. If httpRequest's header list does not contain `User-Agent`,
    //       append (`User-Agent`, the environment default `User-Agent`
    //       value).
    if (!list.contains("User-Agent")) try addHeader(allocator, added, "User-Agent", default_user_agent);
    // 8.16. A conditional request in cache mode "default" is "no-store".
    var cache_mode = request.cache_mode;
    if (cache_mode == .default) {
        for ([_][]const u8{ "If-Modified-Since", "If-None-Match", "If-Unmodified-Since", "If-Match", "If-Range" }) |name| {
            if (list.contains(name)) cache_mode = .no_store;
        }
    }
    // 8.17. "no-cache": (`Cache-Control`, `max-age=0`), unless the request
    //       has one or its prevent-modification flag is set.
    if (cache_mode == .no_cache and !request.prevent_no_cache_cache_control_header_modification and !list.contains("Cache-Control")) {
        try addHeader(allocator, added, "Cache-Control", "max-age=0");
    }
    // 8.18. "no-store" and "reload": `Pragma` and `Cache-Control` both
    //       `no-cache`, each unless the request has one.
    if (cache_mode == .no_store or cache_mode == .reload) {
        if (!list.contains("Pragma")) try addHeader(allocator, added, "Pragma", "no-cache");
        if (!list.contains("Cache-Control")) try addHeader(allocator, added, "Cache-Control", "no-cache");
    }
    // 8.19. If httpRequest's header list contains `Range`, then append
    //       (`Accept-Encoding`, `identity`).
    if (list.contains("Range")) try addHeader(allocator, added, "Accept-Encoding", "identity");
}

fn addHeader(allocator: Allocator, added: *std.ArrayListUnmanaged(NetworkRequest.Header), name: []const u8, value: []const u8) !void {
    const copy = try allocator.dupe(u8, value);
    added.append(allocator, .{ .name = name, .value = copy }) catch |err| {
        allocator.free(copy);
        return err;
    };
}

/// The environment default `User-Agent` value (Fetch: implementation
/// defined; HTML's navigator.userAgent is to return it). The same per-OS
/// string src/webidl/impls/Navigator.zig's userAgent getter returns.
pub const default_user_agent = switch (@import("builtin").os.tag) {
    .macos => "Mozilla/5.0 (Macintosh; Intel Mac OS X) WhatWG-Zig/1.0",
    .linux => "Mozilla/5.0 (X11; Linux x86_64) WhatWG-Zig/1.0",
    .windows => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) WhatWG-Zig/1.0",
    else => "Mozilla/5.0 WhatWG-Zig/1.0",
};

/// Fetch "append a request `Origin` header" for `request`: the value to
/// append, or null when it appends none. OWNED.
///
/// The algorithm asserts request's origin is not "client"; a request the
/// user agent made for itself (a script or frame load, which still keeps
/// "client") gets no `Origin`, as before.
///
/// Spec: https://fetch.spec.whatwg.org/#append-a-request-origin-header
fn requestOriginHeader(allocator: Allocator, request: *InternalRequest) !?[]u8 {
    if (request.origin == .client) return null;
    // 2. Let serializedOrigin be the result of byte-serializing a request
    //    origin with request.
    const serialized = try request.serializeOrigin(allocator);
    errdefer allocator.free(serialized);
    // 3. If request's response tainting is "cors" or request's mode is
    //    "websocket" (or "webtransport"), then append it.
    if (request.response_tainting == .cors or request.mode == .websocket) return serialized;
    // 4. Otherwise, if request's method is neither `GET` nor `HEAD`:
    if (std.mem.eql(u8, request.method, "GET") or std.mem.eql(u8, request.method, "HEAD")) {
        allocator.free(serialized);
        return null;
    }
    // 4.1. If request's mode is not "cors", then switch on request's
    //      referrer policy, which may make serializedOrigin `null`.
    if (request.mode != .cors) {
        const hidden = switch (request.referrer_policy) {
            .no_referrer => true,
            // A tuple origin whose scheme is "https", and a current URL
            // whose scheme is not.
            .no_referrer_when_downgrade, .strict_origin, .strict_origin_when_cross_origin => std.ascii.startsWithIgnoreCase(request.origin.origin, "https://") and
                !std.ascii.startsWithIgnoreCase(request.currentUrl(), "https:"),
            .same_origin => !try request.currentUrlIsSameOrigin(),
            else => false,
        };
        if (hidden) {
            allocator.free(serialized);
            return try allocator.dupe(u8, "null");
        }
    }
    // 4.2. Append (`Origin`, serializedOrigin).
    return serialized;
}

/// Whether HTTP-network fetch sends and stores cookies for `request`:
/// HTTP-network-or-cache fetch's includeCredentials - credentials mode
/// "include", or "same-origin" while the response tainting is "basic" (a
/// cross-origin request in "cors" mode sends its cookies only when it asks
/// to). Cookie handling itself is libcurl's, through CurlCookieManager - it
/// sends the matching cookies (Fetch spec §4.9 step 5) and stores the
/// `Set-Cookie` ones (step 11).
pub fn httpNetworkFetchUsesCookies(request: *const InternalRequest) bool {
    return switch (request.credentials_mode) {
        .include => true,
        .same_origin => request.response_tainting == .basic,
        .omit => false,
    };
}

/// HTTP-network fetch, once the network has answered with `network_response`
/// (sent at `start_time`): the response it returns.
///
/// A network response that is all there is carries its body. One whose body
/// is still arriving - the response is handed on at its headers, step 20 -
/// has none, and `streamed_body` is the pipe it arrives through, whose
/// ownership passes in.
///
/// Per Fetch spec §4.9:
/// 3. Convert NetworkResponse to InternalResponse
/// 4. Record timing information
pub fn httpNetworkFetchFinish(
    allocator: Allocator,
    params: *FetchParams,
    network_response: *const NetworkResponse,
    start_time: f64,
    streamed_body: ?*BodyPipe,
) HttpFetchError!*InternalResponse {
    const request = params.request;

    // Step 3: Convert NetworkResponse to InternalResponse
    const response = InternalResponse.init(allocator) catch {
        if (streamed_body) |pipe| pipe.release();
        return HttpFetchError.OutOfMemory;
    };
    errdefer response.deinit();

    // The body first, so that from here the response owns the pipe.
    if (streamed_body) |pipe| {
        response.body = @import("../internal/body.zig").Body.fromPipe(allocator, pipe) catch {
            pipe.release();
            return HttpFetchError.OutOfMemory;
        };
    }

    // Set response URL from request (or final URL if redirected)
    if (network_response.final_url) |final_url| {
        response.addUrl(final_url) catch {
            return HttpFetchError.OutOfMemory;
        };
    } else {
        response.addUrl(request.currentUrl()) catch {
            return HttpFetchError.OutOfMemory;
        };
    }

    // Set status code, and the status message: the status line's
    // reason-phrase (HTTP/1.x; none after).
    response.status = network_response.status;
    if (network_response.status_message.len > 0) response.setStatusMessage(network_response.status_message) catch {
        return HttpFetchError.OutOfMemory;
    };

    // Copy headers
    for (network_response.headers) |header| {
        response.header_list.append(header.name, header.value) catch {
            return HttpFetchError.OutOfMemory;
        };
    }

    // Set body if present
    if (network_response.body) |body_bytes| {
        const body = @import("../internal/body.zig").Body.fromBytes(allocator, body_bytes) catch {
            return HttpFetchError.OutOfMemory;
        };
        response.body = body;
    }

    // Step 4: Record timing information
    const end_time = getCurrentTimeMs();
    params.timing_info.final_network_response_start_time = start_time + @as(f64, @floatFromInt(network_response.time_to_first_byte_ms));
    params.timing_info.end_time = end_time;

    return response;
}

/// Build a NetworkRequest from an InternalRequest, with `added` after its own
/// headers - their values owned, and the NetworkRequest's once this returns
/// (on error, still the caller's).
fn buildNetworkRequest(allocator: Allocator, request: *InternalRequest, added: []const NetworkRequest.Header) !NetworkRequest {
    // Get headers from header list using iterator()
    const header_entries = request.header_list.iterator();

    // Allocate headers array
    const headers = try allocator.alloc(NetworkRequest.Header, header_entries.len + added.len);
    errdefer allocator.free(headers);
    const owned_values = try allocator.alloc([]const u8, added.len);
    errdefer allocator.free(owned_values);
    for (added, 0..) |header, i| owned_values[i] = header.value;

    for (header_entries, 0..) |header, i| {
        headers[i] = .{
            .name = header.name,
            .value = header.value,
        };
    }
    for (added, 0..) |header, i| headers[header_entries.len + i] = header;

    // Get body bytes if present
    const body: ?[]const u8 = if (request.body) |b| switch (b) {
        .bytes => |bytes| bytes,
        .body => |body_obj| body_obj.getBytes(),
    } else null;

    return NetworkRequest{
        .url = request.currentUrl(),
        .method = request.method,
        .headers = headers,
        .body = body,
        // HTTP/2 where TLS negotiates it, HTTP/1.1 otherwise.
        .http_version = .http_2,
        .connect_timeout_ms = 30_000,
        .timeout_ms = 0, // No timeout by default
        .follow_redirects = false, // WHATWG Fetch handles redirects
        .max_redirects = 20,
        .proxy = null, // TODO: Get from request/settings
        // Whatever the embedder registered, which is `verify_peer` and
        // `verify_host` against the system trust store unless it said otherwise.
        .cert_options = network.defaultCertOptions(),
        .verbose = false,
        .owned_values = owned_values,
    };
}

/// Free allocated NetworkRequest resources.
pub fn freeNetworkRequest(allocator: Allocator, request: NetworkRequest) void {
    allocator.free(request.headers);
    for (request.owned_values) |value| allocator.free(value);
    allocator.free(request.owned_values);
}

/// CORS check result.
pub const CorsCheckResult = enum {
    success,
    failure,
};

/// Fetch "CORS check" for `request` and `response`.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-cors-check
pub fn corsCheck(allocator: Allocator, request: *InternalRequest, response: *InternalResponse) !CorsCheckResult {
    // 1. Let origin be the result of getting `Access-Control-Allow-Origin`
    //    from response's header list (every value, combined: two of them are
    //    "a, b", which matches nothing).
    const origin = (try response.header_list.get(allocator, "Access-Control-Allow-Origin")) orelse {
        // 2. If origin is null, then return failure.
        return .failure;
    };
    defer allocator.free(origin);
    // 3. If request's credentials mode is not "include" and origin is `*`,
    //    then return success.
    if (request.credentials_mode != .include and std.mem.eql(u8, origin, "*")) return .success;
    // 4. If the result of byte-serializing a request origin with request is
    //    not origin, then return failure.
    const serialized = try request.serializeOrigin(allocator);
    defer allocator.free(serialized);
    if (!std.mem.eql(u8, serialized, origin)) return .failure;
    // 5. If request's credentials mode is not "include", then return
    //    success.
    if (request.credentials_mode != .include) return .success;
    // 6. Let credentials be the result of getting
    //    `Access-Control-Allow-Credentials` from response's header list.
    const credentials = (try response.header_list.get(allocator, "Access-Control-Allow-Credentials")) orelse return .failure;
    defer allocator.free(credentials);
    // 7. If credentials is `true`, then return success.
    if (std.mem.eql(u8, credentials, "true")) return .success;
    // 8. Return failure.
    return .failure;
}

/// Check if response is a network error.
fn isNetworkError(response: *InternalResponse) bool {
    return response.response_type == .@"error" or response.status == 0;
}

/// Get current time in milliseconds (DOMHighResTimeStamp format).
pub fn getCurrentTimeMs() f64 {
    return @as(f64, @floatFromInt(clock.wallSeconds())) * 1000.0;
}

// =============================================================================
// CORS-preflight fetch
// =============================================================================

/// HTTP fetch step 4.1's condition, given makeCORSPreflight: does `request`
/// need a CORS-preflight fetch first? With no CORS-preflight cache there is
/// never a cache entry match, so: its method is not CORS-safelisted or its
/// use-CORS-preflight flag is set, or it has a CORS-unsafe request-header
/// name.
pub fn corsPreflightNeeded(allocator: Allocator, request: *const InternalRequest) !bool {
    if (request.use_cors_preflight or !isCorsSafelistedMethod(request.method)) return true;
    const unsafe_names = try validation.getCORSUnsafeRequestHeaderNames(allocator, &request.header_list);
    defer freeNames(allocator, unsafe_names);
    return unsafe_names.len > 0;
}

/// CORS-preflight fetch, steps 1-6 up to the network: the preflight request,
/// for the network to answer. `corsPreflightFetchFinish` takes the answer.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-preflight-fetch-0
pub fn corsPreflightFetchStart(allocator: Allocator, request: *InternalRequest) HttpFetchError!NetworkRequest {
    return buildPreflightRequest(allocator, request) catch HttpFetchError.OutOfMemory;
}

fn buildPreflightRequest(allocator: Allocator, request: *InternalRequest) !NetworkRequest {
    // 1. preflight: method `OPTIONS`, request's URL list, origin and
    //    referrer; mode "cors" and response tainting "cors" - so its
    //    `Origin` header is request's origin, byte-serialized (step 8.12 of
    //    the HTTP-network-or-cache fetch step 6 runs).
    var owned: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer {
        for (owned.items) |value| allocator.free(value);
        owned.deinit(allocator);
    }
    var headers: std.ArrayListUnmanaged(NetworkRequest.Header) = .empty;
    errdefer headers.deinit(allocator);

    // 2. Append (`Accept`, `*/*`).
    try headers.append(allocator, .{ .name = "Accept", .value = "*/*" });
    // 3. Append (`Access-Control-Request-Method`, request's method).
    try headers.append(allocator, .{ .name = "Access-Control-Request-Method", .value = request.method });
    // 4-5. The CORS-unsafe request-header names with request's header list,
    //      if any, separated by `,` - not combined: no 0x20 after 0x2C.
    const unsafe_names = try validation.getCORSUnsafeRequestHeaderNames(allocator, &request.header_list);
    defer freeNames(allocator, unsafe_names);
    if (unsafe_names.len > 0) {
        const value = try std.mem.join(allocator, ",", unsafe_names);
        owned.append(allocator, value) catch |err| {
            allocator.free(value);
            return err;
        };
        try headers.append(allocator, .{ .name = "Access-Control-Request-Headers", .value = value });
    }
    // The preflight's referrer is request's (which main fetch step 9 has
    // determined): HTTP-network-or-cache fetch 8.11 sends it as `Referer`.
    if (request.referrer == .url) {
        const referer = try allocator.dupe(u8, request.referrer.url);
        owned.append(allocator, referer) catch |err| {
            allocator.free(referer);
            return err;
        };
        try headers.append(allocator, .{ .name = "Referer", .value = referer });
    }
    if (request.origin != .client) {
        const origin = try request.serializeOrigin(allocator);
        owned.append(allocator, origin) catch |err| {
            allocator.free(origin);
            return err;
        };
        try headers.append(allocator, .{ .name = "Origin", .value = origin });
    }
    // 8.15 runs for the preflight too: its header list has no User-Agent.
    try headers.append(allocator, .{ .name = "User-Agent", .value = default_user_agent });

    const header_slice = try headers.toOwnedSlice(allocator);
    errdefer allocator.free(header_slice);
    const owned_values = try owned.toOwnedSlice(allocator);
    return .{
        .url = request.currentUrl(),
        .method = "OPTIONS",
        .headers = header_slice,
        .body = null,
        .http_version = .http_2,
        .follow_redirects = false,
        .cert_options = network.defaultCertOptions(),
        .owned_values = owned_values,
    };
}

/// CORS-preflight fetch step 7, once the network answered the preflight
/// with `network_response`: whether it lets `request` go - false is step 8's
/// network error. With no CORS-preflight cache, steps 8-15 have nothing to
/// store.
pub fn corsPreflightFetchFinish(allocator: Allocator, request: *InternalRequest, network_response: *const NetworkResponse) HttpFetchError!bool {
    // Every error on the way is an allocation failing.
    return preflightAllows(allocator, request, network_response) catch HttpFetchError.OutOfMemory;
}

fn preflightAllows(allocator: Allocator, request: *InternalRequest, network_response: *const NetworkResponse) !bool {
    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    response.status = network_response.status;
    for (network_response.headers) |header| try response.header_list.append(header.name, header.value);

    // 7. If a CORS check for request (not preflight: request's credentials
    //    mode is the one that counts) and response returns success and
    //    response's status is an ok status:
    if (try corsCheck(allocator, request, response) == .failure) return false;
    if (!internal_response.isOkStatus(response.status)) return false;

    // 1-3. methods and headerNames: the `Access-Control-Allow-Methods` and
    //      `Access-Control-Allow-Headers` values; failure is a network error.
    const listed_methods = tokenList(allocator, response, "Access-Control-Allow-Methods") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.NotATokenList => return false,
    };
    const methods_null = listed_methods == null;
    var methods = listed_methods orelse TokenList{};
    defer methods.deinit(allocator);
    var header_names = (tokenList(allocator, response, "Access-Control-Allow-Headers") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.NotATokenList => return false,
    }) orelse TokenList{};
    defer header_names.deinit(allocator);

    // 4. If methods is null and request's use-CORS-preflight flag is set,
    //    methods is « request's method ».
    const method_listed = if (methods_null and request.use_cors_preflight) true else methods.containsExact(request.method);

    const include = request.credentials_mode == .include;
    // 5. If request's method is not in methods, is not a CORS-safelisted
    //    method, and request's credentials mode is "include" or methods does
    //    not contain `*`: a network error.
    if (!method_listed and !isCorsSafelistedMethod(request.method) and (include or !methods.containsExact("*"))) return false;

    // 6. A CORS non-wildcard request-header name (`Authorization`) in
    //    request's header list must be in headerNames, `*` or not.
    for (request.header_list.entries.items) |header| {
        if (validation.isCORSNonWildcardRequestHeaderName(header.name) and !header_names.containsIgnoreCase(header.name)) return false;
    }

    // 7. Each CORS-unsafe request-header name must be in headerNames, or
    //    headerNames contain `*` and request's credentials mode not be
    //    "include".
    const unsafe_names = try validation.getCORSUnsafeRequestHeaderNames(allocator, &request.header_list);
    defer freeNames(allocator, unsafe_names);
    for (unsafe_names) |name| {
        if (!header_names.containsIgnoreCase(name) and (include or !header_names.containsExact("*"))) return false;
    }

    // 8-16. max-age and the cache: there is no CORS-preflight cache ("If
    //       the user agent does not provide for a cache, then return
    //       response").
    return true;
}

/// A header's list of tokens (Fetch "extracting header list values" for a
/// #method or #field-name header): slices of `combined`, which it owns.
const TokenList = struct {
    combined: []const u8 = "",
    items: std.ArrayListUnmanaged([]const u8) = .empty,

    fn deinit(self: *TokenList, allocator: Allocator) void {
        self.items.deinit(allocator);
        allocator.free(self.combined);
    }

    fn containsExact(self: *const TokenList, value: []const u8) bool {
        for (self.items.items) |item| if (std.mem.eql(u8, item, value)) return true;
        return false;
    }

    fn containsIgnoreCase(self: *const TokenList, value: []const u8) bool {
        for (self.items.items) |item| if (std.ascii.eqlIgnoreCase(item, value)) return true;
        return false;
    }
};

/// `name`'s values in `response`'s header list as a token list: null when
/// there is no such header, error.NotATokenList for the spec's failure.
fn tokenList(allocator: Allocator, response: *InternalResponse, name: []const u8) error{ OutOfMemory, NotATokenList }!?TokenList {
    const combined = (try response.header_list.get(allocator, name)) orelse return null;
    var list: TokenList = .{ .combined = combined };
    errdefer list.deinit(allocator);
    var it = std.mem.splitScalar(u8, combined, ',');
    while (it.next()) |raw| {
        const item = std.mem.trim(u8, raw, " \t");
        if (item.len == 0) continue;
        if (!validation.isValidHeaderName(item)) return error.NotATokenList;
        try list.items.append(allocator, item);
    }
    return list;
}

fn freeNames(allocator: Allocator, names: []const []const u8) void {
    for (names) |name| allocator.free(name);
    allocator.free(names);
}

/// A CORS-safelisted method: `GET`, `HEAD` or `POST`.
fn isCorsSafelistedMethod(method: []const u8) bool {
    return std.mem.eql(u8, method, "GET") or std.mem.eql(u8, method, "HEAD") or std.mem.eql(u8, method, "POST");
}

// =============================================================================
// Tests
// =============================================================================

test "corsCheck - wildcard origin without credentials" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://other.com");
    request.credentials_mode = .omit;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "*");

    try std.testing.expectEqual(CorsCheckResult.success, try corsCheck(allocator, request, response));
}

test "corsCheck - wildcard origin with credentials fails" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://other.com");
    request.credentials_mode = .include;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "*");

    try std.testing.expectEqual(CorsCheckResult.failure, try corsCheck(allocator, request, response));
}

test "corsCheck - matching origin" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://example.com");
    request.credentials_mode = .omit;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "https://example.com");

    try std.testing.expectEqual(CorsCheckResult.success, try corsCheck(allocator, request, response));
}

test "corsCheck - non-matching origin" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://other.com");
    request.credentials_mode = .omit;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "https://example.com");

    try std.testing.expectEqual(CorsCheckResult.failure, try corsCheck(allocator, request, response));
}

test "corsCheck - credentials with allow-credentials header" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://example.com");
    request.credentials_mode = .include;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "https://example.com");
    try response.header_list.append("Access-Control-Allow-Credentials", "true");

    try std.testing.expectEqual(CorsCheckResult.success, try corsCheck(allocator, request, response));
}

test "corsCheck - missing allow-origin header" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://example.com");

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    try std.testing.expectEqual(CorsCheckResult.failure, try corsCheck(allocator, request, response));
}

test "corsCheck - every Access-Control-Allow-Origin is one value, and credentials must be exactly true" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    try request.setOrigin("https://other.com");
    request.credentials_mode = .include;

    const two = try InternalResponse.init(allocator);
    defer two.deinit();
    try two.header_list.append("Access-Control-Allow-Origin", "https://other.com");
    try two.header_list.append("Access-Control-Allow-Origin", "https://other.com");
    try two.header_list.append("Access-Control-Allow-Credentials", "true");
    try std.testing.expectEqual(CorsCheckResult.failure, try corsCheck(allocator, request, two));

    const upper = try InternalResponse.init(allocator);
    defer upper.deinit();
    try upper.header_list.append("Access-Control-Allow-Origin", "https://other.com");
    try upper.header_list.append("Access-Control-Allow-Credentials", "TRUE");
    try std.testing.expectEqual(CorsCheckResult.failure, try corsCheck(allocator, request, upper));
}

test "corsCheck - after a redirect elsewhere the request origin is null" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "http://a.test/");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    try request.addUrl("http://b.test/");
    try request.addUrl("http://c.test/");

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "http://a.test");
    try std.testing.expectEqual(CorsCheckResult.failure, try corsCheck(allocator, request, response));

    const nulled = try InternalResponse.init(allocator);
    defer nulled.deinit();
    try nulled.header_list.append("Access-Control-Allow-Origin", "null");
    try std.testing.expectEqual(CorsCheckResult.success, try corsCheck(allocator, request, nulled));
}

test "isNetworkError" {
    const allocator = std.testing.allocator;

    const error_response = try internal_response.networkError(allocator);
    defer error_response.deinit();
    try std.testing.expect(isNetworkError(error_response));

    const ok_response = try InternalResponse.init(allocator);
    defer ok_response.deinit();
    ok_response.status = 200;
    try std.testing.expect(!isNetworkError(ok_response));
}

test "redirectBecomesGet - HTTP-redirect fetch step 12" {
    try std.testing.expect(redirectBecomesGet(301, "POST"));
    try std.testing.expect(redirectBecomesGet(302, "POST"));
    try std.testing.expect(!redirectBecomesGet(302, "PUT"));
    try std.testing.expect(redirectBecomesGet(303, "PUT"));
    try std.testing.expect(redirectBecomesGet(303, "POST"));
    try std.testing.expect(!redirectBecomesGet(303, "GET"));
    try std.testing.expect(!redirectBecomesGet(303, "HEAD"));
    try std.testing.expect(!redirectBecomesGet(307, "POST"));
    try std.testing.expect(!redirectBecomesGet(308, "POST"));
}

test "sameHttpOrigin - scheme, host and port, ignoring userinfo and path" {
    try std.testing.expect(sameHttpOrigin("http://a.test/x", "http://a.test/y?z#w"));
    try std.testing.expect(sameHttpOrigin("http://u:p@a.test:81/x", "http://a.test:81/"));
    try std.testing.expect(!sameHttpOrigin("http://a.test/", "https://a.test/"));
    try std.testing.expect(!sameHttpOrigin("http://a.test/", "http://b.test/"));
    try std.testing.expect(!sameHttpOrigin("http://a.test:81/", "http://a.test/"));
}

test "locationUrl - relative, absolute, missing, duplicated, and the inherited fragment" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    response.status = 302;
    try response.addUrl("http://a.test/dir/page?q");

    // No Location: null (step 4 of HTTP-redirect fetch returns the response).
    try std.testing.expect((try locationUrl(allocator, response, "http://a.test/dir/page")) == null);

    // Path-relative, resolved against the RESPONSE's URL, and given the
    // request's fragment because it has none of its own.
    try response.header_list.append("Location", "next");
    const rel = (try locationUrl(allocator, response, "http://a.test/dir/page#frag")).?;
    defer allocator.free(rel);
    try std.testing.expectEqualStrings("http://a.test/dir/next#frag", rel);

    // Two Location headers: failure.
    try response.header_list.append("Location", "/other");
    try std.testing.expectError(error.InvalidLocation, locationUrl(allocator, response, "http://a.test/"));

    // Not a redirect status: null, whatever the headers say.
    response.status = 200;
    try std.testing.expect((try locationUrl(allocator, response, "http://a.test/")) == null);
}

test "HTTP fetch step 4.4: a CORS-tainted response - a 304 too - must pass the CORS check" {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.response_tainting = .cors;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    // A 304 without `Access-Control-Allow-Origin`: a network error.
    const not_modified = try InternalResponse.init(allocator);
    not_modified.status = 304;
    try std.testing.expectError(HttpFetchError.CorsError, httpFetchFinish(allocator, params, .{}, not_modified));

    // With it: the response.
    const allowed = try InternalResponse.init(allocator);
    allowed.status = 304;
    try allowed.header_list.append("Access-Control-Allow-Origin", "http://a.test");
    const next = try httpFetchFinish(allocator, params, .{}, allowed);
    try std.testing.expect(next.response == allowed);
    allowed.deinit();

    // A "basic" response is not checked.
    request.response_tainting = .basic;
    const basic = try InternalResponse.init(allocator);
    const basic_next = try httpFetchFinish(allocator, params, .{}, basic);
    try std.testing.expect(basic_next.response == basic);
    basic.deinit();
}

test "append a request Origin header: cors and websocket always, other GET/HEAD never, the rest by referrer policy" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();

    // Still "client": none.
    try std.testing.expect((try requestOriginHeader(allocator, request)) == null);

    try request.setOrigin("https://a.test");
    request.response_tainting = .cors;
    request.mode = .cors;
    {
        const value = (try requestOriginHeader(allocator, request)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings("https://a.test", value);
    }

    // A same-origin GET: none.
    request.response_tainting = .basic;
    try std.testing.expect((try requestOriginHeader(allocator, request)) == null);

    // A POST in cors mode: the origin, whatever the referrer policy.
    try request.setMethod("POST");
    request.referrer_policy = .no_referrer;
    {
        const value = (try requestOriginHeader(allocator, request)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings("https://a.test", value);
    }

    // A no-cors POST: "no-referrer" hides it, and so does a downgrade from
    // https under "strict-origin-when-cross-origin"; "unsafe-url" does not.
    request.mode = .no_cors;
    {
        const value = (try requestOriginHeader(allocator, request)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings("null", value);
    }
    request.referrer_policy = .strict_origin_when_cross_origin;
    {
        const value = (try requestOriginHeader(allocator, request)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings("null", value);
    }
    request.referrer_policy = .unsafe_url;
    {
        const value = (try requestOriginHeader(allocator, request)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings("https://a.test", value);
    }
}

test "HTTP-network-or-cache fetch sends the Origin header without adding it to the request" {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .cors;
    request.response_tainting = .cors;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const started = try httpNetworkOrCacheFetchStart(allocator, params, .{});
    const network_request = started.network;
    defer freeNetworkRequest(allocator, network_request);
    var origin: ?[]const u8 = null;
    for (network_request.headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "Origin")) origin = header.value;
    }
    try std.testing.expectEqualStrings("http://a.test", origin.?);
    try std.testing.expect(!request.header_list.contains("Origin"));
}

test "includeCredentials: include always, same-origin only while tainting is basic, omit never" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    request.credentials_mode = .same_origin;
    try std.testing.expect(httpNetworkFetchUsesCookies(request));
    request.response_tainting = .cors;
    try std.testing.expect(!httpNetworkFetchUsesCookies(request));
    request.credentials_mode = .include;
    try std.testing.expect(httpNetworkFetchUsesCookies(request));
    request.credentials_mode = .omit;
    request.response_tainting = .basic;
    try std.testing.expect(!httpNetworkFetchUsesCookies(request));
}

test "CORS-preflight fetch: an OPTIONS request with the method, the unsafe header names and the origin" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    try request.setReferrerUrl("http://a.test/page");
    try request.setMethod("PUT");
    try request.header_list.append("X-B", "1");
    try request.header_list.append("Content-Type", "text/plain");
    try request.header_list.append("x-a", "2");

    try std.testing.expect(try corsPreflightNeeded(allocator, request));
    const preflight = try corsPreflightFetchStart(allocator, request);
    defer freeNetworkRequest(allocator, preflight);
    try std.testing.expectEqualStrings("OPTIONS", preflight.method);
    try std.testing.expectEqualStrings("http://b.test/x", preflight.url);
    const expected = [_][2][]const u8{
        .{ "Accept", "*/*" },
        .{ "Access-Control-Request-Method", "PUT" },
        // Sorted, lowercased, joined by a bare comma.
        .{ "Access-Control-Request-Headers", "x-a,x-b" },
        .{ "Referer", "http://a.test/page" },
        .{ "Origin", "http://a.test" },
        .{ "User-Agent", default_user_agent },
    };
    try std.testing.expectEqual(expected.len, preflight.headers.len);
    for (expected, preflight.headers) |want, got| {
        try std.testing.expectEqualStrings(want[0], got.name);
        try std.testing.expectEqualStrings(want[1], got.value);
    }
}

fn preflightAnswer(status: u16, headers: []NetworkResponse.Header) NetworkResponse {
    return .{
        .allocator = std.testing.allocator,
        .status = status,
        .http_version = .http_1_1,
        .headers = headers,
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

test "CORS-preflight fetch step 7: the answer must allow the origin, the method and every unsafe header" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    try request.setMethod("PUT");
    try request.header_list.append("X-A", "1");

    var allowed = [_]NetworkResponse.Header{
        .{ .name = "Access-Control-Allow-Origin", .value = "http://a.test" },
        .{ .name = "Access-Control-Allow-Methods", .value = "GET, PUT" },
        .{ .name = "Access-Control-Allow-Headers", .value = "x-a" },
    };
    try std.testing.expect(try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &allowed)));
    // Not an ok status.
    try std.testing.expect(!try corsPreflightFetchFinish(allocator, request, &preflightAnswer(302, &allowed)));

    // No such method; methods compare byte for byte.
    var wrong_case = [_]NetworkResponse.Header{
        .{ .name = "Access-Control-Allow-Origin", .value = "http://a.test" },
        .{ .name = "Access-Control-Allow-Methods", .value = "put" },
        .{ .name = "Access-Control-Allow-Headers", .value = "X-A" },
    };
    try std.testing.expect(!try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &wrong_case)));

    // A header left out; then `*`, which serves without credentials only.
    var wildcard = [_]NetworkResponse.Header{
        .{ .name = "Access-Control-Allow-Origin", .value = "http://a.test" },
        .{ .name = "Access-Control-Allow-Methods", .value = "*" },
        .{ .name = "Access-Control-Allow-Headers", .value = "*" },
        .{ .name = "Access-Control-Allow-Credentials", .value = "true" },
    };
    try std.testing.expect(try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &wildcard)));
    request.credentials_mode = .include;
    try std.testing.expect(!try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &wildcard)));
    request.credentials_mode = .same_origin;

    // `Authorization` is never covered by `*`.
    try request.header_list.append("Authorization", "x");
    try std.testing.expect(!try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &wildcard)));

    // A value that is not a token list is failure.
    var broken = [_]NetworkResponse.Header{
        .{ .name = "Access-Control-Allow-Origin", .value = "http://a.test" },
        .{ .name = "Access-Control-Allow-Methods", .value = "PUT, not a token" },
    };
    try std.testing.expect(!try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &broken)));
}

test "CORS-preflight fetch step 7.4: with the use-CORS-preflight flag, no Allow-Methods allows request's method" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    try request.setMethod("PUT");
    var bare = [_]NetworkResponse.Header{
        .{ .name = "Access-Control-Allow-Origin", .value = "*" },
    };
    try std.testing.expect(!try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &bare)));
    request.use_cors_preflight = true;
    try std.testing.expect(try corsPreflightFetchFinish(allocator, request, &preflightAnswer(200, &bare)));
}

test "HTTP-network-or-cache fetch step 14: a 401 to a stream upload from a window is a network error" {
    const allocator = std.testing.allocator;
    const Body = @import("../internal/body.zig").Body;

    var window_token: u8 = 0;
    const request = try InternalRequest.init(allocator, "https://a.test/upload");
    defer request.deinit();
    try request.setOrigin("https://a.test");
    try request.setMethod("POST");
    request.traversable_for_user_prompts = .{ .traversable = &window_token };
    request.body = .{ .body = try Body.fromSource(allocator, .none, 0) };

    // A 401: the body cannot be sent again for the credentials a prompt
    // would ask for, so a network error.
    const unauthorized = try InternalResponse.init(allocator);
    unauthorized.status = 401;
    const refused = try httpNetworkOrCacheFetchFinish(allocator, request, unauthorized);
    defer refused.deinit();
    try std.testing.expect(isNetworkError(refused));

    // Any other status goes on as it is.
    const ok = try InternalResponse.init(allocator);
    ok.status = 200;
    const kept = try httpNetworkOrCacheFetchFinish(allocator, request, ok);
    try std.testing.expect(kept == ok);
    kept.deinit();

    // With no traversable to prompt in (a worker's request), the 401 stands.
    request.traversable_for_user_prompts = .no_traversable;
    const worker_401 = try InternalResponse.init(allocator);
    worker_401.status = 401;
    const stands = try httpNetworkOrCacheFetchFinish(allocator, request, worker_401);
    try std.testing.expect(stands == worker_401);
    stands.deinit();

    // Nor for a CORS request, or one without credentials.
    request.traversable_for_user_prompts = .{ .traversable = &window_token };
    request.response_tainting = .cors;
    const cors_401 = try InternalResponse.init(allocator);
    cors_401.status = 401;
    const cors_kept = try httpNetworkOrCacheFetchFinish(allocator, request, cors_401);
    try std.testing.expect(cors_kept == cors_401);
    cors_kept.deinit();
}

test "HTTP-redirect fetch step 19: a redirect's Referrer-Policy becomes the request's" {
    const allocator = std.testing.allocator;
    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try std.testing.expect((try referrerPolicyOf(allocator, response)) == null);
    try response.header_list.append("Referrer-Policy", "no-referrer, bogus");
    try response.header_list.append("Referrer-Policy", "origin");
    try std.testing.expectEqual(internal_request.ReferrerPolicy.origin, (try referrerPolicyOf(allocator, response)).?);
}

test "HTTP-network-or-cache fetch step 8.11: a URL referrer is sent as Referer, before Origin" {
    const allocator = std.testing.allocator;
    const FetchController = @import("../internal/fetch_controller.zig").FetchController;
    const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;

    const request = try InternalRequest.init(allocator, "http://b.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    try request.setReferrerUrl("http://a.test/page");
    request.mode = .cors;
    request.response_tainting = .cors;
    const controller = try FetchController.init(allocator);
    defer controller.deinit();
    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    const started = try httpNetworkOrCacheFetchStart(allocator, params, .{});
    const network_request = started.network;
    defer freeNetworkRequest(allocator, network_request);
    var referer_at: ?usize = null;
    var origin_at: ?usize = null;
    for (network_request.headers, 0..) |header, i| {
        if (std.mem.eql(u8, header.name, "Referer")) {
            referer_at = i;
            try std.testing.expectEqualStrings("http://a.test/page", header.value);
        }
        if (std.mem.eql(u8, header.name, "Origin")) origin_at = i;
    }
    try std.testing.expect(referer_at.? < origin_at.?);
    try std.testing.expect(!request.header_list.contains("Referer"));
}

test "HTTP-network-or-cache fetch step 8: User-Agent, a null body's Content-Length, and the cache headers" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setMethod("POST");
    request.cache_mode = .no_store;
    try request.header_list.append("Range", "bytes=0-1");

    var added: std.ArrayListUnmanaged(NetworkRequest.Header) = .empty;
    defer {
        for (added.items) |h| allocator.free(h.value);
        added.deinit(allocator);
    }
    try httpRequestHeaders(allocator, request, &added);
    const want = [_][2][]const u8{
        .{ "Content-Length", "0" },
        .{ "User-Agent", default_user_agent },
        .{ "Pragma", "no-cache" },
        .{ "Cache-Control", "no-cache" },
        .{ "Accept-Encoding", "identity" },
    };
    try std.testing.expectEqual(want.len, added.items.len);
    for (want, added.items) |w, got| {
        try std.testing.expectEqualStrings(w[0], got.name);
        try std.testing.expectEqualStrings(w[1], got.value);
    }

    // A request's own User-Agent and Cache-Control stand; a conditional
    // request in "default" mode is "no-store".
    for (added.items) |h| allocator.free(h.value);
    added.clearRetainingCapacity();
    try request.setMethod("GET");
    request.cache_mode = .default;
    request.header_list.delete("Range");
    try request.header_list.append("User-Agent", "mine");
    try request.header_list.append("If-None-Match", "x");
    try httpRequestHeaders(allocator, request, &added);
    try std.testing.expectEqual(2, added.items.len);
    try std.testing.expectEqualStrings("Pragma", added.items[0].name);
    try std.testing.expectEqualStrings("Cache-Control", added.items[1].name);
}
