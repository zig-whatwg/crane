//! Cache API Module
//!
//! Implementation of the Cache API for Service Workers.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cache-objects
//!
//! ## Overview
//!
//! The Cache API provides a mechanism for storing Request/Response pairs
//! for offline access and efficient caching strategies.
//!
//! ## Module Structure
//!
//! - **types.zig**: Supporting types (CacheQueryOptions, StoredRequest, StoredResponse, etc.)
//! - **vary.zig**: Vary header matching per HTTP spec
//! - **cache.zig**: Cache interface for storing request/response pairs
//! - **cache_storage.zig**: CacheStorage interface for managing named caches
//!
//! ## Usage
//!
//! ```zig
//! const cache = @import("service_worker").cache;
//!
//! // Create a CacheStorage
//! const storage = try cache.CacheStorage.init(allocator);
//! defer storage.deinit();
//!
//! // Open a named cache
//! const my_cache = (try storage.open("v1")).value.?;
//!
//! // Store a request/response pair
//! _ = try my_cache.put(
//!     "https://example.com/api",
//!     "GET",
//!     &[_]cache.HeaderEntry{},
//!     200,
//!     "OK",
//!     &[_]cache.HeaderEntry{.{ .name = "Content-Type", .value = "application/json" }},
//!     "{\"data\": 1}",
//!     .basic,
//! );
//!
//! // Retrieve from cache
//! const response = (try my_cache.match("https://example.com/api", "GET", &[_]cache.HeaderEntry{}, .{})).value.?;
//! ```

const std = @import("std");

// Types
pub const types = @import("types.zig");
pub const CacheQueryOptions = types.CacheQueryOptions;
pub const MultiCacheQueryOptions = types.MultiCacheQueryOptions;
pub const HeaderEntry = types.HeaderEntry;
pub const ResponseType = types.ResponseType;
pub const StoredRequest = types.StoredRequest;
pub const StoredResponse = types.StoredResponse;
pub const CacheEntry = types.CacheEntry;

// Vary header matching
pub const vary = @import("vary.zig");
pub const parseVaryHeader = vary.parseVaryHeader;
pub const freeVaryList = vary.freeVaryList;
pub const isVaryStar = vary.isVaryStar;
pub const varyMatches = vary.varyMatches;
pub const urlMatches = vary.urlMatches;
pub const methodMatches = vary.methodMatches;
pub const requestMatches = vary.requestMatches;

// Cache interface
pub const cache = @import("cache.zig");
pub const Cache = cache.Cache;

// CacheStorage interface
pub const cache_storage = @import("cache_storage.zig");
pub const CacheStorage = cache_storage.CacheStorage;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}
