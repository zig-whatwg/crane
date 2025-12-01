//! Service Worker Events Module
//!
//! Event types for Service Worker lifecycle and functional events.
//!
//! Spec: https://w3c.github.io/ServiceWorker/
//!
//! ## Overview
//!
//! - **ExtendableEvent**: Base event with waitUntil() support
//! - **InstallEvent**: Fired during installation (extends ExtendableEvent)
//! - **FetchEvent**: Fired when intercepting fetch requests
//! - **ExtendableMessageEvent**: Fired when receiving messages
//! - **Router**: URL pattern matching for static routing
//!
//! ## Usage
//!
//! ```zig
//! const events = @import("service_worker").events;
//!
//! // Create an install event
//! const install = try events.InstallEvent.init(allocator, .{});
//! defer install.deinit();
//!
//! // Add router rules during install
//! _ = try install.addRoutes(&[_]events.RouterRule{
//!     .{
//!         .condition = .{ .url_pattern = .{ .pathname = "/static/*" } },
//!         .source = .network,
//!     },
//! });
//!
//! // Create a fetch event
//! var request: Request = ...;
//! const fetch = try events.FetchEvent.init(allocator, .{
//!     .request = &request,
//!     .client_id = "client-123",
//! });
//! defer fetch.deinit();
//!
//! // Respond with custom response
//! try fetch.respondWith(&my_response);
//! ```

const std = @import("std");

// ExtendableEvent
pub const extendable_event = @import("extendable_event.zig");
pub const ExtendableEvent = extendable_event.ExtendableEvent;
pub const ExtendableEventInit = extendable_event.ExtendableEventInit;
pub const PromiseHandle = extendable_event.PromiseHandle;

// FetchEvent
pub const fetch_event = @import("fetch_event.zig");
pub const FetchEvent = fetch_event.FetchEvent;
pub const FetchEventInit = fetch_event.FetchEventInit;
pub const StoredResponse = fetch_event.StoredResponse;

// InstallEvent
pub const install_event = @import("install_event.zig");
pub const InstallEvent = install_event.InstallEvent;

// ExtendableMessageEvent
pub const extendable_message_event = @import("extendable_message_event.zig");
pub const ExtendableMessageEvent = extendable_message_event.ExtendableMessageEvent;
pub const ExtendableMessageEventInit = extendable_message_event.ExtendableMessageEventInit;
pub const MessageSource = extendable_message_event.MessageSource;

// Router
pub const router_mod = @import("router.zig");
pub const Router = router_mod.Router;
pub const RouterRule = router_mod.RouterRule;
pub const RouterCondition = router_mod.RouterCondition;
pub const RouterSource = router_mod.RouterSource;
pub const URLPattern = router_mod.URLPattern;
pub const RequestCondition = router_mod.RequestCondition;
pub const CacheSource = router_mod.CacheSource;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}
