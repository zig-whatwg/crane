//! WHATWG Storage Standard Implementation
//!
//! Implements the WHATWG Storage Standard (https://storage.spec.whatwg.org/)
//! which defines the infrastructure for storage APIs like IndexedDB, localStorage,
//! Cache API, and service worker registrations.
//!
//! ## Architecture
//!
//! ```
//! StorageShed (user agent or traversable navigable)
//!     └── StorageKey (origin tuple)
//!         └── StorageShelf (per-origin)
//!             └── BucketMap ("default" → StorageBucket)
//!                 └── StorageBucket (local or session)
//!                     └── BottleMap (identifier → StorageBottle)
//!                         └── StorageBottle (per-endpoint: indexedDB, localStorage, etc.)
//!                             └── StorageProxyMap (actual data)
//! ```
//!
//! ## Storage Types
//!
//! - **Local Storage**: Persisted across sessions (IndexedDB, localStorage, Cache API)
//! - **Session Storage**: Cleared when session ends (sessionStorage)
//!
//! ## Registered Storage Endpoints
//!
//! | Identifier | Type | Quota |
//! |------------|------|-------|
//! | "caches" | local | null |
//! | "indexedDB" | local | null |
//! | "localStorage" | local | 5 MiB |
//! | "serviceWorkerRegistrations" | local | null |
//! | "sessionStorage" | session | 5 MiB |
//!
//! ## Specification References
//!
//! - WHATWG Storage Standard: https://storage.spec.whatwg.org/
//! - Storage Spec Model: https://storage.spec.whatwg.org/#model

const std = @import("std");
const fs = @import("fs");

// ============================================================================
// Storage Types (Phase 3.1)
// ============================================================================

/// Storage type: local (persisted) or session (temporary)
/// https://storage.spec.whatwg.org/#storage-type
pub const StorageType = enum {
    /// Local storage persists across sessions
    local,
    /// Session storage is cleared when the session ends
    session,
};

/// Storage bucket mode for local storage
/// https://storage.spec.whatwg.org/#bucket-mode
pub const BucketMode = enum {
    /// Can be cleared by user agent under storage pressure
    best_effort,
    /// Cannot be cleared without user consent
    persistent,
};

// ============================================================================
// Storage Endpoints (Phase 3.1)
// ============================================================================

/// Storage identifier for registered endpoints
/// https://storage.spec.whatwg.org/#storage-identifier
pub const StorageIdentifier = enum {
    caches,
    fileSystem,
    indexedDB,
    localStorage,
    serviceWorkerRegistrations,
    sessionStorage,

    pub fn toString(self: StorageIdentifier) []const u8 {
        return switch (self) {
            .caches => "caches",
            .fileSystem => "fileSystem",
            .indexedDB => "indexedDB",
            .localStorage => "localStorage",
            .serviceWorkerRegistrations => "serviceWorkerRegistrations",
            .sessionStorage => "sessionStorage",
        };
    }
};

/// A storage endpoint is a local or session storage API
/// https://storage.spec.whatwg.org/#storage-endpoint
pub const StorageEndpoint = struct {
    /// Unique identifier for this endpoint
    identifier: StorageIdentifier,
    /// Storage types this endpoint supports
    types: []const StorageType,
    /// Recommended quota in bytes (null = no limit)
    quota: ?u64,
};

/// 5 MiB in bytes (5 × 2^20)
pub const FIVE_MEBIBYTES: u64 = 5 * 1024 * 1024;

/// Registered storage endpoints per the spec
/// https://storage.spec.whatwg.org/#registered-storage-endpoints
/// Note: fileSystem is from the File System Standard
pub const registered_storage_endpoints = [_]StorageEndpoint{
    .{ .identifier = .caches, .types = &.{.local}, .quota = null },
    .{ .identifier = .fileSystem, .types = &.{.local}, .quota = null },
    .{ .identifier = .indexedDB, .types = &.{.local}, .quota = null },
    .{ .identifier = .localStorage, .types = &.{.local}, .quota = FIVE_MEBIBYTES },
    .{ .identifier = .serviceWorkerRegistrations, .types = &.{.local}, .quota = null },
    .{ .identifier = .sessionStorage, .types = &.{.session}, .quota = FIVE_MEBIBYTES },
};

/// Get endpoint by identifier
pub fn getEndpoint(identifier: StorageIdentifier) StorageEndpoint {
    for (registered_storage_endpoints) |endpoint| {
        if (endpoint.identifier == identifier) {
            return endpoint;
        }
    }
    unreachable;
}

// ============================================================================
// Storage Key (Phase 3.6)
// ============================================================================

/// A storage key is a tuple consisting of an origin
/// https://storage.spec.whatwg.org/#storage-key
pub const StorageKey = struct {
    /// The origin component of the storage key
    /// For now this is a simple string; will integrate with HTML origin type
    origin: []const u8,

    /// Allocator used to allocate the origin string
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a storage key from an origin string
    pub fn init(allocator: std.mem.Allocator, origin: []const u8) !Self {
        const origin_copy = try allocator.dupe(u8, origin);
        return Self{
            .origin = origin_copy,
            .allocator = allocator,
        };
    }

    /// Create a storage key without copying (for temporary use)
    pub fn initBorrowed(origin: []const u8) Self {
        return Self{
            .origin = origin,
            .allocator = null,
        };
    }

    /// Free the storage key's resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.origin);
        }
        self.* = undefined;
    }

    /// Check if two storage keys are equal
    /// https://storage.spec.whatwg.org/#storage-key-equal
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.origin, other.origin);
    }

    /// Hash function for use in hash maps
    pub fn hash(self: Self) u64 {
        return std.hash.Wyhash.hash(0, self.origin);
    }

    /// Context for hash map
    pub const HashContext = struct {
        pub fn hash(_: HashContext, key: StorageKey) u64 {
            return key.hash();
        }

        pub fn eql(_: HashContext, a: StorageKey, b: StorageKey) bool {
            return a.equals(b);
        }
    };
};

// ============================================================================
// Storage Proxy Map (Phase 3.1)
// ============================================================================

/// A storage proxy map is equivalent to a map, with all operations
/// performed on its backing map
/// https://storage.spec.whatwg.org/#storage-proxy-map
pub const StorageProxyMap = struct {
    /// The backing map where actual data is stored
    backing_map: *std.StringHashMap([]u8),

    /// Allocator for value allocations
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Get a value from the map
    pub fn get(self: Self, key: []const u8) ?[]const u8 {
        return self.backing_map.get(key);
    }

    /// Set a value in the map
    pub fn set(self: Self, key: []const u8, value: []const u8) !void {
        // Remove old value if exists
        if (self.backing_map.fetchRemove(key)) |old| {
            self.allocator.free(old.value);
        }

        // Copy key and value
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        try self.backing_map.put(key_copy, value_copy);
    }

    /// Delete a key from the map
    pub fn delete(self: Self, key: []const u8) bool {
        if (self.backing_map.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
            return true;
        }
        return false;
    }

    /// Check if a key exists
    pub fn has(self: Self, key: []const u8) bool {
        return self.backing_map.contains(key);
    }

    /// Get the number of entries
    pub fn count(self: Self) usize {
        return self.backing_map.count();
    }

    /// Clear all entries
    pub fn clear(self: Self) void {
        var iter = self.backing_map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.backing_map.clearRetainingCapacity();
    }
};

// ============================================================================
// Storage Bottle (Phase 3.4)
// ============================================================================

/// A storage bottle is a part of a storage bucket carved out for a single endpoint
/// https://storage.spec.whatwg.org/#storage-bottle
pub const StorageBottle = struct {
    /// The actual data storage
    map: std.StringHashMap([]u8),

    /// Number of proxy maps referencing this bottle's map
    /// (We track count instead of storing pointers for simplicity)
    proxy_map_ref_count: usize,

    /// Conservative estimate of bytes this bottle can hold (null = no limit)
    quota: ?u64,

    /// Allocator for this bottle
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new storage bottle
    pub fn init(allocator: std.mem.Allocator, quota: ?u64) Self {
        return Self{
            .map = std.StringHashMap([]u8).init(allocator),
            .proxy_map_ref_count = 0,
            .quota = quota,
            .allocator = allocator,
        };
    }

    /// Free the storage bottle's resources
    pub fn deinit(self: *Self) void {
        // Free all map entries
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    /// Create a proxy map for this bottle
    pub fn createProxyMap(self: *Self) StorageProxyMap {
        self.proxy_map_ref_count += 1;
        return StorageProxyMap{
            .backing_map = &self.map,
            .allocator = self.allocator,
        };
    }

    /// Estimate storage usage in bytes
    pub fn estimateUsage(self: Self) u64 {
        var total: u64 = 0;
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            total += entry.key_ptr.len;
            total += entry.value_ptr.len;
        }
        return total;
    }
};

// ============================================================================
// Storage Bucket (Phase 3.3)
// ============================================================================

/// A storage bucket is a place for storage endpoints to store data
/// https://storage.spec.whatwg.org/#storage-bucket
pub const StorageBucket = struct {
    /// Map of storage identifiers to storage bottles
    bottle_map: std.AutoHashMap(StorageIdentifier, StorageBottle),

    /// Storage type (local or session)
    storage_type: StorageType,

    /// Mode for local storage buckets (best-effort or persistent)
    /// Only meaningful for local storage; session storage ignores this
    mode: BucketMode,

    /// Allocator for this bucket
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new storage bucket
    /// https://storage.spec.whatwg.org/#create-a-storage-bucket
    pub fn init(allocator: std.mem.Allocator, storage_type: StorageType) !Self {
        var bucket = Self{
            .bottle_map = std.AutoHashMap(StorageIdentifier, StorageBottle).init(allocator),
            .storage_type = storage_type,
            .mode = .best_effort,
            .allocator = allocator,
        };

        // Initialize bottles for all registered endpoints of this type
        for (registered_storage_endpoints) |endpoint| {
            for (endpoint.types) |t| {
                if (t == storage_type) {
                    const bottle = StorageBottle.init(allocator, endpoint.quota);
                    try bucket.bottle_map.put(endpoint.identifier, bottle);
                    break;
                }
            }
        }

        return bucket;
    }

    /// Free the storage bucket's resources
    pub fn deinit(self: *Self) void {
        var iter = self.bottle_map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.bottle_map.deinit();
    }

    /// Get a bottle by identifier
    pub fn getBottle(self: *Self, identifier: StorageIdentifier) ?*StorageBottle {
        return self.bottle_map.getPtr(identifier);
    }

    /// Estimate total storage usage across all bottles
    pub fn estimateUsage(self: Self) u64 {
        var total: u64 = 0;
        var iter = self.bottle_map.iterator();
        while (iter.next()) |entry| {
            total += entry.value_ptr.estimateUsage();
        }
        return total;
    }

    /// Clear all data in this bucket
    pub fn clear(self: *Self) void {
        var iter = self.bottle_map.iterator();
        while (iter.next()) |entry| {
            const proxy = entry.value_ptr.createProxyMap();
            proxy.clear();
        }
    }
};

// ============================================================================
// Storage Shelf (Phase 3.2)
// ============================================================================

/// A storage shelf exists for each storage key within a storage shed
/// https://storage.spec.whatwg.org/#storage-shelf
pub const StorageShelf = struct {
    /// Map of bucket names to storage buckets
    /// For now only "default" is used per spec
    bucket_map: std.StringHashMap(StorageBucket),

    /// Allocator for this shelf
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new storage shelf
    /// https://storage.spec.whatwg.org/#create-a-storage-shelf
    pub fn init(allocator: std.mem.Allocator, storage_type: StorageType) !Self {
        var shelf = Self{
            .bucket_map = std.StringHashMap(StorageBucket).init(allocator),
            .allocator = allocator,
        };

        // Create the default bucket
        const bucket = try StorageBucket.init(allocator, storage_type);
        try shelf.bucket_map.put("default", bucket);

        return shelf;
    }

    /// Free the storage shelf's resources
    pub fn deinit(self: *Self) void {
        var iter = self.bucket_map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.bucket_map.deinit();
    }

    /// Get the default bucket
    pub fn getDefaultBucket(self: *Self) ?*StorageBucket {
        return self.bucket_map.getPtr("default");
    }

    /// Get a bucket by name
    pub fn getBucket(self: *Self, name: []const u8) ?*StorageBucket {
        return self.bucket_map.getPtr(name);
    }

    /// Estimate storage usage for this shelf
    /// https://storage.spec.whatwg.org/#storage-usage
    pub fn estimateUsage(self: Self) u64 {
        var total: u64 = 0;
        var iter = self.bucket_map.iterator();
        while (iter.next()) |entry| {
            total += entry.value_ptr.estimateUsage();
        }
        return total;
    }

    /// Get the storage quota for this shelf
    /// https://storage.spec.whatwg.org/#storage-quota
    /// Default: 50 MiB (implementation-defined)
    pub fn getQuota(self: Self) u64 {
        _ = self;
        // Implementation-defined quota
        // This should be less than total storage and not dependent on available space
        return 50 * 1024 * 1024; // 50 MiB default
    }

    /// Check if storage is persistent
    pub fn isPersistent(self: Self) bool {
        if (self.bucket_map.get("default")) |bucket| {
            return bucket.mode == .persistent;
        }
        return false;
    }
};

// ============================================================================
// Storage Shed (Phase 3.1)
// ============================================================================

/// A storage shed is a map of storage keys to storage shelves
/// https://storage.spec.whatwg.org/#storage-shed
pub const StorageShed = struct {
    /// Map of storage keys to storage shelves
    shelves: std.HashMap(StorageKey, StorageShelf, StorageKey.HashContext, std.hash_map.default_max_load_percentage),

    /// Storage type for this shed
    storage_type: StorageType,

    /// Allocator for this shed
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new storage shed
    pub fn init(allocator: std.mem.Allocator, storage_type: StorageType) Self {
        return Self{
            .shelves = std.HashMap(StorageKey, StorageShelf, StorageKey.HashContext, std.hash_map.default_max_load_percentage).init(allocator),
            .storage_type = storage_type,
            .allocator = allocator,
        };
    }

    /// Free the storage shed's resources
    pub fn deinit(self: *Self) void {
        var iter = self.shelves.iterator();
        while (iter.next()) |entry| {
            // Free the key
            var key = entry.key_ptr.*;
            key.deinit();
            // Free the shelf
            entry.value_ptr.deinit();
        }
        self.shelves.deinit();
    }

    /// Obtain a storage shelf for the given key
    /// https://storage.spec.whatwg.org/#obtain-a-storage-shelf
    pub fn obtainShelf(self: *Self, key: StorageKey) !*StorageShelf {
        // Check if shelf already exists
        const borrowed_key = StorageKey.initBorrowed(key.origin);
        if (self.shelves.getPtr(borrowed_key)) |shelf| {
            return shelf;
        }

        // Create new shelf
        const owned_key = try StorageKey.init(self.allocator, key.origin);
        errdefer {
            var k = owned_key;
            k.deinit();
        }

        const shelf = try StorageShelf.init(self.allocator, self.storage_type);
        try self.shelves.put(owned_key, shelf);

        return self.shelves.getPtr(owned_key).?;
    }

    /// Get a shelf without creating it
    pub fn getShelf(self: *Self, key: StorageKey) ?*StorageShelf {
        const borrowed_key = StorageKey.initBorrowed(key.origin);
        return self.shelves.getPtr(borrowed_key);
    }

    /// Remove a shelf
    pub fn removeShelf(self: *Self, key: StorageKey) void {
        const borrowed_key = StorageKey.initBorrowed(key.origin);
        if (self.shelves.fetchRemove(borrowed_key)) |entry| {
            var k = entry.key;
            k.deinit();
            var shelf = entry.value;
            shelf.deinit();
        }
    }

    /// Get number of shelves
    pub fn count(self: Self) usize {
        return self.shelves.count();
    }
};

// ============================================================================
// Global Storage Shed (Phase 3.1)
// ============================================================================

/// The user agent's storage shed for local storage
/// This would typically be a singleton in a real implementation
var global_local_storage_shed: ?*StorageShed = null;

/// Global bucket file system manager
/// Manages per-origin bucket file systems for the File System Access API
var global_bucket_manager: ?*fs.BucketManager = null;

/// Initialize the global local storage shed
pub fn initGlobalStorageShed(allocator: std.mem.Allocator) !*StorageShed {
    if (global_local_storage_shed) |shed| {
        return shed;
    }

    const shed = try allocator.create(StorageShed);
    shed.* = StorageShed.init(allocator, .local);
    global_local_storage_shed = shed;
    return shed;
}

/// Get the global local storage shed
pub fn getGlobalStorageShed() ?*StorageShed {
    return global_local_storage_shed;
}

/// Deinitialize the global local storage shed
pub fn deinitGlobalStorageShed(allocator: std.mem.Allocator) void {
    if (global_local_storage_shed) |shed| {
        shed.deinit();
        allocator.destroy(shed);
        global_local_storage_shed = null;
    }
    // Also clean up bucket manager
    if (global_bucket_manager) |manager| {
        manager.deinit();
        allocator.destroy(manager);
        global_bucket_manager = null;
    }
}

// ============================================================================
// Bucket File System Integration (File System Standard)
// ============================================================================

/// Initialize the global bucket file system manager
pub fn initGlobalBucketManager(allocator: std.mem.Allocator) !*fs.BucketManager {
    if (global_bucket_manager) |manager| {
        return manager;
    }

    const manager = try allocator.create(fs.BucketManager);
    manager.* = fs.BucketManager.init(allocator);
    global_bucket_manager = manager;
    return manager;
}

/// Get the bucket file system for an origin
/// https://fs.spec.whatwg.org/#dom-storagemanager-getdirectory
///
/// This returns the BucketFileSystem associated with the origin's storage bucket.
/// Each origin gets its own isolated file system.
pub fn getBucketFileSystem(allocator: std.mem.Allocator, origin: []const u8) !*fs.BucketFileSystem {
    // Validate origin (same rules as storage key)
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) {
        return error.SecurityError;
    }

    // Get or initialize the bucket manager
    const manager = try initGlobalBucketManager(allocator);

    // Get or create bucket for this origin
    return manager.getOrCreate(origin);
}

// ============================================================================
// Algorithms (Phase 3.6, 3.7, 3.8, 3.9)
// ============================================================================

/// Obtain a storage key for an origin
/// https://storage.spec.whatwg.org/#obtain-a-storage-key
pub fn obtainStorageKey(allocator: std.mem.Allocator, origin: []const u8) !?StorageKey {
    // If origin is opaque, return failure
    if (origin.len == 0 or std.mem.eql(u8, origin, "null")) {
        return null;
    }

    // TODO: Check if user has disabled storage

    return try StorageKey.init(allocator, origin);
}

/// Obtain a local storage shelf
/// https://storage.spec.whatwg.org/#obtain-a-local-storage-shelf
pub fn obtainLocalStorageShelf(allocator: std.mem.Allocator, origin: []const u8) !?*StorageShelf {
    const key = try obtainStorageKey(allocator, origin) orelse return null;
    defer {
        var k = key;
        k.deinit();
    }

    const shed = try initGlobalStorageShed(allocator);
    return try shed.obtainShelf(key);
}

/// Obtain a storage bottle map for an endpoint
/// https://storage.spec.whatwg.org/#obtain-a-storage-bottle-map
pub fn obtainStorageBottleMap(
    allocator: std.mem.Allocator,
    storage_type: StorageType,
    origin: []const u8,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    // Get or create storage key
    const key = try obtainStorageKey(allocator, origin) orelse return null;
    defer {
        var k = key;
        k.deinit();
    }

    // Get the appropriate shed
    var shed: *StorageShed = undefined;
    if (storage_type == .local) {
        shed = try initGlobalStorageShed(allocator);
    } else {
        // Session storage requires traversable navigable (not implemented yet)
        return null;
    }

    // Obtain shelf
    const shelf = try shed.obtainShelf(key);

    // Get default bucket
    const bucket = shelf.getDefaultBucket() orelse return null;

    // Get bottle for this endpoint
    const bottle = bucket.getBottle(identifier) orelse return null;

    // Create and return proxy map
    return bottle.createProxyMap();
}

/// Obtain a local storage bottle map
/// https://storage.spec.whatwg.org/#obtain-a-local-storage-bottle-map
pub fn obtainLocalStorageBottleMap(
    allocator: std.mem.Allocator,
    origin: []const u8,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    return obtainStorageBottleMap(allocator, .local, origin, identifier);
}

/// Obtain a session storage bottle map
/// https://storage.spec.whatwg.org/#obtain-a-session-storage-bottle-map
pub fn obtainSessionStorageBottleMap(
    allocator: std.mem.Allocator,
    origin: []const u8,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    return obtainStorageBottleMap(allocator, .session, origin, identifier);
}

// ============================================================================
// Storage Estimate (Phase 3.11)
// ============================================================================

/// Storage estimate dictionary
/// https://storage.spec.whatwg.org/#dictdef-storageestimate
pub const StorageEstimate = struct {
    /// Approximate bytes used
    usage: u64,
    /// Approximate bytes available
    quota: u64,
};

/// Get storage estimate for an origin
pub fn getStorageEstimate(allocator: std.mem.Allocator, origin: []const u8) !?StorageEstimate {
    const shelf = try obtainLocalStorageShelf(allocator, origin) orelse return null;
    return StorageEstimate{
        .usage = shelf.estimateUsage(),
        .quota = shelf.getQuota(),
    };
}

// ============================================================================
// Tests
// ============================================================================

test "StorageKey - init and equals" {
    const allocator = std.testing.allocator;

    var key1 = try StorageKey.init(allocator, "https://example.com");
    defer key1.deinit();

    var key2 = try StorageKey.init(allocator, "https://example.com");
    defer key2.deinit();

    var key3 = try StorageKey.init(allocator, "https://other.com");
    defer key3.deinit();

    try std.testing.expect(key1.equals(key2));
    try std.testing.expect(!key1.equals(key3));
}

test "StorageBottle - basic operations" {
    const allocator = std.testing.allocator;

    var bottle = StorageBottle.init(allocator, FIVE_MEBIBYTES);
    defer bottle.deinit();

    var proxy = bottle.createProxyMap();

    // Set and get
    try proxy.set("key1", "value1");
    try std.testing.expectEqualStrings("value1", proxy.get("key1").?);

    // Has
    try std.testing.expect(proxy.has("key1"));
    try std.testing.expect(!proxy.has("key2"));

    // Count
    try std.testing.expectEqual(@as(usize, 1), proxy.count());

    // Delete
    try std.testing.expect(proxy.delete("key1"));
    try std.testing.expect(!proxy.has("key1"));
    try std.testing.expectEqual(@as(usize, 0), proxy.count());
}

test "StorageBucket - init with bottles" {
    const allocator = std.testing.allocator;

    var bucket = try StorageBucket.init(allocator, .local);
    defer bucket.deinit();

    // Should have bottles for all local endpoints
    try std.testing.expect(bucket.getBottle(.caches) != null);
    try std.testing.expect(bucket.getBottle(.indexedDB) != null);
    try std.testing.expect(bucket.getBottle(.localStorage) != null);
    try std.testing.expect(bucket.getBottle(.serviceWorkerRegistrations) != null);

    // Should not have session storage bottle
    try std.testing.expect(bucket.getBottle(.sessionStorage) == null);
}

test "StorageShelf - default bucket" {
    const allocator = std.testing.allocator;

    var shelf = try StorageShelf.init(allocator, .local);
    defer shelf.deinit();

    // Should have default bucket
    const bucket = shelf.getDefaultBucket();
    try std.testing.expect(bucket != null);

    // Default mode is best-effort
    try std.testing.expectEqual(BucketMode.best_effort, bucket.?.mode);
    try std.testing.expect(!shelf.isPersistent());
}

test "StorageShed - obtain shelf" {
    const allocator = std.testing.allocator;

    var shed = StorageShed.init(allocator, .local);
    defer shed.deinit();

    const key = StorageKey.initBorrowed("https://example.com");

    // First obtain creates shelf
    const shelf1 = try shed.obtainShelf(key);
    try std.testing.expectEqual(@as(usize, 1), shed.count());

    // Second obtain returns same shelf
    const shelf2 = try shed.obtainShelf(key);
    try std.testing.expect(shelf1 == shelf2);
    try std.testing.expectEqual(@as(usize, 1), shed.count());

    // Different key creates new shelf
    const key2 = StorageKey.initBorrowed("https://other.com");
    _ = try shed.obtainShelf(key2);
    try std.testing.expectEqual(@as(usize, 2), shed.count());
}

test "obtainLocalStorageBottleMap" {
    const allocator = std.testing.allocator;
    defer deinitGlobalStorageShed(allocator);

    // Get bottle map for indexedDB
    const proxy = try obtainLocalStorageBottleMap(allocator, "https://example.com", .indexedDB);
    try std.testing.expect(proxy != null);

    // Store some data
    try proxy.?.set("testKey", "testValue");
    try std.testing.expectEqualStrings("testValue", proxy.?.get("testKey").?);

    // Opaque origin should return null
    const opaque_result = try obtainLocalStorageBottleMap(allocator, "null", .indexedDB);
    try std.testing.expect(opaque_result == null);
}

test "StorageEstimate" {
    const allocator = std.testing.allocator;
    defer deinitGlobalStorageShed(allocator);

    // Store some data first
    const proxy = try obtainLocalStorageBottleMap(allocator, "https://example.com", .indexedDB);
    try std.testing.expect(proxy != null);
    try proxy.?.set("key1", "value1");
    try proxy.?.set("key2", "value2value2");

    // Get estimate
    const estimate = try getStorageEstimate(allocator, "https://example.com");
    try std.testing.expect(estimate != null);
    try std.testing.expect(estimate.?.usage > 0);
    try std.testing.expect(estimate.?.quota > 0);
}
