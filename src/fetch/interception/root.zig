//! WHATWG Fetch Standard - Interception Module
//!
//! This module provides the service worker fetch interception infrastructure.
//! It defines a VTable-based interface that allows service workers to intercept
//! fetch requests without creating circular module dependencies.
//!
//! ## Architecture
//!
//! ```
//! fetch (this module)          service_worker              Browser
//!    │                              │                         │
//!    │ defines FetchInterceptor     │ implements it           │ wires them
//!    │ defines registry             │                         │
//!    │                              │                         │
//!    └──────────────────────────────┴─────────────────────────┘
//! ```
//!
//! ## Usage
//!
//! **In http_fetch.zig (fetch algorithm):**
//! ```zig
//! const interception = @import("interception/root.zig");
//!
//! if (request.service_workers_mode == .all and !request.skip_service_worker_interception) {
//!     if (interception.registry.get()) |interceptor| {
//!         switch (interceptor.intercept(allocator, request, &ctx)) {
//!             .network_fallback => {}, // proceed with network
//!             .response => |r| return r,
//!             .err => return networkError(),
//!         }
//!     }
//! }
//! ```
//!
//! **In Browser.zig (startup):**
//! ```zig
//! const interception = @import("fetch").interception;
//!
//! // During init:
//! interception.registry.register(&sw_interceptor.asFetchInterceptor());
//!
//! // During deinit:
//! interception.registry.unregister();
//! ```
//!
//! Spec: https://fetch.spec.whatwg.org/#http-fetch
//! Spec: https://w3c.github.io/ServiceWorker/#handle-fetch

// =============================================================================
// Public API
// =============================================================================

pub const fetch_interceptor = @import("fetch_interceptor.zig");
pub const registry = @import("registry.zig");

// Re-export commonly used types for convenience
pub const FetchInterceptor = fetch_interceptor.FetchInterceptor;
pub const InterceptionDecision = fetch_interceptor.InterceptionDecision;
pub const InterceptionContext = fetch_interceptor.InterceptionContext;
pub const InterceptionError = fetch_interceptor.InterceptionError;
pub const createInterceptor = fetch_interceptor.createInterceptor;

// =============================================================================
// Tests
// =============================================================================

test {
    // Run all submodule tests
    _ = fetch_interceptor;
    _ = registry;
}
