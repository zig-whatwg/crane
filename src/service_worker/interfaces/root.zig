//! Service Worker Client-Side WebIDL Interfaces
//!
//! These interfaces are exposed to Window and Worker contexts for interacting
//! with service workers from client code.
//!
//! Spec: https://w3c.github.io/ServiceWorker/
//!
//! ## Overview
//!
//! This module provides the WebIDL interfaces for Service Workers:
//!
//! - **ServiceWorkerInterface**: Represents a service worker (§4.1)
//! - **ServiceWorkerRegistrationInterface**: Represents a registration (§4.2)
//! - **ServiceWorkerContainer**: Main entry point via navigator.serviceWorker (§4.3)
//! - **NavigationPreloadManager**: Manages navigation preload (§4.4)
//! - **ClientInterface**: Represents a controlled client (§4.6)
//! - **WindowClientInterface**: Extended client for windows (§4.6)
//!
//! ## Usage
//!
//! ```zig
//! const sw = @import("service_worker");
//!
//! // Get the container (would be navigator.serviceWorker in JS)
//! const container = try sw.interfaces.ServiceWorkerContainer.init(
//!     allocator, client, &registration_map);
//! defer container.deinit();
//!
//! // Register a service worker
//! const promise = try container.register("/sw.js", .{ .scope = "/app/" });
//! if (promise.isFulfilled()) {
//!     const registration = promise.value.?;
//!     // ...
//! }
//! ```

const std = @import("std");

// Types
pub const types = @import("types.zig");
pub const ServiceWorkerState = types.ServiceWorkerState;
pub const WorkerType = types.WorkerType;
pub const UpdateViaCacheMode = types.UpdateViaCacheMode;
pub const FrameType = types.FrameType;
pub const ClientType = types.ClientType;
pub const VisibilityState = types.VisibilityState;
pub const RegistrationOptions = types.RegistrationOptions;
pub const NavigationPreloadState = types.NavigationPreloadState;
pub const EventHandler = types.EventHandler;
pub const StructuredSerializeOptions = types.StructuredSerializeOptions;
pub const Promise = types.Promise;
pub const VoidPromise = types.VoidPromise;
pub const BoolPromise = types.BoolPromise;

// ServiceWorker interface (§4.1)
pub const service_worker = @import("service_worker.zig");
pub const ServiceWorkerInterface = service_worker.ServiceWorkerInterface;

// ServiceWorkerRegistration interface (§4.2)
pub const registration = @import("registration.zig");
pub const ServiceWorkerRegistrationInterface = registration.ServiceWorkerRegistrationInterface;

// ServiceWorkerContainer interface (§4.3)
pub const container = @import("container.zig");
pub const ServiceWorkerContainer = container.ServiceWorkerContainer;

// NavigationPreloadManager interface (§4.4)
pub const navigation_preload = @import("navigation_preload.zig");
pub const NavigationPreloadManager = navigation_preload.NavigationPreloadManager;

// Client and WindowClient interfaces (§4.6)
pub const client = @import("client.zig");
pub const ClientInterface = client.ClientInterface;
pub const WindowClientInterface = client.WindowClientInterface;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}
