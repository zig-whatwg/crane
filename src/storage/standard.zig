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
    cookies,
    fileSystem,
    indexedDB,
    localStorage,
    serviceWorkerRegistrations,
    sessionStorage,

    pub fn toString(self: StorageIdentifier) []const u8 {
        return switch (self) {
            .caches => "caches",
            .cookies => "cookies",
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
/// Note: cookies is for CookieStore API integration
pub const registered_storage_endpoints = [_]StorageEndpoint{
    .{ .identifier = .caches, .types = &.{.local}, .quota = null },
    .{ .identifier = .cookies, .types = &.{.local}, .quota = null },
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
        // Remove the old entry if it exists: its key copy too - the put below
        // stores a new one (freeing only the value leaked a key per overwrite).
        if (self.backing_map.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
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
// The user agent's storage (Phase 3.1)
// ============================================================================

/// The user agent's storage: its storage shed (Storage 4.3: "A user agent
/// holds a storage shed, which is a storage shed. A user agent's storage shed
/// holds all local storage data") and the bucket file systems of its storage
/// buckets (File System: "the bucket file system" of a storage bucket).
///
/// One per Browser - a supplement of its scope (runtime.BrowserScope,
/// docs/instances.md): two Browsers in one process, one origin, share none of
/// it, and every realm of one Browser reaches the same one through its
/// `browser_scope`. Made on first use, with the scope's allocator; ends with
/// the Browser. (It was a process global made lazily with whatever allocator
/// its first caller passed, and outlived every Browser.)
///
/// THREADS: a Browser's realms run on its window thread and its workers'
/// threads. `mutex` guards the shed's and the bucket manager's STRUCTURE -
/// every shelf, bucket, bottle and bucket file system is found or made under
/// it (`obtainShelf`, `obtainBottleMap`, `bucketFileSystem`). A bottle's map
/// is then read and written without it, by the realms that may reach it:
/// localStorage and sessionStorage are [Exposed=Window], so only the Browser's
/// window thread. A step that reads or writes a shelf from another thread
/// takes `lock`/`unlock` around it (StorageManager's persist, persisted and
/// estimate).
pub const UserAgentStorage = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    /// The user agent's storage shed: local storage. Session storage keeps
    /// its "{top-level browsing context}:{origin}" shelves here too, until
    /// each tab has its traversable's shed (instances B4).
    shed: StorageShed,
    /// The bucket file systems (navigator.storage.getDirectory()).
    buckets: fs.BucketManager,

    pub fn init(allocator: std.mem.Allocator) UserAgentStorage {
        return .{
            .allocator = allocator,
            .shed = StorageShed.init(allocator, .local),
            .buckets = fs.BucketManager.init(allocator),
        };
    }

    /// With its Browser: every storage area of it is gone.
    pub fn deinit(self: *UserAgentStorage) void {
        self.shed.deinit();
        self.buckets.deinit();
    }

    pub fn lock(self: *UserAgentStorage) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    pub fn unlock(self: *UserAgentStorage) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// "Obtain a local storage shelf" for `origin` (the caller holds the
    /// lock, or is the window thread reaching a shelf only it uses).
    pub fn obtainShelfLocked(self: *UserAgentStorage, origin: []const u8) !?*StorageShelf {
        if (origin.len == 0 or std.mem.eql(u8, origin, "null")) return null;
        return try self.shed.obtainShelf(StorageKey.initBorrowed(origin));
    }

    /// The bucket file system of `origin`'s storage bucket, made on first use.
    pub fn bucketFileSystem(self: *UserAgentStorage, origin: []const u8) !*fs.BucketFileSystem {
        // Validate origin (same rules as storage key)
        if (origin.len == 0 or std.mem.eql(u8, origin, "null")) {
            return error.SecurityError;
        }
        self.lock();
        defer self.unlock();
        return self.buckets.getOrCreate(origin);
    }
};

// ============================================================================
// Bucket File System Integration (File System Standard)
// ============================================================================

/// Get the bucket file system for an origin
/// https://fs.spec.whatwg.org/#dom-storagemanager-getdirectory
///
/// This returns the BucketFileSystem associated with the origin's storage
/// bucket in `user_agent_storage` - its Browser's. Each origin gets its own
/// isolated file system.
pub fn getBucketFileSystem(user_agent_storage: *UserAgentStorage, origin: []const u8) !*fs.BucketFileSystem {
    return user_agent_storage.bucketFileSystem(origin);
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
///
/// From `user_agent_storage`, the user agent's - its Browser's. The caller
/// holds its lock while it uses the shelf from a thread other than the
/// Browser's window thread (UserAgentStorage, THREADS).
pub fn obtainLocalStorageShelf(user_agent_storage: *UserAgentStorage, origin: []const u8) !?*StorageShelf {
    // "Obtain a storage key": failure for an opaque origin.
    // TODO: Check if user has disabled storage
    user_agent_storage.lock();
    defer user_agent_storage.unlock();
    return user_agent_storage.obtainShelfLocked(origin);
}

/// Obtain a storage bottle map for an endpoint
/// https://storage.spec.whatwg.org/#obtain-a-storage-bottle-map
///
/// In `user_agent_storage`, its Browser's. The shelf, bucket and bottle are
/// found or made under its lock; the proxy map returned reads and writes the
/// bottle's map without it (UserAgentStorage, THREADS).
pub fn obtainStorageBottleMap(
    user_agent_storage: *UserAgentStorage,
    storage_type: StorageType,
    origin: []const u8,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    // Note: session storage uses the same shed for now, with a key that
    // includes the browsing context: the caller (getSessionStorage in
    // web_storage.zig) already makes a session key with the top-level
    // browsing context's id. Each tab's traversable storage shed is
    // instances B4.
    _ = storage_type; // Both local and session use the same shed infrastructure
    user_agent_storage.lock();
    defer user_agent_storage.unlock();

    // Obtain shelf (null: the storage key is failure)
    const shelf = try user_agent_storage.obtainShelfLocked(origin) orelse return null;

    // Get default bucket
    const bucket = shelf.getDefaultBucket() orelse return null;

    // Get bottle for this endpoint, creating it if needed
    // Session storage bottles are created on-demand since they're scoped per browsing context
    var bottle = bucket.getBottle(identifier);
    if (bottle == null) {
        // Create the bottle on-demand, with the shed's allocator: it is the
        // shed's, freed with it.
        const endpoint = getEndpoint(identifier);
        const new_bottle = StorageBottle.init(user_agent_storage.allocator, endpoint.quota);
        bucket.bottle_map.put(identifier, new_bottle) catch return null;
        bottle = bucket.bottle_map.getPtr(identifier);
    }

    // Create and return proxy map
    return if (bottle) |b| b.createProxyMap() else null;
}

/// Obtain a local storage bottle map
/// https://storage.spec.whatwg.org/#obtain-a-local-storage-bottle-map
pub fn obtainLocalStorageBottleMap(
    user_agent_storage: *UserAgentStorage,
    origin: []const u8,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    return obtainStorageBottleMap(user_agent_storage, .local, origin, identifier);
}

/// Obtain a session storage bottle map
/// https://storage.spec.whatwg.org/#obtain-a-session-storage-bottle-map
pub fn obtainSessionStorageBottleMap(
    user_agent_storage: *UserAgentStorage,
    origin: []const u8,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    return obtainStorageBottleMap(user_agent_storage, .session, origin, identifier);
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

/// Get storage estimate for an origin, in `user_agent_storage` (its
/// Browser's) - read under its lock, since a worker's StorageManager asks too.
pub fn getStorageEstimate(user_agent_storage: *UserAgentStorage, origin: []const u8) !?StorageEstimate {
    user_agent_storage.lock();
    defer user_agent_storage.unlock();
    const shelf = try user_agent_storage.obtainShelfLocked(origin) orelse return null;
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

test "StorageProxyMap - setting a key again frees the copies it replaces" {
    // Storage.setItem on a key that is already there: set() used to free the
    // old value but not the old key copy (leaks lane, 2026-10-02: one per
    // overwriting setItem, e.g. unload-main-frame-same-origin.window.js).
    const allocator = std.testing.allocator;

    var bottle = StorageBottle.init(allocator, FIVE_MEBIBYTES);
    defer bottle.deinit();

    var proxy = bottle.createProxyMap();
    try proxy.set("key", "first");
    try proxy.set("key", "second");
    try proxy.set("key", "third");
    try std.testing.expectEqualStrings("third", proxy.get("key").?);
    try std.testing.expectEqual(@as(usize, 1), proxy.count());
}

test "StorageBucket - init with bottles" {
    const allocator = std.testing.allocator;

    var bucket = try StorageBucket.init(allocator, .local);
    defer bucket.deinit();

    // Should have bottles for all local endpoints
    try std.testing.expect(bucket.getBottle(.caches) != null);
    try std.testing.expect(bucket.getBottle(.cookies) != null);
    try std.testing.expect(bucket.getBottle(.indexedDB) != null);
    try std.testing.expect(bucket.getBottle(.localStorage) != null);
    try std.testing.expect(bucket.getBottle(.serviceWorkerRegistrations) != null);

    // Should not have session storage bottle
    try std.testing.expect(bucket.getBottle(.sessionStorage) == null);
}

test "StorageIdentifier - cookies" {
    try std.testing.expectEqualStrings("cookies", StorageIdentifier.cookies.toString());

    // Verify cookies endpoint exists and is local storage with no quota
    const endpoint = getEndpoint(.cookies);
    try std.testing.expectEqual(StorageIdentifier.cookies, endpoint.identifier);
    try std.testing.expect(endpoint.quota == null);
    try std.testing.expectEqual(@as(usize, 1), endpoint.types.len);
    try std.testing.expectEqual(StorageType.local, endpoint.types[0]);
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
    var user_agent_storage = UserAgentStorage.init(std.testing.allocator);
    defer user_agent_storage.deinit();

    // Get bottle map for indexedDB
    const proxy = try obtainLocalStorageBottleMap(&user_agent_storage, "https://example.com", .indexedDB);
    try std.testing.expect(proxy != null);

    // Store some data
    try proxy.?.set("testKey", "testValue");
    try std.testing.expectEqualStrings("testValue", proxy.?.get("testKey").?);

    // Opaque origin should return null
    const opaque_result = try obtainLocalStorageBottleMap(&user_agent_storage, "null", .indexedDB);
    try std.testing.expect(opaque_result == null);
}

test "StorageEstimate" {
    var user_agent_storage = UserAgentStorage.init(std.testing.allocator);
    defer user_agent_storage.deinit();

    // Store some data first
    const proxy = try obtainLocalStorageBottleMap(&user_agent_storage, "https://example.com", .indexedDB);
    try std.testing.expect(proxy != null);
    try proxy.?.set("key1", "value1");
    try proxy.?.set("key2", "value2value2");

    // Get estimate
    const estimate = try getStorageEstimate(&user_agent_storage, "https://example.com");
    try std.testing.expect(estimate != null);
    try std.testing.expect(estimate.?.usage > 0);
    try std.testing.expect(estimate.?.quota > 0);
}

test "UserAgentStorage - two user agents' sheds share nothing under one storage key; one's bottle maps share" {
    var a = UserAgentStorage.init(std.testing.allocator);
    defer a.deinit();
    var b = UserAgentStorage.init(std.testing.allocator);
    defer b.deinit();

    const in_a = (try obtainLocalStorageBottleMap(&a, "https://example.com", .localStorage)).?;
    try in_a.set("k", "a");
    const in_b = (try obtainLocalStorageBottleMap(&b, "https://example.com", .localStorage)).?;
    try std.testing.expect(in_b.get("k") == null);
    const in_a_again = (try obtainLocalStorageBottleMap(&a, "https://example.com", .localStorage)).?;
    try std.testing.expectEqualStrings("a", in_a_again.get("k").?);

    // Their bucket file systems too.
    const fs_a = try getBucketFileSystem(&a, "https://example.com");
    try std.testing.expect(fs_a == try getBucketFileSystem(&a, "https://example.com"));
    try std.testing.expect(fs_a != try getBucketFileSystem(&b, "https://example.com"));
    try std.testing.expectError(error.SecurityError, getBucketFileSystem(&a, "null"));
}
