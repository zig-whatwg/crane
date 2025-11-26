//! Cache API Mock
//!
//! Mock implementation of the Cache API from the Service Workers specification.
//! The Cache API provides storage for Request/Response pairs.
//!
//! ## Specification
//!
//! - Service Workers: https://w3c.github.io/ServiceWorker/
//! - Cache Interface: https://w3c.github.io/ServiceWorker/#cache-interface
//! - CacheStorage Interface: https://w3c.github.io/ServiceWorker/#cachestorage-interface
//!
//! ## Why This Mock Exists
//!
//! The WHATWG Storage spec (https://storage.spec.whatwg.org/) defines Cache API
//! as one of the storage endpoints. Each origin's storage bucket contains a
//! "bottle" for Cache API data. This mock allows the Storage spec to be
//! implemented without a full Cache API implementation.
//!
//! ## TODO: Full Implementation Required
//!
//! This mock should be replaced with a complete implementation that includes:
//! - Request/Response object storage
//! - Query matching with CacheQueryOptions
//! - VaryHeader handling
//! - Batch operations (addAll)
//! - Integration with Fetch API
//!

const std = @import("std");
const root = @import("root.zig");
const MockError = root.MockError;

/// Mock Cache interface
///
/// Represents a single named cache that stores Request/Response pairs.
/// In the full implementation, this would support:
/// - match(request, options) -> Response?
/// - matchAll(request?, options?) -> [Response]
/// - add(request) -> void
/// - addAll(requests) -> void
/// - put(request, response) -> void
/// - delete(request, options?) -> bool
/// - keys(request?, options?) -> [Request]
///
/// TODO(Cache API): Implement full Cache interface per Service Workers spec
/// https://w3c.github.io/ServiceWorker/#cache-interface
pub const Cache = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Self {
        const name_copy = try allocator.dupe(u8, name);
        return Self{
            .allocator = allocator,
            .name = name_copy,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
    }

    /// Match a request against the cache
    ///
    /// TODO(Cache API): Implement request matching with CacheQueryOptions
    /// - ignoreSearch: Ignore query string
    /// - ignoreMethod: Ignore HTTP method
    /// - ignoreVary: Ignore Vary header
    pub fn match(self: *Self, request: anytype) MockError!?*anyopaque {
        _ = self;
        _ = request;
        return MockError.NotImplemented;
    }

    /// Add a request to the cache (fetches and stores)
    ///
    /// TODO(Cache API): Implement fetch + put
    pub fn add(self: *Self, request: anytype) MockError!void {
        _ = self;
        _ = request;
        return MockError.NotImplemented;
    }

    /// Add multiple requests to the cache
    ///
    /// TODO(Cache API): Implement batch fetch + put
    pub fn addAll(self: *Self, requests: anytype) MockError!void {
        _ = self;
        _ = requests;
        return MockError.NotImplemented;
    }

    /// Store a request/response pair
    ///
    /// TODO(Cache API): Implement storage with Response body consumption
    pub fn put(self: *Self, request: anytype, response: anytype) MockError!void {
        _ = self;
        _ = request;
        _ = response;
        return MockError.NotImplemented;
    }

    /// Delete entries matching request
    ///
    /// TODO(Cache API): Implement deletion with options
    pub fn delete(self: *Self, request: anytype) MockError!bool {
        _ = self;
        _ = request;
        return MockError.NotImplemented;
    }

    /// Get all cached request keys
    ///
    /// TODO(Cache API): Return iterator of Request objects
    pub fn keys(self: *Self) MockError!void {
        _ = self;
        return MockError.NotImplemented;
    }
};

/// Mock CacheStorage interface
///
/// Provides access to named Cache objects. In the full implementation:
/// - match(request, options?) -> Response? (searches all caches)
/// - has(cacheName) -> bool
/// - open(cacheName) -> Cache
/// - delete(cacheName) -> bool
/// - keys() -> [string]
///
/// TODO(Cache API): Implement full CacheStorage interface
/// https://w3c.github.io/ServiceWorker/#cachestorage-interface
pub const CacheStorage = struct {
    allocator: std.mem.Allocator,
    caches: std.StringHashMap(*Cache),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .caches = std.StringHashMap(*Cache).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.caches.valueIterator();
        while (iter.next()) |cache| {
            cache.*.deinit();
            self.allocator.destroy(cache.*);
        }
        self.caches.deinit();
    }

    /// Check if a named cache exists
    pub fn has(self: *Self, name: []const u8) bool {
        return self.caches.contains(name);
    }

    /// Open (or create) a named cache
    ///
    /// TODO(Cache API): Full implementation should handle quota management
    pub fn open(self: *Self, name: []const u8) !*Cache {
        if (self.caches.get(name)) |cache| {
            return cache;
        }

        const cache = try self.allocator.create(Cache);
        cache.* = try Cache.init(self.allocator, name);
        try self.caches.put(cache.name, cache);
        return cache;
    }

    /// Delete a named cache
    pub fn deleteCacheByName(self: *Self, name: []const u8) bool {
        if (self.caches.fetchRemove(name)) |entry| {
            entry.value.deinit();
            self.allocator.destroy(entry.value);
            return true;
        }
        return false;
    }

    /// Search all caches for a matching response
    ///
    /// TODO(Cache API): Implement cross-cache search
    pub fn match(self: *Self, request: anytype) MockError!?*anyopaque {
        _ = self;
        _ = request;
        return MockError.NotImplemented;
    }

    /// Get estimated storage usage
    ///
    /// For Storage API integration - returns mock estimate
    pub fn estimateUsage(self: *Self) u64 {
        // Mock: Return 0 bytes since we don't store anything
        _ = self;
        return 0;
    }
};

/// Cache Query Options
///
/// TODO(Cache API): Use for match operations
pub const CacheQueryOptions = struct {
    ignore_search: bool = false,
    ignore_method: bool = false,
    ignore_vary: bool = false,
};

test "CacheStorage basic operations" {
    const allocator = std.testing.allocator;

    var storage = CacheStorage.init(allocator);
    defer storage.deinit();

    // Test open creates cache
    const cache = try storage.open("test-cache");
    try std.testing.expect(storage.has("test-cache"));
    try std.testing.expectEqualStrings("test-cache", cache.name);

    // Test delete removes cache
    try std.testing.expect(storage.deleteCacheByName("test-cache"));
    try std.testing.expect(!storage.has("test-cache"));
}

test "Cache mock methods return NotImplemented" {
    const allocator = std.testing.allocator;

    var cache = try Cache.init(allocator, "test");
    defer cache.deinit();

    // All mock methods should return NotImplemented
    try std.testing.expectError(MockError.NotImplemented, cache.match("request"));
    try std.testing.expectError(MockError.NotImplemented, cache.add("request"));
    try std.testing.expectError(MockError.NotImplemented, cache.put("request", "response"));
    try std.testing.expectError(MockError.NotImplemented, cache.delete("request"));
    try std.testing.expectError(MockError.NotImplemented, cache.keys());
}
