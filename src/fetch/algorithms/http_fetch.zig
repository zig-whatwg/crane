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
const fetch_params = @import("../internal/fetch_params.zig");
const FetchParams = fetch_params.FetchParams;

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
};

/// Execute the HTTP fetch algorithm.
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
pub fn httpFetch(
    allocator: Allocator,
    params: *FetchParams,
    options: HttpFetchOptions,
) HttpFetchError!*InternalResponse {
    const request = params.request;

    // Step 2: Let response be null
    var response: ?*InternalResponse = null;

    // Step 3: Service worker handling
    // If request's service-workers mode is "all", handle service worker interception
    // TODO: Implement service worker interception when service worker module is available
    // For now, skip service worker and proceed directly to network fetch

    // Step 4: If response is null
    if (response == null) {
        if (request.redirect_mode == .follow) {
            // Run HTTP-redirect fetch
            response = try httpRedirectFetch(allocator, params, options);
        } else {
            // Run HTTP-network-or-cache fetch
            response = try httpNetworkOrCacheFetch(allocator, params, options, false);
        }
    }

    var final_response = response.?;

    // Step 5: CORS check
    if (options.cors_flag and !isNetworkError(final_response)) {
        const cors_result = corsCheck(request, final_response);
        if (cors_result == .failure) {
            final_response.deinit();
            return HttpFetchError.CorsError;
        }
    }

    return final_response;
}

/// HTTP-redirect fetch algorithm.
///
/// Per Fetch spec §4.7:
/// 1. Let request be fetchParams's request
/// 2. Let response be the result of running HTTP-network-or-cache fetch
/// 3. If response is not a network error and response's status is a redirect status:
///    - Handle redirect based on redirect mode
/// 4. Return response
pub fn httpRedirectFetch(
    allocator: Allocator,
    params: *FetchParams,
    options: HttpFetchOptions,
) HttpFetchError!*InternalResponse {
    const request = params.request;

    // Step 1: Let request be fetchParams's request (already have it)

    // Step 2: Run HTTP-network-or-cache fetch
    var response = try httpNetworkOrCacheFetch(allocator, params, options, false);

    // Step 3: Handle redirects
    if (!isNetworkError(response) and internal_response.isRedirectStatus(response.status)) {
        // Get Location header for redirect
        const location = response.header_list.get(allocator, "Location") catch null;
        defer if (location) |loc| allocator.free(loc);

        if (location) |loc| {
            // Check redirect count
            if (request.redirect_count >= 20) {
                response.deinit();
                return try internal_response.networkError(allocator);
            }

            // Increment redirect count
            request.redirect_count += 1;

            // Add redirect URL to request's URL list
            request.addUrl(loc) catch {
                response.deinit();
                return HttpFetchError.OutOfMemory;
            };

            // Clean up current response and fetch again
            response.deinit();

            // Handle method change for 303 redirects
            if (response.status == 303) {
                request.setMethod("GET") catch {
                    return HttpFetchError.OutOfMemory;
                };
                // Remove body for GET requests
                request.body = null;
            }

            // Recursive redirect fetch
            return try httpRedirectFetch(allocator, params, options);
        }
    }

    return response;
}

/// HTTP-network-or-cache fetch algorithm.
///
/// Per Fetch spec §4.8:
/// This algorithm handles both cached and network responses.
/// For now, we skip caching and go directly to network fetch.
pub fn httpNetworkOrCacheFetch(
    allocator: Allocator,
    params: *FetchParams,
    options: HttpFetchOptions,
    is_new_connection_fetch: bool,
) HttpFetchError!*InternalResponse {
    _ = is_new_connection_fetch;
    const request = params.request;

    // TODO: Implement full cache lookup logic per spec
    // For now, skip cache and go directly to network

    // Check cache mode
    if (request.cache_mode == .only_if_cached) {
        // Only-if-cached requires a cached response
        // Since we don't have cache yet, return network error
        return try internal_response.networkError(allocator);
    }

    // Run HTTP-network fetch
    return try httpNetworkFetch(allocator, params, options);
}

/// HTTP-network fetch algorithm.
///
/// Per Fetch spec §4.9:
/// This is where the actual network request happens.
/// For now, returns a stubbed response.
pub fn httpNetworkFetch(
    allocator: Allocator,
    params: *FetchParams,
    options: HttpFetchOptions,
) HttpFetchError!*InternalResponse {
    _ = options;
    const request = params.request;

    // TODO: Implement actual network request using NetworkBackend
    // For now, create a stubbed successful response

    const response = InternalResponse.init(allocator) catch {
        return HttpFetchError.OutOfMemory;
    };
    errdefer response.deinit();

    // Set response URL from request
    response.addUrl(request.currentUrl()) catch {
        return HttpFetchError.OutOfMemory;
    };

    // Default to 200 OK for stub
    response.status = 200;

    // Record timing
    const now = getCurrentTimeMs();
    params.timing_info.final_network_response_start_time = now;
    params.timing_info.end_time = now;

    return response;
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
fn getCurrentTimeMs() f64 {
    return @as(f64, @floatFromInt(std.time.timestamp())) * 1000.0;
}

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
