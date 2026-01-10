//! Fetch Interception for Service Workers
//!
//! This module provides the integration point between the Fetch specification
//! and Service Workers. It handles request interception per the spec.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-fetch step 3
//! Spec: https://w3c.github.io/ServiceWorker/#handle-fetch

const std = @import("std");
const Allocator = std.mem.Allocator;

// Service Worker types
const Registration = @import("../registration.zig").Registration;
const RegistrationMap = @import("../registration_map.zig").RegistrationMap;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const algorithms = @import("../algorithms/root.zig");
const HandleFetchResult = algorithms.HandleFetchResult;
const HandleFetchContext = algorithms.HandleFetchContext;
const RequestInfo = algorithms.RequestInfo;
const ResponseInfo = algorithms.ResponseInfo;

/// Result of service worker interception.
pub const InterceptionResult = union(enum) {
    /// No interception - request should proceed to network.
    no_interception,
    /// Service worker provided a response.
    response: InterceptedResponse,
    /// Error occurred during interception.
    err: InterceptionError,
};

/// A response from service worker interception.
pub const InterceptedResponse = struct {
    /// HTTP status code.
    status: u16,
    /// Status text.
    status_text: []const u8 = "OK",
    /// Response body (if any).
    body: ?[]const u8 = null,
    /// Content-Type header (if set).
    content_type: ?[]const u8 = null,
    /// Response source for timing.
    source: ResponseSource = .service_worker,
};

/// Response source for timing/debugging.
pub const ResponseSource = enum {
    /// Response came from service worker respondWith().
    service_worker,
    /// Response came from service worker cache.
    service_worker_cache,
    /// Response came from navigation preload.
    navigation_preload,
};

/// Errors during interception.
pub const InterceptionError = enum {
    /// Service worker threw an error.
    sw_error,
    /// respondWith promise rejected.
    respond_with_rejected,
    /// Invalid response from SW.
    invalid_response,
    /// Timeout waiting for response.
    timeout,
};

/// Service workers mode for requests.
pub const ServiceWorkersMode = enum {
    /// Relevant service workers will get a fetch event.
    all,
    /// No service workers will get events for this fetch.
    none,
};

/// Request information for interception check.
pub const RequestForInterception = struct {
    /// Request URL.
    url: []const u8,
    /// HTTP method.
    method: []const u8 = "GET",
    /// Service workers mode.
    service_workers_mode: ServiceWorkersMode = .all,
    /// Is this a navigation request?
    is_navigation: bool = false,
    /// Request origin.
    origin: ?[]const u8 = null,
};

/// Context for fetch interception.
pub const InterceptionContext = struct {
    /// Registration map for looking up service workers.
    registration_map: *RegistrationMap,
    /// Allocator for any temporary allocations.
    allocator: Allocator,
    /// Callback to dispatch fetch event (for real SW execution).
    dispatch_callback: ?*const fn (*ServiceWorker, RequestForInterception) ?InterceptedResponse = null,
    /// Callback for cache lookup.
    cache_lookup: ?*const fn ([]const u8) ?InterceptedResponse = null,
    /// Navigation preload response (if enabled and available).
    preload_response: ?InterceptedResponse = null,
};

/// Intercept a fetch request with service workers.
///
/// This is the main entry point called from HTTP fetch.
///
/// Per Fetch spec §4.6 step 3:
/// "If request's service-workers mode is 'all', then:
///   1. Get the active service worker registration for the request
///   2. If found, run the Handle Fetch algorithm
///   3. Return the response if one was provided"
///
/// Returns:
/// - `.no_interception` if SW mode is "none" or no active SW
/// - `.response` if SW provided a response
/// - `.err` if interception failed
pub fn interceptFetch(
    request: RequestForInterception,
    context: InterceptionContext,
) InterceptionResult {
    // Step 1: Check service workers mode
    if (request.service_workers_mode == .none) {
        return .no_interception;
    }

    // Step 2: Get controlling service worker registration
    const registration = getControllingRegistration(
        request.url,
        request.origin,
        context.registration_map,
    ) orelse {
        // No controlling service worker
        return .no_interception;
    };

    // Step 3: Check for active worker
    const worker = registration.active_worker orelse {
        return .no_interception;
    };

    // Step 4: Check worker state
    if (worker.state != .activated) {
        return .no_interception;
    }

    // Step 5: Build request info for handle fetch
    const req_info = algorithms.RequestInfo{
        .url = request.url,
        .method = request.method,
        .is_navigation = request.is_navigation,
    };

    // Step 6: Build handle fetch context
    // Note: dispatch_fetch_event is set to null here because the actual dispatch
    // happens through the InterceptionContext.dispatch_callback which is called
    // directly in interceptFetch. The handleFetch algorithm will fall through
    // to network if dispatch_fetch_event is null, which is correct for the
    // case where no SW handler intercepts the request.
    //
    // When dispatch_callback IS set, we call it directly below before handleFetch.
    const fetch_ctx = algorithms.HandleFetchContext{
        .dispatch_fetch_event = null, // Dispatch handled separately via context.dispatch_callback
        .preload_response = if (context.preload_response) |pr|
            ResponseInfo{
                .status = pr.status,
                .body = pr.body,
                .content_type = pr.content_type,
            }
        else
            null,
    };

    // Step 7a: Try dispatch_callback first if set (for JS integration)
    if (context.dispatch_callback) |dispatch_fn| {
        {
            const request_for_interception = RequestForInterception{
                .url = request.url,
                .method = request.method,
                .headers = request.headers,
                .body = request.body,
                .mode = request.mode,
                .credentials = request.credentials,
                .cache_mode = request.cache_mode,
                .redirect = request.redirect,
                .referrer = request.referrer,
                .referrer_policy = request.referrer_policy,
                .integrity = request.integrity,
                .is_navigation = request.is_navigation,
                .is_reload = request.is_reload,
                .client_id = request.client_id,
            };

            if (dispatch_fn(worker, request_for_interception)) |intercepted| {
                // SW handler provided a response
                return .{
                    .response = .{
                        .status = intercepted.status,
                        .status_text = intercepted.status_text,
                        .body = intercepted.body,
                        .content_type = intercepted.content_type,
                        .source = .service_worker,
                    },
                };
            }
            // dispatch_callback returned null - no response, fall through to network
            return .no_interception;
        }
    }

    // Step 7b: Run handle fetch algorithm (fallback path when no dispatch_callback)
    const result = algorithms.handleFetch(registration, req_info, fetch_ctx, context.allocator);

    // Step 8: Convert result
    return switch (result) {
        .network => .no_interception,
        .response => |resp| .{
            .response = .{
                .status = resp.status,
                .body = resp.body,
                .content_type = resp.content_type,
                .source = .service_worker,
            },
        },
        .cache => |maybe_resp| if (maybe_resp) |resp| .{
            .response = .{
                .status = resp.status,
                .body = resp.body,
                .content_type = resp.content_type,
                .source = .service_worker_cache,
            },
        } else .no_interception,
        .err => |e| .{
            .err = switch (e) {
                .no_active_worker, .worker_not_activated => return .no_interception,
                .dispatch_failed => .sw_error,
                .respond_with_failed => .respond_with_rejected,
            },
        },
    };
}

/// Get the controlling service worker registration for a URL.
///
/// Per Service Workers spec:
/// 1. Parse the URL to get origin and path
/// 2. Look up registration by scope that matches the URL
/// 3. Return registration if it has an active worker
fn getControllingRegistration(
    url: []const u8,
    origin: ?[]const u8,
    registration_map: *RegistrationMap,
) ?*Registration {
    // Parse URL to get origin
    const url_origin = origin orelse extractOrigin(url) orelse return null;

    // Parse URL to get path for scope matching
    const path = extractPath(url);

    // Look up registration with longest matching scope
    return registration_map.getByScope(url_origin, path);
}

/// Extract origin from URL.
fn extractOrigin(url: []const u8) ?[]const u8 {
    // Find scheme://
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;

    // Find end of host (first / after scheme://)
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;

    // Origin is everything up to the path
    return url[0 .. scheme_end + 3 + path_start];
}

/// Extract path from URL.
fn extractPath(url: []const u8) []const u8 {
    // Find scheme://
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return "/";

    // Find start of path
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse return "/";

    // Return path (strip query and fragment)
    const path = after_scheme[path_start..];
    const query = std.mem.indexOf(u8, path, "?") orelse path.len;
    const fragment = std.mem.indexOf(u8, path, "#") orelse path.len;

    return path[0..@min(query, fragment)];
}

/// Check if a request should be intercepted by service workers.
///
/// Quick check without actually intercepting.
pub fn shouldIntercept(
    request: RequestForInterception,
    registration_map: *RegistrationMap,
) bool {
    if (request.service_workers_mode == .none) {
        return false;
    }

    const registration = getControllingRegistration(
        request.url,
        request.origin,
        registration_map,
    ) orelse return false;

    const worker = registration.active_worker orelse return false;

    return worker.state == .activated;
}

// =============================================================================
// Tests
// =============================================================================

test "extractOrigin" {
    try std.testing.expectEqualStrings(
        "https://example.com",
        extractOrigin("https://example.com/path/to/file").?,
    );
    try std.testing.expectEqualStrings(
        "http://localhost:8080",
        extractOrigin("http://localhost:8080/api/v1").?,
    );
    try std.testing.expect(extractOrigin("invalid-url") == null);
}

test "extractPath" {
    try std.testing.expectEqualStrings(
        "/path/to/file",
        extractPath("https://example.com/path/to/file"),
    );
    try std.testing.expectEqualStrings(
        "/api/v1",
        extractPath("http://localhost:8080/api/v1?query=1#hash"),
    );
    try std.testing.expectEqualStrings(
        "/",
        extractPath("https://example.com"),
    );
}

test "interceptFetch - service workers mode none" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    const request = RequestForInterception{
        .url = "https://example.com/api",
        .service_workers_mode = .none,
    };

    const ctx = InterceptionContext{
        .registration_map = &reg_map,
        .allocator = allocator,
    };

    const result = interceptFetch(request, ctx);
    try std.testing.expectEqual(InterceptionResult.no_interception, result);
}

test "interceptFetch - no registration" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    const request = RequestForInterception{
        .url = "https://example.com/api",
    };

    const ctx = InterceptionContext{
        .registration_map = &reg_map,
        .allocator = allocator,
    };

    const result = interceptFetch(request, ctx);
    try std.testing.expectEqual(InterceptionResult.no_interception, result);
}

test "shouldIntercept" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    // No registration = no intercept
    try std.testing.expect(!shouldIntercept(.{
        .url = "https://example.com/api",
    }, &reg_map));

    // SW mode none = no intercept
    try std.testing.expect(!shouldIntercept(.{
        .url = "https://example.com/api",
        .service_workers_mode = .none,
    }, &reg_map));
}
