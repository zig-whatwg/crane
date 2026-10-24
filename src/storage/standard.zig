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
//!     └── StorageKey (origin, top-level site, has cross-site ancestor)
//!         └── StorageShelf (per storage key)
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

/// A storage key (Storage 4.2) as every browser keys storage: an origin, the
/// top-level site it runs under, and whether it has a cross-site ancestor.
///
/// The Storage Standard's text still says "a tuple consisting of an origin"
/// (with "This is expected to change; see Client-Side Storage Partitioning"),
/// and Crane follows the browsers over it (golden rule 2: no newer spec is
/// involved, the browsers differ from the text, and all three agree):
/// Chrome, Firefox and Safari all partition third-party storage by top-level
/// by default (wpt.fyi aligned stable 23b0b89b1a: Chrome 155, Firefox 158,
/// Safari 27 pass webstorage/localstorage-basic-partitioned.sub,
/// sessionStorage-basic-partitioned.sub and
/// localstorage-about-blank-3P-iframe-opens-3P-window.partitioned 1/1 each).
/// Their keys: Chromium blink::StorageKey (origin, top_level_site,
/// ancestor_chain_bit), Gecko OriginAttributes.partitionKey
/// "(scheme,baseDomain[,port][,f])" whose "f" is the foreign-by-ancestor bit
/// (caps/OriginAttributes.cpp ParsePartitionKey), WebKit ClientOrigin
/// {topOrigin, clientOrigin}. So the top-level SITE and the bit (Chrome and
/// Firefox). Corroboration, not the reason: whatwg/storage PR 182 (open since
/// 2025-06, every engine interested, none opposed; Chromium 40177656, Gecko
/// 1977899, WebKit 247732) makes the key exactly this, and HTML gave every
/// environment its "has cross-site ancestor" (whatwg/html PR 11133, 2025-07).
///
/// The parts are serializations: `origin` an origin's ("null" when opaque),
/// `top_level_site` a site's (HTML "obtain a site": "scheme://registrable
/// domain", or "null" for an opaque top-level origin). Opaque identities
/// travel as nonzero values, never cross-thread OriginRecord pointers.
/// They remain ineligible for persistent storage.
pub const StorageKey = struct {
    /// The origin, serialized.
    origin: []const u8,
    /// The top-level site, serialized.
    top_level_site: []const u8,
    /// HTML "has cross-site ancestor" of the environment the key is for.
    has_cross_site_ancestor: bool,
    origin_nonce: ?u128 = null,
    top_level_nonce: ?u128 = null,

    /// The allocator that made `origin` and `top_level_site` (one allocation
    /// each); null for a borrowed key.
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// A key owning copies of its parts.
    pub fn init(allocator: std.mem.Allocator, origin: []const u8, top_level_site: []const u8, has_cross_site_ancestor: bool) !Self {
        const origin_copy = try allocator.dupe(u8, origin);
        errdefer allocator.free(origin_copy);
        const site_copy = try allocator.dupe(u8, top_level_site);
        return .{
            .origin = origin_copy,
            .top_level_site = site_copy,
            .has_cross_site_ancestor = has_cross_site_ancestor,
            .allocator = allocator,
        };
    }

    /// A key borrowing its parts, for a lookup.
    pub fn initBorrowed(origin: []const u8, top_level_site: []const u8, has_cross_site_ancestor: bool) Self {
        return .{
            .origin = origin,
            .top_level_site = top_level_site,
            .has_cross_site_ancestor = has_cross_site_ancestor,
        };
    }

    /// An owned copy of this key.
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        var copy = try init(allocator, self.origin, self.top_level_site, self.has_cross_site_ancestor);
        copy.origin_nonce = self.origin_nonce;
        copy.top_level_nonce = self.top_level_nonce;
        return copy;
    }

    /// Free the key's parts, if it owns them.
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.origin);
            alloc.free(self.top_level_site);
        }
        self.* = undefined;
    }

    /// Storage "equals" with whatwg/storage PR 182's steps: the origins are
    /// same origin, the top-level sites same site, and the bits equal. The
    /// Opaque serializations require the same known identity on both sides.
    /// https://storage.spec.whatwg.org/#storage-key-equal
    pub fn equals(self: Self, other: Self) bool {
        return self.has_cross_site_ancestor == other.has_cross_site_ancestor and
            samePart(self.origin, self.origin_nonce, other.origin, other.origin_nonce) and
            ((self.isOriginOnlyAdministrativeKey() and other.isOriginOnlyAdministrativeKey()) or
                samePart(self.top_level_site, self.top_level_nonce, other.top_level_site, other.top_level_nonce));
    }

    /// StorageManager's origin-only accounting uses an empty site sentinel,
    /// separate from every environment partition. It still needs a tuple origin.
    fn isOriginOnlyAdministrativeKey(self: Self) bool {
        return self.origin.len != 0 and !std.mem.eql(u8, self.origin, "null") and self.top_level_site.len == 0;
    }

    fn samePart(a: []const u8, a_nonce: ?u128, b: []const u8, b_nonce: ?u128) bool {
        if (a.len == 0 or !std.mem.eql(u8, a, b)) return false;
        if (!std.mem.eql(u8, a, "null")) return true;
        return a_nonce != null and a_nonce.? != 0 and a_nonce == b_nonce;
    }

    /// Hash function for use in hash maps: of every part `equals` compares.
    pub fn hash(self: Self) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(self.origin);
        hasher.update(&.{0});
        hasher.update(self.top_level_site);
        hasher.update(&.{@intFromBool(self.has_cross_site_ancestor)});
        if (std.mem.eql(u8, self.origin, "null")) {
            const nonce = self.origin_nonce orelse 0;
            hasher.update(std.mem.asBytes(&nonce));
        }
        if (std.mem.eql(u8, self.top_level_site, "null")) {
            const nonce = self.top_level_nonce orelse 0;
            hasher.update(std.mem.asBytes(&nonce));
        }
        return hasher.final();
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

    /// "<origin> <top-level site> <0|1>": the key as one string, for the
    /// modules that keep or carry one without importing this one - the blob
    /// URL store's entries (src/file) and a request's (src/fetch). No
    /// serialized origin or site contains a space, so the form is canonical:
    /// two keys are equal exactly when their serializations are. Owned by
    /// the caller.
    pub fn serialize(self: Self, allocator: std.mem.Allocator) ![]u8 {
        if (self.isOpaque()) {
            var origin_buf: [32]u8 = undefined;
            var site_buf: [32]u8 = undefined;
            const origin_id = nonceText(&origin_buf, if (std.mem.eql(u8, self.origin, "null")) self.origin_nonce else null);
            const site_id = nonceText(&site_buf, if (std.mem.eql(u8, self.top_level_site, "null")) self.top_level_nonce else null);
            return std.fmt.allocPrint(allocator, "{s} {s} {d} {s} {s}", .{ self.origin, self.top_level_site, @intFromBool(self.has_cross_site_ancestor), origin_id, site_id });
        }
        return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ self.origin, self.top_level_site, @intFromBool(self.has_cross_site_ancestor) });
    }

    fn nonceText(buf: *[32]u8, nonce: ?u128) []const u8 {
        const value = nonce orelse return "-";
        if (value == 0) return "-";
        return std.fmt.bufPrint(buf, "{x}", .{value}) catch unreachable;
    }

    fn parseNonce(text: []const u8) error{InvalidNonce}!?u128 {
        if (std.mem.eql(u8, text, "-")) return null;
        if (text.len == 0 or text.len > 32 or text[0] == '0') return error.InvalidNonce;
        for (text) |c| if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return error.InvalidNonce;
        return std.fmt.parseInt(u128, text, 16) catch error.InvalidNonce;
    }

    /// The key `serialized` (`serialize`'s form) names, borrowing from it;
    /// null for anything else.
    pub fn parse(serialized: []const u8) ?Self {
        var parts = std.mem.splitScalar(u8, serialized, ' ');
        const origin = parts.next() orelse return null;
        const site = parts.next() orelse return null;
        const bit = parts.next() orelse return null;
        if (origin.len == 0 or site.len == 0) return null;
        const has_cross_site_ancestor = if (std.mem.eql(u8, bit, "1")) true else if (std.mem.eql(u8, bit, "0")) false else return null;
        var key = initBorrowed(origin, site, has_cross_site_ancestor);
        if (parts.next()) |origin_id| {
            const site_id = parts.next() orelse return null;
            if (parts.next() != null or !key.isOpaque()) return null;
            key.origin_nonce = parseNonce(origin_id) catch return null;
            key.top_level_nonce = parseNonce(site_id) catch return null;
            if (!std.mem.eql(u8, origin, "null") and key.origin_nonce != null) return null;
            if (!std.mem.eql(u8, site, "null") and key.top_level_nonce != null) return null;
        }
        return key;
    }

    /// Whether the origin or top-level site is opaque (or missing), which
    /// still makes the key ineligible for persistent storage.
    pub fn isOpaque(self: Self) bool {
        return self.origin.len == 0 or std.mem.eql(u8, self.origin, "null") or
            self.top_level_site.len == 0 or std.mem.eql(u8, self.top_level_site, "null");
    }
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
        // Its bottles hold nothing yet: freeing the map frees all of it.
        errdefer bucket.bottle_map.deinit();

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

        errdefer shelf.bucket_map.deinit();

        // Create the default bucket
        var bucket = try StorageBucket.init(allocator, storage_type);
        errdefer bucket.deinit();
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
        // Storage's obtain-a-storage-key rejects opaque partitions. The
        // existing origin-only administrative shelf is the sole exception;
        // every admitted map key must compare equal to itself.
        if (key.isOpaque() and !key.isOriginOnlyAdministrativeKey()) return error.SecurityError;
        // Check if shelf already exists
        if (self.shelves.getPtr(key)) |shelf| {
            return shelf;
        }

        // Create new shelf, under a copy of the key the shed owns.
        var owned_key = try key.clone(self.allocator);
        errdefer owned_key.deinit();
        var shelf = try StorageShelf.init(self.allocator, self.storage_type);
        errdefer shelf.deinit();
        try self.shelves.put(owned_key, shelf);

        return self.shelves.getPtr(owned_key).?;
    }

    /// Get a shelf without creating it
    pub fn getShelf(self: *Self, key: StorageKey) ?*StorageShelf {
        return self.shelves.getPtr(key);
    }

    /// Remove a shelf
    pub fn removeShelf(self: *Self, key: StorageKey) void {
        if (self.shelves.fetchRemove(key)) |entry| {
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
    /// The user agent's storage shed: local storage, a shelf per storage
    /// key.
    shed: StorageShed,
    /// The session storage sheds: Storage 4.3 gives every traversable
    /// navigable a storage shed of its own, here by the top-level
    /// traversable's browsing context id. Each holds a shelf per storage key;
    /// a shed's shelves stay in its own allocation when this map grows, so a
    /// Storage object's proxy map stays valid. Until each tab holds its
    /// traversable's shed itself (instances B4), they end with the Browser.
    session_sheds: std.AutoHashMapUnmanaged(u64, StorageShed) = .empty,
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
        var sheds = self.session_sheds.valueIterator();
        while (sheds.next()) |shed| shed.deinit();
        self.session_sheds.deinit(self.allocator);
        self.buckets.deinit();
    }

    pub fn lock(self: *UserAgentStorage) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    pub fn unlock(self: *UserAgentStorage) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// "Obtain a local storage shelf" for `key`, a key "obtain a storage key"
    /// gave (the caller holds the lock, or is the window thread reaching a
    /// shelf only it uses). Null - failure - for a key it would have refused.
    pub fn obtainLocalShelfLocked(self: *UserAgentStorage, key: StorageKey) !?*StorageShelf {
        const storage_key = obtainStorageKey(key) orelse return null;
        return try self.shed.obtainShelf(storage_key);
    }

    /// "Obtain a session storage shelf": `key`'s shelf in the session storage
    /// shed of the top-level traversable `traversable`, made on first use.
    pub fn obtainSessionShelfLocked(self: *UserAgentStorage, traversable: u64, key: StorageKey) !?*StorageShelf {
        const storage_key = obtainStorageKey(key) orelse return null;
        const shed = try self.sessionShedLocked(traversable);
        return try shed.obtainShelf(storage_key);
    }

    /// The session storage shed of the top-level traversable `traversable`,
    /// made empty on first use.
    pub fn sessionShedLocked(self: *UserAgentStorage, traversable: u64) !*StorageShed {
        const entry = try self.session_sheds.getOrPut(self.allocator, traversable);
        if (!entry.found_existing) entry.value_ptr.* = StorageShed.init(self.allocator, .session);
        return entry.value_ptr;
    }

    /// The local storage shelf of `origin` alone, with no top-level site:
    /// what the origin-only callers (StorageManager's persist, persisted and
    /// estimate, the quota manager) reach until they are given their
    /// environment's storage key. Kept apart from every partition a real
    /// environment's key names (no site is empty), so it shares nothing with
    /// them. The caller holds the lock.
    pub fn obtainShelfLocked(self: *UserAgentStorage, origin: []const u8) !?*StorageShelf {
        if (origin.len == 0 or std.mem.eql(u8, origin, "null")) return null;
        return try self.shed.obtainShelf(StorageKey.initBorrowed(origin, "", false));
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

/// Storage "obtain a storage key", given `key`, its environment's key for
/// non-storage purposes (dom.global_settings computes it): failure (null)
/// when its origin is opaque - step 2 - and, a deviation stated, when its
/// top-level site is: Crane gives an opaque site no identity, so every
/// sandboxed or opaque top-level page would share one "null" partition
/// (lesson: a missing partition key is not a shared partition). The browsers
/// give such a page a partition of its own (Chromium's opaque top-level site
/// is a nonce, Gecko's partitionKey a null principal's); Crane gives it none.
/// Step 3, "the user has disabled storage", has no setting here.
/// https://storage.spec.whatwg.org/#obtain-a-storage-key
pub fn obtainStorageKey(key: StorageKey) ?StorageKey {
    if (key.isOpaque()) return null;
    return key;
}

/// Obtain a local storage shelf
/// https://storage.spec.whatwg.org/#obtain-a-local-storage-shelf
///
/// From `user_agent_storage`, the user agent's - its Browser's. The caller
/// holds its lock while it uses the shelf from a thread other than the
/// Browser's window thread (UserAgentStorage, THREADS).
pub fn obtainLocalStorageShelf(user_agent_storage: *UserAgentStorage, key: StorageKey) !?*StorageShelf {
    user_agent_storage.lock();
    defer user_agent_storage.unlock();
    return user_agent_storage.obtainLocalShelfLocked(key);
}

/// The proxy map of `identifier`'s bottle on `shelf`'s default bucket, the
/// bottle made on first use with `allocator` (the shed's: freed with it).
fn bottleMapOf(allocator: std.mem.Allocator, shelf: *StorageShelf, identifier: StorageIdentifier) !?StorageProxyMap {
    const bucket = shelf.getDefaultBucket() orelse return null;
    if (bucket.getBottle(identifier)) |bottle| return bottle.createProxyMap();
    const endpoint = getEndpoint(identifier);
    try bucket.bottle_map.put(identifier, StorageBottle.init(allocator, endpoint.quota));
    return bucket.bottle_map.getPtr(identifier).?.createProxyMap();
}

/// Obtain a storage bottle map for an endpoint: local storage's, in the
/// Browser's storage shed, for `key`.
/// https://storage.spec.whatwg.org/#obtain-a-storage-bottle-map
///
/// The shelf, bucket and bottle are found or made under the lock of
/// `user_agent_storage`, its Browser's; the proxy map returned reads and
/// writes the bottle's map without it (UserAgentStorage, THREADS). Null when
/// "obtain a storage key" fails for `key`.
pub fn obtainStorageBottleMap(
    user_agent_storage: *UserAgentStorage,
    key: StorageKey,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    user_agent_storage.lock();
    defer user_agent_storage.unlock();
    const shelf = try user_agent_storage.obtainLocalShelfLocked(key) orelse return null;
    return bottleMapOf(user_agent_storage.allocator, shelf, identifier);
}

/// Obtain a local storage bottle map
/// https://storage.spec.whatwg.org/#obtain-a-local-storage-bottle-map
pub fn obtainLocalStorageBottleMap(
    user_agent_storage: *UserAgentStorage,
    key: StorageKey,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    return obtainStorageBottleMap(user_agent_storage, key, identifier);
}

/// Obtain a session storage bottle map: `key`'s, in the session storage
/// shed of the top-level traversable `traversable` (its browsing context
/// id). Null when "obtain a storage key" fails for `key`.
/// https://storage.spec.whatwg.org/#obtain-a-session-storage-bottle-map
pub fn obtainSessionStorageBottleMap(
    user_agent_storage: *UserAgentStorage,
    traversable: u64,
    key: StorageKey,
    identifier: StorageIdentifier,
) !?StorageProxyMap {
    user_agent_storage.lock();
    defer user_agent_storage.unlock();
    const shelf = try user_agent_storage.obtainSessionShelfLocked(traversable, key) orelse return null;
    return bottleMapOf(user_agent_storage.allocator, shelf, identifier);
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

/// A first-party storage key of https://example.com.
const example_key = StorageKey.initBorrowed("https://example.com", "https://example.com", false);

test "StorageKey - init and equals" {
    const allocator = std.testing.allocator;

    var key1 = try StorageKey.init(allocator, "https://example.com", "https://example.com", false);
    defer key1.deinit();

    var key2 = try StorageKey.init(allocator, "https://example.com", "https://example.com", false);
    defer key2.deinit();

    var key3 = try StorageKey.init(allocator, "https://other.com", "https://other.com", false);
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

    const key = StorageKey.initBorrowed("https://example.com", "https://example.com", false);

    // First obtain creates shelf
    const shelf1 = try shed.obtainShelf(key);
    try std.testing.expectEqual(@as(usize, 1), shed.count());

    // Second obtain returns same shelf
    const shelf2 = try shed.obtainShelf(key);
    try std.testing.expect(shelf1 == shelf2);
    try std.testing.expectEqual(@as(usize, 1), shed.count());

    // Different key creates new shelf
    const key2 = StorageKey.initBorrowed("https://other.com", "https://other.com", false);
    _ = try shed.obtainShelf(key2);
    try std.testing.expectEqual(@as(usize, 2), shed.count());
}

test "obtainLocalStorageBottleMap" {
    var user_agent_storage = UserAgentStorage.init(std.testing.allocator);
    defer user_agent_storage.deinit();

    // Get bottle map for indexedDB
    const proxy = try obtainLocalStorageBottleMap(&user_agent_storage, example_key, .indexedDB);
    try std.testing.expect(proxy != null);

    // Store some data
    try proxy.?.set("testKey", "testValue");
    try std.testing.expectEqualStrings("testValue", proxy.?.get("testKey").?);

    // Opaque origin should return null
    const opaque_result = try obtainLocalStorageBottleMap(&user_agent_storage, StorageKey.initBorrowed("null", "https://example.com", true), .indexedDB);
    try std.testing.expect(opaque_result == null);
}

test "StorageEstimate" {
    var user_agent_storage = UserAgentStorage.init(std.testing.allocator);
    defer user_agent_storage.deinit();

    // Store some data first, in the origin-only shelf the estimate reads.
    user_agent_storage.lock();
    const shelf = (try user_agent_storage.obtainShelfLocked("https://example.com")).?;
    user_agent_storage.unlock();
    const proxy = try bottleMapOf(user_agent_storage.allocator, shelf, .indexedDB);
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

    const in_a = (try obtainLocalStorageBottleMap(&a, example_key, .localStorage)).?;
    try in_a.set("k", "a");
    const in_b = (try obtainLocalStorageBottleMap(&b, example_key, .localStorage)).?;
    try std.testing.expect(in_b.get("k") == null);
    const in_a_again = (try obtainLocalStorageBottleMap(&a, example_key, .localStorage)).?;
    try std.testing.expectEqualStrings("a", in_a_again.get("k").?);

    // Their bucket file systems too.
    const fs_a = try getBucketFileSystem(&a, "https://example.com");
    try std.testing.expect(fs_a == try getBucketFileSystem(&a, "https://example.com"));
    try std.testing.expect(fs_a != try getBucketFileSystem(&b, "https://example.com"));
    try std.testing.expectError(error.SecurityError, getBucketFileSystem(&a, "null"));
}
