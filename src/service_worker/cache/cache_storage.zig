//! CacheStorage Interface
//!
//! Manages multiple named caches for a service worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cachestorage-interface
//!
//! WebIDL:
//! ```idl
//! [SecureContext, Exposed=(Window,Worker)]
//! interface CacheStorage {
//!   [NewObject] Promise<(Response or undefined)> match(RequestInfo request, optional MultiCacheQueryOptions options = {});
//!   [NewObject] Promise<boolean> has(DOMString cacheName);
//!   [NewObject] Promise<Cache> open(DOMString cacheName);
//!   [NewObject] Promise<boolean> delete(DOMString cacheName);
//!   [NewObject] Promise<sequence<DOMString>> keys();
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const CacheQueryOptions = types.CacheQueryOptions;
const MultiCacheQueryOptions = types.MultiCacheQueryOptions;
const StoredResponse = types.StoredResponse;
const StoredRequest = types.StoredRequest;
const HeaderEntry = types.HeaderEntry;

const cache_module = @import("cache.zig");
const Cache = cache_module.Cache;

const iface_types = @import("../interfaces/types.zig");
const Promise = iface_types.Promise;
const VoidPromise = iface_types.VoidPromise;
const BoolPromise = iface_types.BoolPromise;

/// CacheStorage interface.
///
/// Manages multiple named caches for a service worker.
///
/// Spec: https://w3c.github.io/ServiceWorker/#cachestorage-interface
pub const CacheStorage = struct {
    allocator: Allocator,

    /// Map of cache name to Cache instance.
    caches: std.StringHashMapUnmanaged(*Cache),

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .caches = .{},
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free all caches
        var iter = self.caches.iterator();
        while (iter.next()) |entry| {
            // Free the key (cache name)
            self.allocator.free(entry.key_ptr.*);
            // Deinit the cache
            entry.value_ptr.*.deinit();
        }
        self.caches.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Search all caches for a matching response.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-match
    pub fn match(
        self: *Self,
        request_url: []const u8,
        request_method: []const u8,
        request_headers: []const HeaderEntry,
        options: MultiCacheQueryOptions,
    ) !Promise(?*StoredResponse) {
        var promise = Promise(?*StoredResponse).init();

        const cache_opts = options.toCacheQueryOptions();

        // If cache_name is specified, only search that cache
        if (options.cache_name) |name| {
            if (self.caches.get(name)) |cache| {
                const result = try cache.match(
                    request_url,
                    request_method,
                    request_headers,
                    cache_opts,
                );
                promise.resolve(result.value.?);
                return promise;
            }
            // Cache not found
            promise.resolve(null);
            return promise;
        }

        // Search all caches in insertion order
        var iter = self.caches.iterator();
        while (iter.next()) |entry| {
            const cache = entry.value_ptr.*;
            const result = try cache.match(
                request_url,
                request_method,
                request_headers,
                cache_opts,
            );
            if (result.value.?) |response| {
                promise.resolve(response);
                return promise;
            }
        }

        promise.resolve(null);
        return promise;
    }

    /// Check if a cache with the given name exists.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-has
    pub fn has(self: *Self, cache_name: []const u8) BoolPromise {
        var promise = BoolPromise.init();
        promise.resolve(self.caches.contains(cache_name));
        return promise;
    }

    /// Open a cache, creating it if it doesn't exist.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-open
    pub fn open(self: *Self, cache_name: []const u8) !Promise(*Cache) {
        var promise = Promise(*Cache).init();

        // If cache exists, return it
        if (self.caches.get(cache_name)) |cache| {
            promise.resolve(cache);
            return promise;
        }

        // Create new cache
        const cache = try Cache.init(self.allocator, cache_name);
        errdefer cache.deinit();

        // Store with duplicated key
        const key = try self.allocator.dupe(u8, cache_name);
        errdefer self.allocator.free(key);

        try self.caches.put(self.allocator, key, cache);

        promise.resolve(cache);
        return promise;
    }

    /// Delete a cache by name.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-delete
    pub fn delete(self: *Self, cache_name: []const u8) BoolPromise {
        var promise = BoolPromise.init();

        if (self.caches.fetchRemove(cache_name)) |entry| {
            // Free the key
            self.allocator.free(entry.key);
            // Deinit the cache
            entry.value.deinit();
            promise.resolve(true);
        } else {
            promise.resolve(false);
        }

        return promise;
    }

    /// Get all cache names.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-keys
    pub fn keys(self: *Self) !Promise([][]const u8) {
        var promise = Promise([][]const u8).init();

        var names = std.ArrayList([]const u8).init(self.allocator);
        errdefer names.deinit();

        var iter = self.caches.iterator();
        while (iter.next()) |entry| {
            // Return references to the stored keys (not duplicated)
            try names.append(entry.key_ptr.*);
        }

        promise.resolve(try names.toOwnedSlice());
        return promise;
    }

    // =========================================================================
    // Utility Methods
    // =========================================================================

    /// Get the number of caches.
    pub fn count(self: *const Self) u32 {
        return self.caches.count();
    }

    /// Check if there are no caches.
    pub fn isEmpty(self: *const Self) bool {
        return self.caches.count() == 0;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "CacheStorage.init and deinit" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    try std.testing.expect(storage.isEmpty());
}

test "CacheStorage.open creates cache" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const promise = try storage.open("v1");
    try std.testing.expect(promise.isFulfilled());

    const cache = promise.value.?;
    try std.testing.expectEqualStrings("v1", cache.name);
    try std.testing.expectEqual(@as(u32, 1), storage.count());
}

test "CacheStorage.open returns existing cache" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const promise1 = try storage.open("v1");
    const promise2 = try storage.open("v1");

    // Should be the same cache
    try std.testing.expectEqual(promise1.value.?, promise2.value.?);
    try std.testing.expectEqual(@as(u32, 1), storage.count());
}

test "CacheStorage.has" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    try std.testing.expect(!storage.has("v1").value.?);

    _ = try storage.open("v1");

    try std.testing.expect(storage.has("v1").value.?);
    try std.testing.expect(!storage.has("v2").value.?);
}

test "CacheStorage.delete" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    _ = try storage.open("v1");
    try std.testing.expectEqual(@as(u32, 1), storage.count());

    // Delete existing cache
    const del_promise = storage.delete("v1");
    try std.testing.expect(del_promise.value.?);
    try std.testing.expect(storage.isEmpty());

    // Delete non-existent cache
    const del_promise2 = storage.delete("v1");
    try std.testing.expect(!del_promise2.value.?);
}

test "CacheStorage.keys" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    _ = try storage.open("v1");
    _ = try storage.open("v2");
    _ = try storage.open("v3");

    const promise = try storage.keys();
    try std.testing.expect(promise.isFulfilled());

    const names = promise.value.?;
    defer allocator.free(names);

    try std.testing.expectEqual(@as(usize, 3), names.len);
}

test "CacheStorage.match searches all caches" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    // Create caches and add entries
    const cache1_promise = try storage.open("v1");
    const cache1 = cache1_promise.value.?;

    _ = try cache1.put(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{},
        "from v1",
        .basic,
    );

    // Match should find it
    const match_promise = try storage.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try std.testing.expect(match_promise.isFulfilled());
    try std.testing.expect(match_promise.value.? != null);

    const response = match_promise.value.?.?;
    try std.testing.expectEqualStrings("from v1", response.body.?);
}

test "CacheStorage.match with cache_name" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    // Create two caches
    const cache1_promise = try storage.open("v1");
    const cache1 = cache1_promise.value.?;

    const cache2_promise = try storage.open("v2");
    const cache2 = cache2_promise.value.?;

    _ = try cache1.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "from v1", .basic);
    _ = try cache2.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "from v2", .basic);

    // Match in specific cache
    const match_promise = try storage.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{ .cache_name = "v2" },
    );
    try std.testing.expect(match_promise.value.? != null);
    try std.testing.expectEqualStrings("from v2", match_promise.value.?.?.body.?);
}

test "CacheStorage.match non-existent cache_name" {
    const allocator = std.testing.allocator;

    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const match_promise = try storage.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{ .cache_name = "nonexistent" },
    );
    try std.testing.expect(match_promise.value.? == null);
}
