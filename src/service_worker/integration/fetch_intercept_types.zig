//! Fetch Interception Types for Service Workers (Standalone)
//!
//! This module provides only the TYPE DEFINITIONS for fetch interception,
//! without importing the algorithms module. This allows browser and other
//! modules to use these types without circular dependencies.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import only the registration map (no WebIDL deps)
const RegistrationMap = @import("../registration_map.zig").RegistrationMap;

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
    /// Uses *anyopaque to avoid circular dependency with service_worker.zig.
    dispatch_callback: ?*const fn (*anyopaque, RequestForInterception) ?InterceptedResponse = null,
    /// Callback for cache lookup.
    cache_lookup: ?*const fn ([]const u8) ?InterceptedResponse = null,
    /// Navigation preload response (if enabled and available).
    preload_response: ?InterceptedResponse = null,
};

/// Intercept a fetch request with service workers.
///
/// This is a STUB implementation for the standalone module. It checks if there's
/// a controlling service worker and optionally dispatches to it via callback.
/// Without a callback, it returns no_interception (network fallback).
///
/// The real service worker fetch event dispatch is handled by the full
/// service_worker module when it wires up the dispatch_callback.
pub fn interceptFetch(request: RequestForInterception, context: InterceptionContext) InterceptionResult {
    // If service workers are disabled for this request, skip interception
    if (request.service_workers_mode == .none) {
        return .no_interception;
    }

    // Check if we have a dispatch callback for real SW execution
    if (context.dispatch_callback) |callback| {
        // The callback uses *anyopaque - caller is responsible for providing
        // a valid service worker pointer. For now, we pass null since this
        // standalone module doesn't have access to ServiceWorker type.
        // TODO: Wire this up properly when service_worker module initializes.
        _ = callback;
        // For now, fall through to no_interception
    }

    // Check cache lookup if available
    if (context.cache_lookup) |lookup| {
        if (lookup(request.url)) |cached| {
            return .{ .response = cached };
        }
    }

    // Check navigation preload
    if (context.preload_response) |preload| {
        return .{ .response = preload };
    }

    // No service worker interception - proceed to network
    return .no_interception;
}
