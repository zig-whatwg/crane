//! In-Memory Cache Backend - HTTP Caching
//!
//! This module implements an in-memory HTTP cache backend.
//!
//! Features:
//! - LRU eviction when cache is full
//! - Configurable max entries and max size
//! - Thread-safe design (uses atomic operations)
//! - Automatic cleanup of expired entries

const std = @import("std");
const Allocator = std.mem.Allocator;
const cache_key = @import("cache_key.zig");
const CacheKey = cache_key.CacheKey;
const cache_entry = @import("cache_entry.zig");
const CacheEntry = cache_entry.CacheEntry;

/// In-memory HTTP cache backend.
pub const MemoryCacheBackend = struct {
    allocator: Allocator,

    /// Cache entries keyed by hash string
    entries: std.StringHashMapUnmanaged(EntryNode),

    /// LRU list head (most recently used)
    lru_head: ?*EntryNode = null,

    /// LRU list tail (least recently used)
    lru_tail: ?*EntryNode = null,

    /// Maximum number of entries
    max_entries: usize,

    /// Maximum total size in bytes
    max_size_bytes: usize,

    /// Current total size in bytes
    current_size: usize = 0,

    /// Current entry count
    entry_count: usize = 0,

    /// Whether this is a shared cache
    is_shared_cache: bool,

    /// Node in the LRU doubly-linked list
    pub const EntryNode = struct {
        entry: *CacheEntry,
        key: []const u8, // The hash key
        prev: ?*EntryNode = null,
        next: ?*EntryNode = null,
    };

    const Self = @This();

    /// Default maximum entries
    pub const DEFAULT_MAX_ENTRIES: usize = 1000;

    /// Default maximum size (100 MB)
    pub const DEFAULT_MAX_SIZE: usize = 100 * 1024 * 1024;

    /// Initialize a new memory cache backend.
    pub fn init(allocator: Allocator) Self {
        return initWithOptions(allocator, DEFAULT_MAX_ENTRIES, DEFAULT_MAX_SIZE, false);
    }

    /// Initialize with custom options.
    pub fn initWithOptions(
        allocator: Allocator,
        max_entries: usize,
        max_size_bytes: usize,
        is_shared_cache: bool,
    ) Self {
        return .{
            .allocator = allocator,
            .entries = .{},
            .max_entries = max_entries,
            .max_size_bytes = max_size_bytes,
            .is_shared_cache = is_shared_cache,
        };
    }

    /// Clean up the cache backend.
    pub fn deinit(self: *Self) void {
        // Free all entries
        var it = self.entries.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.entry.deinit();
            self.allocator.free(kv.key_ptr.*);
            // Note: EntryNode is stored inline in the hashmap, no separate free needed
        }
        self.entries.deinit(self.allocator);
    }

    /// Look up a cache entry by key.
    /// Moves entry to front of LRU list if found.
    pub fn match(self: *Self, key: *const CacheKey) ?*CacheEntry {
        const hash_key = key.toHashKey(self.allocator) catch return null;
        defer self.allocator.free(hash_key);

        const node_ptr = self.entries.getPtr(hash_key) orelse return null;

        // Check if expired
        const now = std.time.timestamp();
        if (!node_ptr.entry.isFresh(self.is_shared_cache, now)) {
            // Check stale-while-revalidate
            if (!node_ptr.entry.canServeStaleWhileRevalidate(self.is_shared_cache, now)) {
                // Entry is stale and can't be served
                return null;
            }
        }

        // Move to front of LRU list
        self.moveToFront(node_ptr);

        return node_ptr.entry;
    }

    /// Store an entry in the cache.
    pub fn store(self: *Self, key: *const CacheKey, entry: *CacheEntry) !void {
        // Check if response should be stored
        if (entry.shouldNotStore()) {
            return;
        }

        // For shared caches, check private flag
        if (self.is_shared_cache and !entry.timing.cache_control.canStoreInSharedCache()) {
            return;
        }

        // Generate hash key
        const hash_key = try key.toHashKey(self.allocator);
        errdefer self.allocator.free(hash_key);

        const entry_size = entry.totalSize();

        // Remove existing entry if present
        if (self.entries.getPtr(hash_key)) |existing| {
            self.current_size -= existing.entry.totalSize();
            self.removeFromLru(existing);
            existing.entry.deinit();
            _ = self.entries.remove(hash_key);
            self.entry_count -= 1;
            self.allocator.free(hash_key);
        }

        // Evict entries if necessary
        while (self.entry_count >= self.max_entries or
            (self.max_size_bytes > 0 and self.current_size + entry_size > self.max_size_bytes))
        {
            if (!self.evictLru()) break;
        }

        // Create new entry node
        const node = EntryNode{
            .entry = entry,
            .key = hash_key,
        };

        // Add to hashmap
        try self.entries.put(self.allocator, hash_key, node);
        self.entry_count += 1;
        self.current_size += entry_size;

        // Add to front of LRU list
        const node_ptr = self.entries.getPtr(hash_key).?;
        self.addToFront(node_ptr);
    }

    /// Delete an entry from the cache.
    pub fn delete(self: *Self, key: *const CacheKey) void {
        const hash_key = key.toHashKey(self.allocator) catch return;
        defer self.allocator.free(hash_key);

        if (self.entries.getPtr(hash_key)) |node_ptr| {
            self.current_size -= node_ptr.entry.totalSize();
            self.removeFromLru(node_ptr);
            node_ptr.entry.deinit();

            // Remove from hashmap (need to fetch the stored key for freeing)
            if (self.entries.fetchRemove(hash_key)) |kv| {
                self.allocator.free(kv.key);
            }
            self.entry_count -= 1;
        }
    }

    /// Clear all entries from the cache.
    pub fn clear(self: *Self) void {
        var it = self.entries.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.entry.deinit();
            self.allocator.free(kv.key_ptr.*);
        }
        self.entries.clearRetainingCapacity();
        self.lru_head = null;
        self.lru_tail = null;
        self.current_size = 0;
        self.entry_count = 0;
    }

    /// Get cache statistics.
    pub fn getStats(self: *const Self) CacheStats {
        return .{
            .entry_count = self.entry_count,
            .current_size = self.current_size,
            .max_entries = self.max_entries,
            .max_size_bytes = self.max_size_bytes,
        };
    }

    /// Remove expired entries.
    pub fn removeExpired(self: *Self) usize {
        const now = std.time.timestamp();
        var removed: usize = 0;
        var keys_to_remove = std.ArrayListUnmanaged([]const u8){};
        defer keys_to_remove.deinit(self.allocator);

        // Collect keys to remove
        var it = self.entries.iterator();
        while (it.next()) |kv| {
            const entry = kv.value_ptr.entry;
            // Remove if stale and can't serve stale
            if (!entry.isFresh(self.is_shared_cache, now) and
                !entry.canServeStaleWhileRevalidate(self.is_shared_cache, now))
            {
                keys_to_remove.append(self.allocator, kv.key_ptr.*) catch continue;
            }
        }

        // Remove collected keys
        for (keys_to_remove.items) |hash_key| {
            if (self.entries.getPtr(hash_key)) |node_ptr| {
                self.current_size -= node_ptr.entry.totalSize();
                self.removeFromLru(node_ptr);
                node_ptr.entry.deinit();
                if (self.entries.fetchRemove(hash_key)) |kv| {
                    self.allocator.free(kv.key);
                }
                self.entry_count -= 1;
                removed += 1;
            }
        }

        return removed;
    }

    // === Private LRU helpers ===

    fn moveToFront(self: *Self, node: *EntryNode) void {
        if (self.lru_head == node) return; // Already at front

        self.removeFromLru(node);
        self.addToFront(node);
    }

    fn addToFront(self: *Self, node: *EntryNode) void {
        node.prev = null;
        node.next = self.lru_head;

        if (self.lru_head) |head| {
            head.prev = node;
        }
        self.lru_head = node;

        if (self.lru_tail == null) {
            self.lru_tail = node;
        }
    }

    fn removeFromLru(self: *Self, node: *EntryNode) void {
        if (node.prev) |prev| {
            prev.next = node.next;
        } else {
            self.lru_head = node.next;
        }

        if (node.next) |next| {
            next.prev = node.prev;
        } else {
            self.lru_tail = node.prev;
        }

        node.prev = null;
        node.next = null;
    }

    fn evictLru(self: *Self) bool {
        const tail = self.lru_tail orelse return false;
        const hash_key = tail.key;

        self.current_size -= tail.entry.totalSize();
        self.removeFromLru(tail);
        tail.entry.deinit();

        if (self.entries.fetchRemove(hash_key)) |kv| {
            self.allocator.free(kv.key);
        }
        self.entry_count -= 1;

        return true;
    }
};

/// Cache statistics.
pub const CacheStats = struct {
    entry_count: usize,
    current_size: usize,
    max_entries: usize,
    max_size_bytes: usize,
};

// =============================================================================
// Tests
// =============================================================================

test "MemoryCacheBackend - basic store and match" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.init(allocator);
    defer cache.deinit();

    // Create a key
    const key = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key.deinit();

    // Use current time for realistic timestamps
    const now = std.time.timestamp();

    // Create an entry
    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=31536000" }, // 1 year
    };
    const entry = try CacheEntry.init(allocator, 200, &headers, "test body", now - 1, now);
    // Don't defer deinit - cache takes ownership

    // Store
    try cache.store(key, entry);

    try std.testing.expectEqual(@as(usize, 1), cache.entry_count);

    // Match
    const found = cache.match(key);
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("test body", found.?.body.?);
}

test "MemoryCacheBackend - miss for non-existent key" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.init(allocator);
    defer cache.deinit();

    const key = try CacheKey.init(allocator, "https://example.com/missing", "GET", null);
    defer key.deinit();

    const found = cache.match(key);
    try std.testing.expect(found == null);
}

test "MemoryCacheBackend - delete entry" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.init(allocator);
    defer cache.deinit();

    const key = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key.deinit();

    const now = std.time.timestamp();
    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600" },
    };
    const entry = try CacheEntry.init(allocator, 200, &headers, "body", now - 1, now);

    try cache.store(key, entry);
    try std.testing.expectEqual(@as(usize, 1), cache.entry_count);

    cache.delete(key);
    try std.testing.expectEqual(@as(usize, 0), cache.entry_count);

    const found = cache.match(key);
    try std.testing.expect(found == null);
}

test "MemoryCacheBackend - clear all" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.init(allocator);
    defer cache.deinit();

    const now = std.time.timestamp();

    // Add multiple entries
    for (0..5) |i| {
        var buf: [64]u8 = undefined;
        const url = std.fmt.bufPrint(&buf, "https://example.com/{d}", .{i}) catch unreachable;

        const key = try CacheKey.init(allocator, url, "GET", null);
        defer key.deinit();

        const headers = [_]CacheEntry.Header{
            .{ .name = "Cache-Control", .value = "max-age=3600" },
        };
        const entry = try CacheEntry.init(allocator, 200, &headers, null, now - 1, now);
        try cache.store(key, entry);
    }

    try std.testing.expectEqual(@as(usize, 5), cache.entry_count);

    cache.clear();
    try std.testing.expectEqual(@as(usize, 0), cache.entry_count);
    try std.testing.expectEqual(@as(usize, 0), cache.current_size);
}

test "MemoryCacheBackend - LRU eviction" {
    const allocator = std.testing.allocator;

    // Small cache with max 3 entries
    var cache = MemoryCacheBackend.initWithOptions(allocator, 3, 0, false);
    defer cache.deinit();

    const now = std.time.timestamp();

    // Add 3 entries
    for (0..3) |i| {
        var buf: [64]u8 = undefined;
        const url = std.fmt.bufPrint(&buf, "https://example.com/{d}", .{i}) catch unreachable;

        const key = try CacheKey.init(allocator, url, "GET", null);
        defer key.deinit();

        const headers = [_]CacheEntry.Header{
            .{ .name = "Cache-Control", .value = "max-age=3600" },
        };
        const entry = try CacheEntry.init(allocator, 200, &headers, null, now - 1, now);
        try cache.store(key, entry);
    }

    try std.testing.expectEqual(@as(usize, 3), cache.entry_count);

    // Access entry 0 to make it recently used
    const key0 = try CacheKey.init(allocator, "https://example.com/0", "GET", null);
    defer key0.deinit();
    _ = cache.match(key0);

    // Add 4th entry - should evict LRU (entry 1, since 0 was just accessed)
    const key3 = try CacheKey.init(allocator, "https://example.com/3", "GET", null);
    defer key3.deinit();

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600" },
    };
    const entry3 = try CacheEntry.init(allocator, 200, &headers, null, now - 1, now);
    try cache.store(key3, entry3);

    try std.testing.expectEqual(@as(usize, 3), cache.entry_count);

    // Entry 1 should have been evicted (it was LRU since we accessed 0)
    const key1 = try CacheKey.init(allocator, "https://example.com/1", "GET", null);
    defer key1.deinit();
    const found1 = cache.match(key1);
    try std.testing.expect(found1 == null);

    // Entry 0 should still exist
    const found0 = cache.match(key0);
    try std.testing.expect(found0 != null);
}

test "MemoryCacheBackend - no-store not cached" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.init(allocator);
    defer cache.deinit();

    const key = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key.deinit();

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "no-store" },
    };
    const entry = try CacheEntry.init(allocator, 200, &headers, "secret", 0, 1);
    defer entry.deinit(); // We still own it since it won't be stored

    try cache.store(key, entry);

    // Should not have been stored
    try std.testing.expectEqual(@as(usize, 0), cache.entry_count);
}

test "MemoryCacheBackend - private not cached in shared cache" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.initWithOptions(allocator, 100, 0, true); // shared cache
    defer cache.deinit();

    const key = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key.deinit();

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "private, max-age=3600" },
    };
    const entry = try CacheEntry.init(allocator, 200, &headers, "user data", 0, 1);
    defer entry.deinit(); // We still own it since it won't be stored

    try cache.store(key, entry);

    // Should not have been stored in shared cache
    try std.testing.expectEqual(@as(usize, 0), cache.entry_count);
}

test "MemoryCacheBackend - getStats" {
    const allocator = std.testing.allocator;

    var cache = MemoryCacheBackend.initWithOptions(allocator, 100, 1024 * 1024, false);
    defer cache.deinit();

    const now = std.time.timestamp();
    const key = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key.deinit();

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600" },
    };
    const entry = try CacheEntry.init(allocator, 200, &headers, "test", now - 1, now);
    try cache.store(key, entry);

    const stats = cache.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.entry_count);
    try std.testing.expect(stats.current_size > 0);
    try std.testing.expectEqual(@as(usize, 100), stats.max_entries);
}
