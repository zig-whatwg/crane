//! HTTP Cache Module - WHATWG Fetch Implementation
//!
//! This module provides HTTP caching per RFC 7234 and the Fetch specification.
//!
//! ## Components
//!
//! - `cache_control.zig` - Cache-Control header parsing
//! - `freshness.zig` - Freshness lifetime and age calculations
//! - `cache_key.zig` - Cache key generation and matching
//! - `cache_entry.zig` - Cached response entry structure
//! - `memory_backend.zig` - In-memory LRU cache backend
//! - `backend.zig` - CacheBackend trait for pluggable backends
//!
//! ## Usage
//!
//! ```zig
//! const cache = @import("fetch").cache;
//!
//! // Create an in-memory cache
//! var memory_cache = cache.MemoryCacheBackend.init(allocator);
//! defer memory_cache.deinit();
//!
//! // Create a cache key from request
//! const key = try cache.CacheKey.init(allocator, url, method, partition_key);
//! defer key.deinit();
//!
//! // Look up cached response
//! if (memory_cache.match(key)) |entry| {
//!     // Use cached response
//!     if (entry.isFresh(false, std.time.timestamp())) {
//!         return entry;
//!     }
//! }
//!
//! // Store response in cache
//! const entry = try cache.CacheEntry.init(allocator, status, headers, body, req_time, res_time);
//! try memory_cache.store(key, entry);
//! ```
//!
//! ## Spec References
//!
//! - https://fetch.spec.whatwg.org/#http-cache
//! - https://httpwg.org/specs/rfc7234.html (HTTP Caching)
//! - https://httpwg.org/specs/rfc5861.html (stale-while-revalidate, stale-if-error)

const std = @import("std");

pub const cache_control = @import("cache_control.zig");
pub const freshness_mod = @import("freshness.zig");
pub const cache_key = @import("cache_key.zig");
pub const cache_entry = @import("cache_entry.zig");
pub const memory_backend = @import("memory_backend.zig");
pub const backend = @import("backend.zig");

// Re-export main types
pub const CacheControl = cache_control.CacheControl;
pub const CacheTiming = freshness_mod.CacheTiming;
pub const CacheKey = cache_key.CacheKey;
pub const VaryEntry = cache_key.VaryEntry;
pub const CacheEntry = cache_entry.CacheEntry;
pub const MemoryCacheBackend = memory_backend.MemoryCacheBackend;
pub const CacheStats = memory_backend.CacheStats;
pub const CacheBackend = backend.CacheBackend;
pub const memoryCacheAsBackend = backend.memoryCacheAsBackend;

// Re-export utility functions
pub const isCacheableMethod = cache_key.isCacheableMethod;
pub const isCacheableStatus = cache_key.isCacheableStatus;
pub const parseHttpDate = freshness_mod.parseHttpDate;
pub const calculateCurrentAge = freshness_mod.calculateCurrentAge;
pub const calculateFreshnessLifetime = freshness_mod.calculateFreshnessLifetime;
pub const isFresh = freshness_mod.isFresh;
pub const canServeStaleWhileRevalidate = freshness_mod.canServeStaleWhileRevalidate;
pub const canServeStaleIfError = freshness_mod.canServeStaleIfError;
pub const timeUntilStale = freshness_mod.timeUntilStale;

test {
    std.testing.refAllDecls(@This());
}
