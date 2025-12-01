//! Service Worker Global Scope APIs
//!
//! APIs available inside a running service worker context.
//!
//! Spec: https://w3c.github.io/ServiceWorker/
//!
//! ## Overview
//!
//! This module provides:
//!
//! - **ServiceWorkerGlobalScope**: The global object inside a service worker (§4.5)
//! - **Clients**: API for accessing controlled clients (§4.7)
//!
//! ## Usage
//!
//! ```zig
//! const sw = @import("service_worker");
//!
//! // Create a service worker global scope
//! const scope = try sw.global.ServiceWorkerGlobalScope.init(
//!     allocator, internal_sw, internal_reg);
//! defer scope.deinit();
//!
//! // Access clients API
//! const clients = scope.getClients();
//!
//! // Set up event handlers
//! scope.setOnfetch(myFetchHandler);
//! scope.setOninstall(myInstallHandler);
//!
//! // Skip waiting
//! const promise = scope.skipWaiting();
//! ```

const std = @import("std");

// ServiceWorkerGlobalScope (§4.5)
pub const service_worker_global_scope = @import("service_worker_global_scope.zig");
pub const ServiceWorkerGlobalScope = service_worker_global_scope.ServiceWorkerGlobalScope;

// Clients interface (§4.7)
pub const clients = @import("clients.zig");
pub const Clients = clients.Clients;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}
