//! Handle Fetch Algorithm
//!
//! Handles fetch requests by potentially routing to a service worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#handle-fetch

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const FetchEvent = @import("../events/fetch_event.zig").FetchEvent;
const Router = @import("../events/router.zig").Router;
const RouterSourceEnum = @import("../types.zig").RouterSourceEnum;

/// Result of the handle fetch algorithm.
pub const HandleFetchResult = union(enum) {
    /// No interception - fetch should proceed to network.
    network,
    /// Response provided by the service worker.
    response: ResponseInfo,
    /// Error occurred during handling.
    err: HandleFetchError,
    /// Router directed to cache (returns cache result).
    cache: ?ResponseInfo,
};

/// Response information returned by handle fetch.
pub const ResponseInfo = struct {
    /// HTTP status code.
    status: u16 = 200,
    /// Response body (if any).
    body: ?[]const u8 = null,
    /// Content type.
    content_type: ?[]const u8 = null,
};

/// Errors that can occur during handle fetch.
pub const HandleFetchError = enum {
    /// No active service worker.
    no_active_worker,
    /// Worker not in activated state.
    worker_not_activated,
    /// Event dispatch failed.
    dispatch_failed,
    /// respondWith failed.
    respond_with_failed,
};

/// Request information for handle fetch.
pub const RequestInfo = struct {
    /// Request URL.
    url: []const u8,
    /// HTTP method.
    method: []const u8 = "GET",
    /// Is this a navigation request?
    is_navigation: bool = false,
    /// Request headers (simplified).
    headers: ?[]const Header = null,
};

/// Simple header representation.
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// Context for the handle fetch algorithm.
pub const HandleFetchContext = struct {
    /// Router rules to evaluate (if any).
    router: ?*const Router = null,

    /// Callback for dispatching fetch event to worker.
    /// Returns true if respondWith was called, along with the response.
    dispatch_fetch_event: ?*const fn (
        worker: *ServiceWorker,
        event: *FetchEvent,
    ) ?ResponseInfo = null,

    /// Callback for cache lookup.
    lookup_cache: ?*const fn (url: []const u8) ?ResponseInfo = null,

    /// Navigation preload response (if preload was enabled).
    preload_response: ?ResponseInfo = null,
};

/// Handle a fetch request.
///
/// Spec: https://w3c.github.io/ServiceWorker/#handle-fetch
///
/// Algorithm:
/// 1. Let registration be the controlling registration
/// 2. Let activeWorker be registration's active worker
/// 3. If activeWorker is null, return null (no interception)
/// 4. If activeWorker's state is not "activated", return null
/// 5. Check router rules (if any):
///    a. If router says "network", return null
///    b. If router says "cache", check cache and return
///    c. If router says "fetch-event", continue to SW
/// 6. Create FetchEvent with request
/// 7. Set preloadResponse if navigation preload enabled
/// 8. Dispatch event to worker
/// 9. If respondWith() called, return that response
/// 10. Otherwise, return null (fallback to network)
pub fn handleFetch(
    registration: *Registration,
    request: RequestInfo,
    context: HandleFetchContext,
    allocator: std.mem.Allocator,
) HandleFetchResult {
    // Step 1 & 2: Get active worker
    const worker = registration.active_worker orelse {
        return .{ .err = .no_active_worker };
    };

    // Step 3 & 4: Check worker state
    if (worker.state != .activated) {
        return .{ .err = .worker_not_activated };
    }

    // Step 5: Check router rules
    if (context.router) |router| {
        if (router.evaluateRules(request.url, request.method)) |source| {
            switch (source) {
                .network => return .network,
                .cache => {
                    // Try cache lookup
                    if (context.lookup_cache) |lookup| {
                        return .{ .cache = lookup(request.url) };
                    }
                    return .{ .cache = null };
                },
                .fetch_event => {
                    // Continue to fetch event dispatch
                },
                .race_network_and_fetch_handler => {
                    // For now, treat as fetch_event
                    // Real impl would race both
                },
            }
        }
    }

    // Step 6: Create FetchEvent
    var event = FetchEvent.init(allocator, request.url, request.method);
    defer event.deinit();

    // Step 7: Set preload response if navigation
    if (request.is_navigation and context.preload_response != null) {
        event.has_preload_response = true;
    }

    // Step 8 & 9: Dispatch event
    if (context.dispatch_fetch_event) |dispatch| {
        if (dispatch(worker, &event)) |response| {
            return .{ .response = response };
        }
    }

    // Step 10: No respondWith called, fallback to network
    return .network;
}

/// Check if a request should be handled by a service worker.
///
/// This is a quick check without actually handling the request.
pub fn shouldHandleFetch(registration: *const Registration) bool {
    const worker = registration.active_worker orelse return false;
    return worker.state == .activated;
}

// =============================================================================
// Tests
// =============================================================================

test "handleFetch - no active worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const result = handleFetch(reg, .{ .url = "https://example.com/api" }, .{}, allocator);
    try std.testing.expectEqual(HandleFetchError.no_active_worker, result.err);
}

test "handleFetch - worker not activated" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.activating); // Not yet activated

    reg.setActiveWorker(sw);

    const result = handleFetch(reg, .{ .url = "https://example.com/api" }, .{}, allocator);
    try std.testing.expectEqual(HandleFetchError.worker_not_activated, result.err);
}

test "handleFetch - network fallback" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.activated);

    reg.setActiveWorker(sw);

    // No dispatch callback = network fallback
    const result = handleFetch(reg, .{ .url = "https://example.com/api" }, .{}, allocator);
    try std.testing.expectEqual(HandleFetchResult.network, result);
}

test "handleFetch - respondWith" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.activated);

    reg.setActiveWorker(sw);

    const ctx = HandleFetchContext{
        .dispatch_fetch_event = struct {
            fn dispatch(_: *ServiceWorker, _: *FetchEvent) ?ResponseInfo {
                return .{
                    .status = 200,
                    .body = "cached response",
                    .content_type = "text/plain",
                };
            }
        }.dispatch,
    };

    const result = handleFetch(reg, .{ .url = "https://example.com/api" }, ctx, allocator);
    switch (result) {
        .response => |resp| {
            try std.testing.expectEqual(@as(u16, 200), resp.status);
            try std.testing.expectEqualStrings("cached response", resp.body.?);
        },
        else => try std.testing.expect(false),
    }
}

test "shouldHandleFetch" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // No worker
    try std.testing.expect(!shouldHandleFetch(reg));

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    reg.setActiveWorker(sw);

    // Not activated
    sw.setState(.activating);
    try std.testing.expect(!shouldHandleFetch(reg));

    // Activated
    sw.setState(.activated);
    try std.testing.expect(shouldHandleFetch(reg));
}
