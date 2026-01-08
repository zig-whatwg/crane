//! Service Worker FetchInterceptor Implementation
//!
//! This module implements the fetch interception VTable interface,
//! adapting the service worker interception logic to the generic
//! FetchInterceptor contract defined in src/fetch/interception/.
//!
//! This breaks the circular dependency by having service_worker
//! depend on fetch (one-way), while fetch only knows about the
//! generic FetchInterceptor interface.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import the fetch interception contract (fetch module)
const fetch_interception = @import("fetch").interception;
const FetchInterceptor = fetch_interception.FetchInterceptor;
const InterceptionDecision = fetch_interception.InterceptionDecision;
const InterceptionContext = fetch_interception.InterceptionContext;
const InterceptionError = fetch_interception.InterceptionError;

// Import fetch internal types
const fetch_internal = @import("fetch").internal;
const InternalRequest = fetch_internal.InternalRequest;
const InternalResponse = fetch_internal.InternalResponse;

// Import local service worker types (standalone types without algorithm deps)
const sw_intercept = @import("fetch_intercept_types.zig");
const RegistrationMap = @import("../registration_map.zig").RegistrationMap;

/// Service Worker implementation of the FetchInterceptor interface.
///
/// This adapter translates between the generic FetchInterceptor contract
/// and the service worker-specific interception logic.
pub const ServiceWorkerFetchInterceptor = struct {
    /// The service worker registration map for looking up controlling workers.
    registration_map: *RegistrationMap,

    /// Allocator for temporary allocations during interception.
    allocator: Allocator,

    /// Optional callback for dispatching fetch events to actual JS runtime.
    /// If null, interception will check for controlling worker but cannot
    /// actually dispatch events (useful for testing registration logic).
    /// Uses *anyopaque to avoid circular dependency with service_worker.zig.
    dispatch_callback: ?*const fn (*anyopaque, sw_intercept.RequestForInterception) ?sw_intercept.InterceptedResponse = null,

    /// Optional cache lookup callback.
    cache_lookup: ?*const fn ([]const u8) ?sw_intercept.InterceptedResponse = null,

    /// Cached FetchInterceptor for returning stable pointer
    fetch_interceptor_cache: ?FetchInterceptor = null,

    const Self = @This();

    /// Get this as a generic FetchInterceptor pointer for registration with the fetch module.
    pub fn asFetchInterceptor(self: *Self) *const FetchInterceptor {
        if (self.fetch_interceptor_cache == null) {
            self.fetch_interceptor_cache = .{
                .ptr = self,
                .vtable = &vtable,
            };
        }
        return &self.fetch_interceptor_cache.?;
    }

    /// Initialize a new ServiceWorkerFetchInterceptor.
    pub fn init(
        allocator: Allocator,
        registration_map: *RegistrationMap,
    ) Self {
        return .{
            .registration_map = registration_map,
            .allocator = allocator,
            .dispatch_callback = null,
            .cache_lookup = null,
        };
    }

    /// Set the dispatch callback for handling fetch events.
    /// This should be called by the runtime when a ServiceWorker context is ready.
    /// The first parameter is a *ServiceWorker cast to *anyopaque to avoid circular deps.
    pub fn setDispatchCallback(
        self: *Self,
        callback: *const fn (*anyopaque, sw_intercept.RequestForInterception) ?sw_intercept.InterceptedResponse,
    ) void {
        self.dispatch_callback = callback;
    }

    /// Set the cache lookup callback.
    pub fn setCacheLookup(
        self: *Self,
        callback: *const fn ([]const u8) ?sw_intercept.InterceptedResponse,
    ) void {
        self.cache_lookup = callback;
    }

    /// VTable for the FetchInterceptor interface.
    const vtable: FetchInterceptor.VTable = .{
        .intercept = intercept,
    };

    /// Implementation of the intercept function.
    fn intercept(
        ptr: *anyopaque,
        allocator: Allocator,
        request: *InternalRequest,
        ctx: *const InterceptionContext,
    ) InterceptionDecision {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Check bypass flag from context
        if (ctx.bypass_service_worker) {
            return .network_fallback;
        }

        // Check reentrancy protection flag on request
        if (request.skip_service_worker_interception) {
            return .network_fallback;
        }

        // Build the SW-specific request info
        // Get current URL from url_list (last item after redirects)
        const current_url = if (request.url_list.items.len > 0)
            request.url_list.items[request.url_list.items.len - 1]
        else
            return .network_fallback;

        const sw_request = sw_intercept.RequestForInterception{
            .url = current_url,
            .method = request.method,
            .service_workers_mode = switch (request.service_workers_mode) {
                .all => .all,
                .none => .none,
            },
            .is_navigation = request.mode == .navigate,
            .origin = null, // Could extract from request if needed
        };

        // Build the SW interception context
        const sw_context = sw_intercept.InterceptionContext{
            .registration_map = self.registration_map,
            .allocator = allocator,
            .dispatch_callback = self.dispatch_callback,
            .cache_lookup = self.cache_lookup,
            .preload_response = null,
        };

        // Call the existing SW interception logic
        const result = sw_intercept.interceptFetch(sw_request, sw_context);

        // Translate the result to the generic InterceptionDecision
        return switch (result) {
            .no_interception => .network_fallback,
            .err => |e| .{ .err = translateError(e) },
            .response => |r| blk: {
                // Build an InternalResponse from the SW response
                const response = buildInternalResponse(allocator, r) catch {
                    break :blk InterceptionDecision{ .err = .internal_error };
                };
                break :blk InterceptionDecision{ .response = response };
            },
        };
    }

    /// Translate SW-specific errors to generic InterceptionError.
    fn translateError(err: sw_intercept.InterceptionError) InterceptionError {
        return switch (err) {
            .sw_error => .internal_error,
            .respond_with_rejected => .rejected,
            .invalid_response => .invalid_response,
            .timeout => .timeout,
        };
    }

    /// Build an InternalResponse from a SW InterceptedResponse.
    fn buildInternalResponse(
        allocator: Allocator,
        sw_response: sw_intercept.InterceptedResponse,
    ) !*InternalResponse {
        // Create a new InternalResponse
        const response = try InternalResponse.init(allocator);

        // Set status
        response.status = sw_response.status;
        response.status_message = sw_response.status_text;

        // Handle body from SW response
        if (sw_response.body) |body_bytes| {
            // Create Body from the service worker response bytes
            const Body = @import("fetch").internal.Body;
            response.body = try Body.fromBytes(allocator, body_bytes);
        }

        // Set content-type header if present
        if (sw_response.content_type) |ct| {
            try response.header_list.append("content-type", ct);
        }

        // Mark as from service worker for timing
        response.response_type = .default;

        return response;
    }
};

// ============================================================================
// Global Registration
// ============================================================================

/// Global state for lazy registration.
/// Uses atomic to be thread-safe.
var global_registered: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
var global_interceptor: ?*ServiceWorkerFetchInterceptor = null;

/// Ensure the service worker fetch interceptor is registered with the fetch module.
///
/// This function is idempotent - calling it multiple times is safe.
/// It should be called when service worker functionality is first used
/// (e.g., when a ServiceWorkerContainer is created).
///
/// Parameters:
/// - allocator: Allocator for creating the interceptor instance
/// - registration_map: The global registration map for SW lookups
///
/// Returns true if registration was performed, false if already registered.
pub fn ensureRegistered(
    allocator: Allocator,
    registration_map: *RegistrationMap,
) bool {
    // Fast path: already registered
    if (global_registered.load(.acquire)) {
        return false;
    }

    // Create and register the interceptor
    const interceptor = allocator.create(ServiceWorkerFetchInterceptor) catch return false;
    interceptor.* = ServiceWorkerFetchInterceptor.init(allocator, registration_map);

    // Register with the fetch module
    fetch_interception.registry.register(interceptor.asFetchInterceptor());

    // Store globally and mark as registered
    global_interceptor = interceptor;
    global_registered.store(true, .release);

    return true;
}

/// Unregister the global service worker fetch interceptor.
///
/// Should be called during shutdown to clean up resources.
pub fn unregister(allocator: Allocator) void {
    if (!global_registered.load(.acquire)) {
        return;
    }

    // Unregister from fetch module
    fetch_interception.registry.unregister();

    // Free the interceptor
    if (global_interceptor) |interceptor| {
        allocator.destroy(interceptor);
        global_interceptor = null;
    }

    global_registered.store(false, .release);
}

/// Check if the interceptor is currently registered.
pub fn isRegistered() bool {
    return global_registered.load(.acquire);
}

test "ServiceWorkerFetchInterceptor - basic creation" {
    const allocator = std.testing.allocator;

    // Create a mock registration map
    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    // Create the interceptor
    var interceptor = ServiceWorkerFetchInterceptor.init(allocator, &reg_map);

    // Get as generic FetchInterceptor
    const generic = interceptor.asFetchInterceptor();

    // Verify vtable is set
    try std.testing.expect(generic.vtable != null);
    try std.testing.expect(generic.ptr != null);
}
