//! Service Worker Integration Module
//!
//! This module provides integration between Service Workers and other
//! WHATWG specifications, primarily the Fetch specification.
//!
//! ## Overview
//!
//! The integration layer connects:
//! - Fetch specification's HTTP fetch algorithm to SW interception
//! - Resource Timing API to SW timing information
//! - Navigation preload to parallel fetching
//!
//! ## Usage
//!
//! ```zig
//! const integration = @import("service_worker").integration;
//!
//! // Check if a request should be intercepted
//! if (integration.shouldIntercept(request, registration_map)) {
//!     const result = integration.interceptFetch(request, context);
//!     switch (result) {
//!         .response => |resp| // Use SW response
//!         .no_interception => // Continue to network
//!         .err => |e| // Handle error
//!     }
//! }
//! ```

const std = @import("std");

// Fetch interception
pub const fetch_intercept = @import("fetch_intercept.zig");
pub const interceptFetch = fetch_intercept.interceptFetch;
pub const shouldIntercept = fetch_intercept.shouldIntercept;
pub const InterceptionResult = fetch_intercept.InterceptionResult;
pub const InterceptionContext = fetch_intercept.InterceptionContext;
pub const InterceptedResponse = fetch_intercept.InterceptedResponse;
pub const InterceptionError = fetch_intercept.InterceptionError;
pub const RequestForInterception = fetch_intercept.RequestForInterception;
pub const ResponseSource = fetch_intercept.ResponseSource;
pub const ServiceWorkersMode = fetch_intercept.ServiceWorkersMode;

// Timing integration
pub const timing = @import("timing.zig");
pub const ServiceWorkerTiming = timing.ServiceWorkerTiming;

// Registrar implementation
pub const registrar_impl = @import("registrar_impl.zig");
pub const ServiceWorkerRegistrarImpl = registrar_impl.ServiceWorkerRegistrarImpl;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}
