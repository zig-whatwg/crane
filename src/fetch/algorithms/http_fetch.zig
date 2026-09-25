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
const LibcurlBackend = network.LibcurlBackend;
const CurlCookieManager = network.curl_cookies.CurlCookieManager;
const cors = @import("../cors/root.zig");
const clock = @import("clock");
const PreflightCache = cors.PreflightCache;

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
    /// CORS flag - set if this is a CORS request
    cors_flag: bool = false,
    /// CORS-preflight flag - set if preflight should be performed
    cors_preflight_flag: bool = false,
    /// Cookie manager for credentials handling (optional)
    /// If null, LibcurlBackend creates its own cookie manager.
    /// Cookies are handled automatically by libcurl when attached.
    cookie_manager: ?*CurlCookieManager = null,
    /// Preflight cache for CORS preflight requests (optional)
    preflight_cache: ?*PreflightCache = null,
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

    // Step 5: CORS check
    if (options.cors_flag and !isNetworkError(final_response)) {
        const cors_result = corsCheck(request, final_response);
        if (cors_result == .failure) {
            final_response.deinit();
            return HttpFetchError.CorsError;
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

    // Everything below needs only the status, so read it before letting the
    // redirect response go.
    const status = response.status;
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

    // Steps 9-10 compare request's origin with locationURL's and check
    // response tainting. Neither is populated on this path yet - main fetch
    // does not compute tainting and callers leave origin as "client" - so they
    // cannot be evaluated here without guessing.
    // TODO: steps 9-10 once main fetch step 12 sets response tainting.

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

    // Step 19: set request's referrer policy on redirect.
    // TODO: needs the response's `Referrer-Policy` header parsed; the policy
    // is left unchanged until then.

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

    // CORS preflight per Fetch spec §4.8 step 8
    // If CORS-preflight flag is set, perform preflight before actual request
    //
    // Main fetch sets no CORS flags yet, so nothing reaches this. When it
    // does, the preflight has to become a network step of its own, like the
    // request below: as it stands it blocks.
    if (options.cors_preflight_flag) {
        const preflight_result = performCorsPreflight(allocator, request, options) catch {
            return HttpFetchError.OutOfMemory;
        };

        switch (preflight_result) {
            .success => {
                // Preflight succeeded, continue with actual request
            },
            .failure => {
                // Preflight failed
                return HttpFetchError.CorsError;
            },
        }
    }

    // HTTP-network fetch, step 1: Build NetworkRequest from InternalRequest
    const network_request = buildNetworkRequest(allocator, request) catch {
        return HttpFetchError.OutOfMemory;
    };
    return .{ .network = network_request };
}

/// Whether HTTP-network fetch sends and stores cookies for `request`: unless
/// its credentials mode is "omit". Cookie handling itself is libcurl's, through
/// CurlCookieManager - it sends the matching cookies (Fetch spec §4.9 step 5)
/// and stores the `Set-Cookie` ones (step 11).
pub fn httpNetworkFetchUsesCookies(request: *const InternalRequest) bool {
    return request.credentials_mode != .omit;
}

/// HTTP-network fetch, once the network has answered with `network_response`
/// (sent at `start_time`): the response it returns.
///
/// Per Fetch spec §4.9:
/// 3. Convert NetworkResponse to InternalResponse
/// 4. Record timing information
pub fn httpNetworkFetchFinish(
    allocator: Allocator,
    params: *FetchParams,
    network_response: *const NetworkResponse,
    start_time: f64,
) HttpFetchError!*InternalResponse {
    const request = params.request;

    // Step 3: Convert NetworkResponse to InternalResponse
    const response = InternalResponse.init(allocator) catch {
        return HttpFetchError.OutOfMemory;
    };
    errdefer response.deinit();

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

    // Set status code
    response.status = network_response.status;

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

/// Build a NetworkRequest from an InternalRequest.
fn buildNetworkRequest(allocator: Allocator, request: *InternalRequest) !NetworkRequest {
    // Get headers from header list using iterator()
    const header_entries = request.header_list.iterator();

    // Allocate headers array
    const headers = try allocator.alloc(NetworkRequest.Header, header_entries.len);
    errdefer allocator.free(headers);

    for (header_entries, 0..) |header, i| {
        headers[i] = .{
            .name = header.name,
            .value = header.value,
        };
    }

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
        .http_version = .http_1_1, // Default to HTTP/1.1
        .connect_timeout_ms = 30_000,
        .timeout_ms = 0, // No timeout by default
        .follow_redirects = false, // WHATWG Fetch handles redirects
        .max_redirects = 20,
        .proxy = null, // TODO: Get from request/settings
        // Whatever the embedder registered, which is `verify_peer` and
        // `verify_host` against the system trust store unless it said otherwise.
        .cert_options = network.defaultCertOptions(),
        .verbose = false,
    };
}

/// Free allocated NetworkRequest resources.
pub fn freeNetworkRequest(allocator: Allocator, request: NetworkRequest) void {
    allocator.free(request.headers);
}

/// CORS check result.
pub const CorsCheckResult = enum {
    success,
    failure,
};

/// Perform CORS check on response.
///
/// Per Fetch spec §4.10:
/// 1. Let origin be request's origin
/// 2. Let credentials be true if request's credentials mode is "include"
/// 3. Check Access-Control-Allow-Origin header
/// 4. If credentials, check Access-Control-Allow-Credentials header
pub fn corsCheck(request: *InternalRequest, response: *InternalResponse) CorsCheckResult {
    // Get Access-Control-Allow-Origin header
    // Use getFirstValue to get single header value without allocation
    const allow_origin = response.header_list.getFirstValue("Access-Control-Allow-Origin") orelse {
        return .failure;
    };

    // Check if origin matches
    if (std.mem.eql(u8, allow_origin, "*")) {
        // Wildcard - check credentials mode
        if (request.credentials_mode == .include) {
            // Wildcard with credentials is not allowed
            return .failure;
        }
        return .success;
    }

    // Get request origin
    const request_origin = switch (request.origin) {
        .client => return .failure, // Can't CORS check with client origin
        .origin => |o| o,
    };

    // Compare origins (case-sensitive)
    if (!std.mem.eql(u8, allow_origin, request_origin)) {
        return .failure;
    }

    // Check credentials if needed
    if (request.credentials_mode == .include) {
        const allow_credentials = response.header_list.getFirstValue("Access-Control-Allow-Credentials") orelse {
            return .failure;
        };
        if (!std.ascii.eqlIgnoreCase(allow_credentials, "true")) {
            return .failure;
        }
    }

    return .success;
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
// CORS Preflight Integration
// =============================================================================

/// Perform CORS preflight request using real network.
///
/// Per Fetch spec §4.8 step 8:
/// "If CORS-preflight flag is set, then run CORS-preflight fetch"
///
/// This function:
/// 1. Checks preflight cache for existing valid entry
/// 2. If not cached, performs OPTIONS request via LibcurlBackend
/// 3. Validates response and caches successful preflights
fn performCorsPreflight(
    allocator: Allocator,
    request: *InternalRequest,
    options: HttpFetchOptions,
) !cors.PreflightResult {
    // Get request origin
    const origin = switch (request.origin) {
        .client => return .{ .failure = .cors_check_failed },
        .origin => |o| o,
    };

    const url = request.currentUrl();

    // Check preflight cache first
    if (options.preflight_cache) |cache| {
        if (cache.match(origin, url, origin)) |entry| {
            // Validate cached entry allows this request
            if (entry.isMethodAllowed(request.method)) {
                // Check headers
                const header_entries = request.header_list.iterator();
                var all_headers_allowed = true;
                for (header_entries) |header| {
                    if (!cors.isCorseSafelistedRequestHeader(header.name, header.value)) {
                        if (!entry.isHeaderAllowed(header.name)) {
                            all_headers_allowed = false;
                            break;
                        }
                    }
                }
                if (all_headers_allowed) {
                    // Cache hit - preflight allowed
                    return .{
                        .success = .{
                            .allocator = allocator,
                            .methods = .empty,
                            .headers = .empty,
                            .methods_wildcard = entry.methods_wildcard,
                            .headers_wildcard = entry.headers_wildcard,
                            .expiry_time = entry.expiry_time,
                        },
                    };
                }
            }
        }
    }

    // No valid cache entry - perform preflight request

    // Get unsafe header names
    const header_entries = request.header_list.iterator();
    var header_names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer header_names.deinit(allocator);
    var header_values: std.ArrayListUnmanaged([]const u8) = .empty;
    defer header_values.deinit(allocator);

    for (header_entries) |header| {
        try header_names.append(allocator, header.name);
        try header_values.append(allocator, header.value);
    }

    const unsafe_headers = try cors.getCorsUnsafeHeaderNames(
        allocator,
        header_names.items,
        header_values.items,
    );
    defer allocator.free(unsafe_headers);

    // Build preflight (OPTIONS) request
    var preflight_headers: std.ArrayListUnmanaged(NetworkRequest.Header) = .empty;
    defer preflight_headers.deinit(allocator);

    // Add Origin header
    try preflight_headers.append(allocator, .{ .name = "Origin", .value = origin });

    // Add Access-Control-Request-Method header
    try preflight_headers.append(allocator, .{ .name = "Access-Control-Request-Method", .value = request.method });

    // Add Access-Control-Request-Headers if we have unsafe headers
    var headers_value: ?[]u8 = null;
    defer if (headers_value) |h| allocator.free(h);

    if (unsafe_headers.len > 0) {
        // Join unsafe header names with ", "
        var total_len: usize = 0;
        for (unsafe_headers) |h| {
            total_len += h.len;
        }
        total_len += (unsafe_headers.len - 1) * 2;

        headers_value = try allocator.alloc(u8, total_len);
        var pos: usize = 0;
        for (unsafe_headers, 0..) |h, i| {
            @memcpy(headers_value.?[pos..][0..h.len], h);
            pos += h.len;
            if (i < unsafe_headers.len - 1) {
                headers_value.?[pos] = ',';
                headers_value.?[pos + 1] = ' ';
                pos += 2;
            }
        }
        try preflight_headers.append(allocator, .{
            .name = "Access-Control-Request-Headers",
            .value = headers_value.?,
        });
    }

    const preflight_request = NetworkRequest{
        .url = url,
        .method = "OPTIONS",
        .headers = preflight_headers.items,
        .body = null,
        .http_version = .http_1_1,
        .connect_timeout_ms = 30_000,
        .timeout_ms = 30_000, // Shorter timeout for preflight
        .follow_redirects = false,
        .max_redirects = 0,
        .proxy = null,
        // Whatever the embedder registered, which is `verify_peer` and
        // `verify_host` against the system trust store unless it said otherwise.
        .cert_options = network.defaultCertOptions(),
        .verbose = false,
    };

    // Perform network request (preflight doesn't use cookies)
    const backend_impl = LibcurlBackend.initWithOptions(allocator, .{
        .enable_cookies = false, // Preflight doesn't need cookies
    }) catch {
        return .{ .failure = .cors_check_failed };
    };
    defer backend_impl.deinit();

    const backend_iface = backend_impl.getBackend();

    var network_response = backend_iface.send(allocator, &preflight_request) catch {
        return .{ .failure = .cors_check_failed };
    };
    defer network_response.deinit();

    // Convert network response headers to a format validatePreflightResponse expects
    var response_headers = PreflightResponseHeaders.init(allocator);
    defer response_headers.deinit();

    for (network_response.headers) |header| {
        try response_headers.put(header.name, header.value);
    }

    // Map CredentialsMode
    const creds_mode: cors.CredentialsMode = switch (request.credentials_mode) {
        .omit => .omit,
        .same_origin => .same_origin,
        .include => .include,
    };

    // Validate preflight response
    const result = cors.validatePreflightResponse(
        allocator,
        origin,
        request.method,
        if (unsafe_headers.len > 0) unsafe_headers else null,
        creds_mode,
        response_headers,
        network_response.status,
    );

    // Cache successful preflight if we have a cache
    if (options.preflight_cache) |cache| {
        switch (result) {
            .success => |entry| {
                // Extract methods and headers for caching
                var methods_list: std.ArrayListUnmanaged([]const u8) = .empty;
                defer methods_list.deinit(allocator);
                for (entry.methods.items) |m| {
                    try methods_list.append(allocator, m);
                }

                var headers_list: std.ArrayListUnmanaged([]const u8) = .empty;
                defer headers_list.deinit(allocator);
                for (entry.headers.items) |h| {
                    try headers_list.append(allocator, h);
                }

                cache.createEntry(
                    origin,
                    url,
                    origin, // network partition key
                    @as(u64, @intCast(@max(0, entry.expiry_time - clock.wallSeconds()))),
                    methods_list.items,
                    entry.methods_wildcard,
                    headers_list.items,
                    entry.headers_wildcard,
                    request.credentials_mode == .include,
                ) catch {
                    // Cache failure is non-fatal
                };
            },
            .failure => {},
        }
    }

    return result;
}

/// Header wrapper for preflight response validation.
const PreflightResponseHeaders = struct {
    headers: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) PreflightResponseHeaders {
        return .{
            .headers = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PreflightResponseHeaders) void {
        self.headers.deinit();
    }

    pub fn put(self: *PreflightResponseHeaders, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    pub fn get(self: *const PreflightResponseHeaders, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "corsCheck - wildcard origin without credentials" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    request.origin = .{ .origin = "https://other.com" };
    request.credentials_mode = .omit;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "*");

    try std.testing.expectEqual(CorsCheckResult.success, corsCheck(request, response));
}

test "corsCheck - wildcard origin with credentials fails" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    request.origin = .{ .origin = "https://other.com" };
    request.credentials_mode = .include;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "*");

    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck(request, response));
}

test "corsCheck - matching origin" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    request.origin = .{ .origin = "https://example.com" };
    request.credentials_mode = .omit;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "https://example.com");

    try std.testing.expectEqual(CorsCheckResult.success, corsCheck(request, response));
}

test "corsCheck - non-matching origin" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    request.origin = .{ .origin = "https://other.com" };
    request.credentials_mode = .omit;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "https://example.com");

    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck(request, response));
}

test "corsCheck - credentials with allow-credentials header" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    request.origin = .{ .origin = "https://example.com" };
    request.credentials_mode = .include;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Access-Control-Allow-Origin", "https://example.com");
    try response.header_list.append("Access-Control-Allow-Credentials", "true");

    try std.testing.expectEqual(CorsCheckResult.success, corsCheck(request, response));
}

test "corsCheck - missing allow-origin header" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();
    request.origin = .{ .origin = "https://example.com" };

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck(request, response));
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
