//! Cache Backend Trait - HTTP Caching
//!
//! This module defines the CacheBackend interface that abstracts cache
//! storage for the Fetch specification. Implementations can use in-memory
//! storage, disk storage, or other backends.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-cache

const std = @import("std");
const Allocator = std.mem.Allocator;
const cache_key = @import("cache_key.zig");
const CacheKey = cache_key.CacheKey;
const cache_entry = @import("cache_entry.zig");
const CacheEntry = cache_entry.CacheEntry;

/// HTTP cache backend interface.
///
/// Implementations:
/// - MemoryCacheBackend: In-memory LRU cache
/// - (Future) DiskCacheBackend: Persistent disk cache
///
/// Usage:
/// ```zig
/// var memory = MemoryCacheBackend.init(allocator);
/// defer memory.deinit();
///
/// const backend = memory.asBackend();
/// const entry = try backend.match(&key);
/// ```
pub const CacheBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Find a matching cached entry for a request key.
        /// Returns null if no match or entry is stale.
        match: *const fn (ptr: *anyopaque, key: *const CacheKey) ?*CacheEntry,

        /// Store a response in the cache.
        /// May evict existing entries if cache is full.
        store: *const fn (ptr: *anyopaque, key: *const CacheKey, entry: *CacheEntry) anyerror!void,

        /// Delete a cached entry by key.
        delete: *const fn (ptr: *anyopaque, key: *const CacheKey) void,

        /// Clear all entries from the cache.
        clear: *const fn (ptr: *anyopaque) void,

        /// Clean up backend resources.
        deinit: *const fn (ptr: *anyopaque) void,
    };

    /// Find a matching cached entry.
    pub fn match(self: CacheBackend, key: *const CacheKey) ?*CacheEntry {
        return self.vtable.match(self.ptr, key);
    }

    /// Store a response in the cache.
    pub fn store(self: CacheBackend, key: *const CacheKey, entry: *CacheEntry) !void {
        return self.vtable.store(self.ptr, key, entry);
    }

    /// Delete a cached entry.
    pub fn delete(self: CacheBackend, key: *const CacheKey) void {
        self.vtable.delete(self.ptr, key);
    }

    /// Clear all entries.
    pub fn clear(self: CacheBackend) void {
        self.vtable.clear(self.ptr);
    }

    /// Clean up backend.
    pub fn deinit(self: CacheBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Create a CacheBackend from MemoryCacheBackend.
pub fn memoryCacheAsBackend(memory: *@import("memory_backend.zig").MemoryCacheBackend) CacheBackend {
    const MemoryCacheBackend = @import("memory_backend.zig").MemoryCacheBackend;

    const vtable = struct {
        fn match(ptr: *anyopaque, key: *const CacheKey) ?*CacheEntry {
            const self: *MemoryCacheBackend = @ptrCast(@alignCast(ptr));
            return self.match(key);
        }

        fn store(ptr: *anyopaque, key: *const CacheKey, entry: *CacheEntry) anyerror!void {
            const self: *MemoryCacheBackend = @ptrCast(@alignCast(ptr));
            return self.store(key, entry);
        }

        fn delete(ptr: *anyopaque, key: *const CacheKey) void {
            const self: *MemoryCacheBackend = @ptrCast(@alignCast(ptr));
            self.delete(key);
        }

        fn clear(ptr: *anyopaque) void {
            const self: *MemoryCacheBackend = @ptrCast(@alignCast(ptr));
            self.clear();
        }

        fn deinitFn(ptr: *anyopaque) void {
            const self: *MemoryCacheBackend = @ptrCast(@alignCast(ptr));
            self.deinit();
        }
    };

    const static_vtable = CacheBackend.VTable{
        .match = vtable.match,
        .store = vtable.store,
        .delete = vtable.delete,
        .clear = vtable.clear,
        .deinit = vtable.deinitFn,
    };

    return .{
        .ptr = memory,
        .vtable = &static_vtable,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "CacheBackend - interface through MemoryCacheBackend" {
    const allocator = std.testing.allocator;
    const MemoryCacheBackend = @import("memory_backend.zig").MemoryCacheBackend;

    var memory = MemoryCacheBackend.init(allocator);
    defer memory.deinit();

    const backend = memoryCacheAsBackend(&memory);

    const now = std.time.timestamp();

    // Create a key
    const key = try CacheKey.init(allocator, "https://example.com/api", "GET", null);
    defer key.deinit();

    // Create an entry
    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=31536000" },
    };
    const entry = try CacheEntry.init(allocator, 200, &headers, "response body", now - 1, now);

    // Store through interface
    try backend.store(key, entry);

    // Match through interface
    const found = backend.match(key);
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("response body", found.?.body.?);

    // Delete through interface
    backend.delete(key);
    try std.testing.expect(backend.match(key) == null);
}
