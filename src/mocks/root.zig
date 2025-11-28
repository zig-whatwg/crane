//! Mocks Module
//!
//! This module provides temporary mock implementations for WHATWG/W3C specs
//! that are not yet implemented. These mocks allow dependent specs (like
//! Storage and IndexedDB) to be developed without waiting for full implementations.
//!
//! ## Mocked Specs
//!
//! - **Cache API** (Service Workers): For Storage spec storage endpoints
//! - **File System API**: For Storage spec storage endpoints
//! - **Structured Clone**: For IndexedDB value serialization
//!
//! ## Usage
//!
//! ```zig
//! const mocks = @import("mocks");
//!
//! // Use structured clone mock for testing
//! const cloned = try mocks.structured_clone.clone(allocator, value);
//! ```
//!
//! ## TODO
//!
//! All mocks in this module should eventually be replaced with full
//! implementations of their respective specifications:
//!
//! - Cache API: https://w3c.github.io/ServiceWorker/#cache-interface
//! - File System: https://fs.spec.whatwg.org/
//! - Structured Clone: https://html.spec.whatwg.org/multipage/structured-data.html
//!

const std = @import("std");

pub const cache_api = @import("cache_api.zig");
pub const file_system = @import("file_system.zig");
pub const structured_clone = @import("structured_clone.zig");
pub const environment = @import("environment.zig");
pub const origin_utils = @import("origin_utils.zig");
pub const service_worker = @import("service_worker.zig");
pub const form_data = @import("form_data.zig");

// Environment exports for convenience.
pub const EnvironmentSettingsObject = environment.EnvironmentSettingsObject;
pub const PolicyContainer = environment.PolicyContainer;
pub const ReferrerPolicy = environment.ReferrerPolicy;
pub const EmbedderPolicy = environment.EmbedderPolicy;
pub const createMockGlobal = environment.createMockGlobal;
pub const destroyMockGlobal = environment.destroyMockGlobal;
pub const sameOrigin = environment.sameOrigin;

// Origin utilities exports
pub const isSameOriginDomain = origin_utils.isSameOriginDomain;
pub const isSameSite = origin_utils.isSameSite;
pub const isSchemelesslySameSite = origin_utils.isSchemelesslySameSite;
pub const getRegistrableDomain = origin_utils.getRegistrableDomain;

// Service worker exports
pub const ServiceWorkerController = service_worker.ServiceWorkerController;
pub const ServiceWorkersMode = service_worker.ServiceWorkersMode;

// FormData exports
pub const FormData = form_data.FormData;
pub const encodeMultipart = form_data.encodeMultipart;
pub const parseUrlEncoded = form_data.parseUrlEncoded;

/// Common error type for mock implementations
pub const MockError = error{
    /// Operation not yet implemented - this is expected for mocks
    NotImplemented,
    /// Operation would require full spec implementation
    RequiresFullImplementation,
    /// Type not supported by mock
    UnsupportedType,
    /// Out of memory
    OutOfMemory,
};

test {
    std.testing.refAllDecls(@This());
}
