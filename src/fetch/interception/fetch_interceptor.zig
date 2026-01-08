//! WHATWG Fetch Standard - Service Worker Interception Contract
//!
//! This module defines the VTable-based FetchInterceptor interface that allows
//! service workers to intercept fetch requests without creating circular dependencies.
//!
//! Architecture:
//! - `fetch` owns this contract (no imports from service_worker)
//! - `service_worker` implements this interface
//! - `Browser` wires them together at startup
//!
//! This pattern matches Chromium's URLLoaderFactory abstraction and follows
//! the existing vtable patterns in src/fetch/network/backend.zig.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-fetch (step 4 - service worker)
//! Spec: https://w3c.github.io/ServiceWorker/#handle-fetch

const std = @import("std");
const Allocator = std.mem.Allocator;

const internal_request = @import("../internal/request.zig");
const internal_response = @import("../internal/response.zig");
const InternalRequest = internal_request.InternalRequest;
const InternalResponse = internal_response.InternalResponse;

// =============================================================================
// Interception Error Types
// =============================================================================

/// Errors that can occur during service worker interception.
pub const InterceptionError = enum {
    /// Internal error in the service worker.
    internal_error,
    /// Service worker took too long to respond.
    timeout,
    /// Service worker returned an invalid response.
    invalid_response,
    /// Service worker explicitly rejected the fetch (respondWith rejected).
    rejected,
    /// No controlling service worker for this request.
    no_controller,
};

// =============================================================================
// Interception Decision
// =============================================================================

/// The result of a service worker interception attempt.
/// Matches the spec's "handle fetch" algorithm outcomes.
pub const InterceptionDecision = union(enum) {
    /// No interception occurred - proceed with network fetch.
    /// This happens when:
    /// - No service worker controls the client
    /// - Service worker didn't call respondWith()
    /// - Request's service-workers mode is "none"
    network_fallback,

    /// Service worker provided a response via respondWith().
    /// The fetch algorithm should use this response directly.
    response: *InternalResponse,

    /// An error occurred during interception.
    err: InterceptionError,
};

// =============================================================================
// Interception Context
// =============================================================================

/// Context passed to the interceptor for each fetch request.
/// Contains metadata needed for interception decisions.
pub const InterceptionContext = struct {
    /// Allocator for any allocations needed during interception.
    allocator: Allocator,

    /// If true, bypass service worker interception regardless of other settings.
    /// Used for:
    /// - Reentrancy protection (fetches initiated by service worker)
    /// - Navigation preload
    /// - Explicit bypass requests
    bypass_service_worker: bool = false,

    /// Optional callback to get current time in milliseconds.
    /// Used for timing info if provided.
    now_ms: ?*const fn () f64 = null,

    /// Client ID for the request's client, if any.
    /// Used to find the controlling service worker.
    client_id: ?[]const u8 = null,

    /// Whether this is a navigation request.
    is_navigation: bool = false,
};

// =============================================================================
// FetchInterceptor VTable Interface
// =============================================================================

/// VTable-based interface for fetch interception.
///
/// Implementations:
/// - ServiceWorkerFetchInterceptorImpl (in service_worker module)
/// - MockFetchInterceptor (for testing)
///
/// Usage:
/// ```zig
/// if (registry.get()) |interceptor| {
///     switch (interceptor.intercept(allocator, request, &ctx)) {
///         .network_fallback => {}, // proceed with network
///         .response => |r| return r,
///         .err => return networkError(),
///     }
/// }
/// ```
pub const FetchInterceptor = struct {
    /// Type-erased pointer to the concrete implementation.
    ptr: *anyopaque,

    /// VTable with function pointers for dispatch.
    vtable: *const VTable,

    pub const VTable = struct {
        /// Attempt to intercept a fetch request.
        ///
        /// Returns:
        /// - `.network_fallback` if no interception should occur
        /// - `.response` with the SW-provided response
        /// - `.err` if interception failed
        intercept: *const fn (
            ptr: *anyopaque,
            allocator: Allocator,
            request: *InternalRequest,
            ctx: *const InterceptionContext,
        ) InterceptionDecision,

        /// Optional: Check if this interceptor can handle the request.
        /// Default implementation returns true.
        canIntercept: ?*const fn (
            ptr: *anyopaque,
            request: *const InternalRequest,
        ) bool = null,

        /// Optional: Called when the interceptor is being unregistered.
        /// Allows cleanup of any resources.
        deinit: ?*const fn (ptr: *anyopaque) void = null,
    };

    /// Attempt to intercept a fetch request.
    pub fn intercept(
        self: FetchInterceptor,
        allocator: Allocator,
        request: *InternalRequest,
        ctx: *const InterceptionContext,
    ) InterceptionDecision {
        return self.vtable.intercept(self.ptr, allocator, request, ctx);
    }

    /// Check if this interceptor can handle the request.
    pub fn canIntercept(self: FetchInterceptor, request: *const InternalRequest) bool {
        if (self.vtable.canIntercept) |can_intercept_fn| {
            return can_intercept_fn(self.ptr, request);
        }
        return true; // Default: can intercept all requests
    }

    /// Clean up the interceptor.
    pub fn deinit(self: FetchInterceptor) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

// =============================================================================
// Helper for creating interceptors
// =============================================================================

/// Helper to create a FetchInterceptor from a concrete implementation type.
/// The implementation type must have an `intercept` method with the correct signature.
pub fn createInterceptor(comptime T: type, impl: *T) FetchInterceptor {
    const vtable = comptime blk: {
        var vt: FetchInterceptor.VTable = .{
            .intercept = struct {
                fn intercept(
                    ptr: *anyopaque,
                    allocator: Allocator,
                    request: *InternalRequest,
                    ctx: *const InterceptionContext,
                ) InterceptionDecision {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.intercept(allocator, request, ctx);
                }
            }.intercept,
        };

        // Check for optional methods
        if (@hasDecl(T, "canIntercept")) {
            vt.canIntercept = struct {
                fn canIntercept(ptr: *anyopaque, request: *const InternalRequest) bool {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.canIntercept(request);
                }
            }.canIntercept;
        }

        if (@hasDecl(T, "deinit")) {
            vt.deinit = struct {
                fn deinitFn(ptr: *anyopaque) void {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    self.deinit();
                }
            }.deinitFn;
        }

        break :blk vt;
    };

    const static_vtable = struct {
        const v: FetchInterceptor.VTable = vtable;
    };

    return .{
        .ptr = impl,
        .vtable = &static_vtable.v,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "FetchInterceptor - network fallback" {
    const MockInterceptor = struct {
        pub fn intercept(
            _: *@This(),
            _: Allocator,
            _: *InternalRequest,
            _: *const InterceptionContext,
        ) InterceptionDecision {
            return .network_fallback;
        }
    };

    var mock = MockInterceptor{};
    const interceptor = createInterceptor(MockInterceptor, &mock);

    var ctx = InterceptionContext{ .allocator = std.testing.allocator };
    const decision = interceptor.intercept(std.testing.allocator, undefined, &ctx);

    try std.testing.expect(decision == .network_fallback);
}
