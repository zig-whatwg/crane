//! IndexedDB Storage Integration
//!
//! Integrates IndexedDB with the WHATWG Storage Standard by mapping
//! IDB databases to storage bottles within the storage hierarchy.
//!
//! ## Architecture
//!
//! ```
//! StorageShed (user agent)
//!     └── StorageKey (origin)
//!         └── StorageShelf
//!             └── StorageBucket ("default")
//!                 └── StorageBottle (identifier: .indexedDB)
//!                     └── IDBStorageArea
//!                         └── DatabaseMetadata (name → version, connections)
//! ```
//!
//! ## W3C IndexedDB 3.0 + WHATWG Storage Standard Integration
//!
//! Per the specifications:
//! - Each origin has a single "indexedDB" storage bottle
//! - The bottle contains all IndexedDB databases for that origin
//! - Database operations use the bottle's backing storage
//!
//! ## Spec References
//!
//! - WHATWG Storage Standard: https://storage.spec.whatwg.org/
//! - W3C IndexedDB 3.0: https://w3c.github.io/IndexedDB/

const std = @import("std");

// Storage Standard types
const standard = @import("../standard.zig");
const StorageShed = standard.StorageShed;
const StorageShelf = standard.StorageShelf;
const StorageBucket = standard.StorageBucket;
const StorageBottle = standard.StorageBottle;
const StorageKey = standard.StorageKey;
const StorageIdentifier = standard.StorageIdentifier;
const StorageType = standard.StorageType;
const obtainStorageKey = standard.obtainStorageKey;
const initGlobalStorageShed = standard.initGlobalStorageShed;
const deinitGlobalStorageShed = standard.deinitGlobalStorageShed;

// IndexedDB types
const IDBDatabase = @import("database.zig").IDBDatabase;
const IDBFactory = @import("factory.zig").IDBFactory;
const IDBError = @import("errors.zig").IDBError;

// ============================================================================
// IDB Storage Area (Per-Origin Database Container)
// ============================================================================

/// Metadata for a single IndexedDB database within a storage bottle
pub const DatabaseMetadata = struct {
    /// Database name (owned)
    name: []const u8,
    /// Current database version
    version: u64,
    /// Active connections to this database
    connections: std.ArrayListUnmanaged(*IDBDatabase),
    /// Creation timestamp (milliseconds since epoch)
    created_at: i64,
    /// Last modified timestamp
    modified_at: i64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8, version: u64) !Self {
        const name_copy = try allocator.dupe(u8, name);
        const now = std.time.milliTimestamp();
        return Self{
            .name = name_copy,
            .version = version,
            .connections = .{},
            .created_at = now,
            .modified_at = now,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.connections.deinit(allocator);
        self.* = undefined;
    }

    pub fn addConnection(self: *Self, db: *IDBDatabase) !void {
        try self.connections.append(self.allocator, db);
    }

    pub fn removeConnection(self: *Self, db: *IDBDatabase) void {
        for (self.connections.items, 0..) |conn, i| {
            if (conn == db) {
                _ = self.connections.swapRemove(i);
                return;
            }
        }
    }

    pub fn connectionCount(self: Self) usize {
        return self.connections.items.len;
    }

    pub fn updateVersion(self: *Self, new_version: u64) void {
        self.version = new_version;
        self.modified_at = std.time.milliTimestamp();
    }
};

/// Storage area for IndexedDB within a storage bottle
/// Contains all IDB databases for a single origin
pub const IDBStorageArea = struct {
    /// Map of database name → metadata
    databases: std.StringHashMap(DatabaseMetadata),
    /// Allocator for this storage area
    allocator: std.mem.Allocator,
    /// Reference to parent bottle (for quota tracking)
    bottle: *StorageBottle,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, bottle: *StorageBottle) Self {
        return Self{
            .databases = std.StringHashMap(DatabaseMetadata).init(allocator),
            .allocator = allocator,
            .bottle = bottle,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.databases.iterator();
        while (iter.next()) |entry| {
            var metadata = entry.value_ptr.*;
            metadata.deinit(self.allocator);
        }
        self.databases.deinit();
    }

    /// Get database metadata by name
    pub fn getDatabase(self: *Self, name: []const u8) ?*DatabaseMetadata {
        return self.databases.getPtr(name);
    }

    /// Create or get a database
    pub fn getOrCreateDatabase(self: *Self, name: []const u8, version: u64) !*DatabaseMetadata {
        const result = self.databases.getPtr(name);
        if (result) |metadata| {
            return metadata;
        }

        // Create new database
        const metadata = try DatabaseMetadata.init(self.allocator, name, version);
        try self.databases.put(name, metadata);
        return self.databases.getPtr(name).?;
    }

    /// Delete a database
    pub fn deleteDatabase(self: *Self, name: []const u8) bool {
        if (self.databases.fetchRemove(name)) |kv| {
            var metadata = kv.value;

            // Close all connections
            for (metadata.connections.items) |conn| {
                conn.close();
            }

            metadata.deinit(self.allocator);
            return true;
        }
        return false;
    }

    /// List all database names
    pub fn listDatabases(self: *Self, allocator: std.mem.Allocator) ![]const []const u8 {
        const db_count = self.databases.count();
        const names = try allocator.alloc([]const u8, db_count);

        var idx: usize = 0;
        var iter = self.databases.iterator();
        while (iter.next()) |entry| {
            names[idx] = entry.key_ptr.*;
            idx += 1;
        }

        return names;
    }

    /// Get number of databases
    pub fn count(self: Self) usize {
        return self.databases.count();
    }

    /// Check if database exists
    pub fn hasDatabase(self: Self, name: []const u8) bool {
        return self.databases.contains(name);
    }
};

// ============================================================================
// Storage Integration Manager
// ============================================================================

/// Manages the integration between IndexedDB and Storage Standard
pub const StorageIntegrationManager = struct {
    /// Map of origin → IDBStorageArea
    storage_areas: std.StringHashMap(*IDBStorageArea),
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .storage_areas = std.StringHashMap(*IDBStorageArea).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.storage_areas.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.storage_areas.deinit();
    }

    /// Get or create a storage area for an origin
    /// This integrates with the WHATWG Storage Standard hierarchy
    pub fn getStorageArea(self: *Self, origin: []const u8) !*IDBStorageArea {
        // Check cache first
        if (self.storage_areas.get(origin)) |area| {
            return area;
        }

        // Get storage bottle from Storage Standard hierarchy
        const shed = try initGlobalStorageShed(self.allocator);
        const key = try obtainStorageKey(self.allocator, origin) orelse {
            return IDBError.SecurityError;
        };
        defer {
            var k = key;
            k.deinit();
        }

        const shelf = try shed.obtainShelf(key);
        const bucket = shelf.getDefaultBucket() orelse {
            return IDBError.InvalidStateError;
        };
        const bottle = bucket.getBottle(.indexedDB) orelse {
            return IDBError.InvalidStateError;
        };

        // Create storage area
        const area = try self.allocator.create(IDBStorageArea);
        errdefer self.allocator.destroy(area);

        area.* = IDBStorageArea.init(self.allocator, bottle);

        // Cache by origin
        const origin_copy = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(origin_copy);

        try self.storage_areas.put(origin_copy, area);

        return area;
    }

    /// Remove a storage area (usually after clearing storage)
    pub fn removeStorageArea(self: *Self, origin: []const u8) void {
        if (self.storage_areas.fetchRemove(origin)) |kv| {
            self.allocator.free(kv.key);
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        }
    }

    /// Clear all IndexedDB data for an origin
    pub fn clearOrigin(self: *Self, origin: []const u8) void {
        if (self.storage_areas.get(origin)) |area| {
            // Delete all databases
            var iter = area.databases.iterator();
            var names_to_delete: std.ArrayListUnmanaged([]const u8) = .{};
            defer names_to_delete.deinit(self.allocator);

            while (iter.next()) |entry| {
                names_to_delete.append(self.allocator, entry.key_ptr.*) catch continue;
            }

            for (names_to_delete.items) |name| {
                _ = area.deleteDatabase(name);
            }
        }
    }
};

// ============================================================================
// Global Integration Manager
// ============================================================================

var global_integration_manager: ?*StorageIntegrationManager = null;

/// Initialize the global integration manager
pub fn initGlobalIntegrationManager(allocator: std.mem.Allocator) !*StorageIntegrationManager {
    if (global_integration_manager) |mgr| {
        return mgr;
    }

    const mgr = try allocator.create(StorageIntegrationManager);
    mgr.* = StorageIntegrationManager.init(allocator);
    global_integration_manager = mgr;
    return mgr;
}

/// Get the global integration manager
pub fn getGlobalIntegrationManager() ?*StorageIntegrationManager {
    return global_integration_manager;
}

/// Deinitialize the global integration manager
pub fn deinitGlobalIntegrationManager(allocator: std.mem.Allocator) void {
    if (global_integration_manager) |mgr| {
        mgr.deinit();
        allocator.destroy(mgr);
        global_integration_manager = null;
    }
}

// ============================================================================
// Integration Algorithms
// ============================================================================

/// Open an IndexedDB database using storage integration
/// This is the spec-compliant way to open a database through the storage hierarchy
pub fn openDatabase(
    allocator: std.mem.Allocator,
    origin: []const u8,
    name: []const u8,
    version: u64,
) !*IDBDatabase {
    const mgr = try initGlobalIntegrationManager(allocator);
    const area = try mgr.getStorageArea(origin);
    const metadata = try area.getOrCreateDatabase(name, version);

    // Create database connection
    const db = try allocator.create(IDBDatabase);
    errdefer allocator.destroy(db);

    db.* = IDBDatabase.init(allocator, name, metadata.version);

    // Track connection
    try metadata.addConnection(db);

    return db;
}

/// Delete an IndexedDB database using storage integration
pub fn deleteDatabase(
    allocator: std.mem.Allocator,
    origin: []const u8,
    name: []const u8,
) !bool {
    const mgr = try initGlobalIntegrationManager(allocator);
    const area = try mgr.getStorageArea(origin);
    return area.deleteDatabase(name);
}

/// List all IndexedDB databases for an origin
pub fn listDatabases(
    allocator: std.mem.Allocator,
    origin: []const u8,
) ![]const []const u8 {
    const mgr = try initGlobalIntegrationManager(allocator);
    const area = try mgr.getStorageArea(origin);
    return area.listDatabases(allocator);
}

/// Get database info (name, version) for an origin
pub const DatabaseInfo = struct {
    name: []const u8,
    version: u64,
};

pub fn getDatabaseInfo(
    allocator: std.mem.Allocator,
    origin: []const u8,
) ![]DatabaseInfo {
    const mgr = try initGlobalIntegrationManager(allocator);
    const area = try mgr.getStorageArea(origin);

    const db_count = area.count();
    const infos = try allocator.alloc(DatabaseInfo, db_count);

    var idx: usize = 0;
    var iter = area.databases.iterator();
    while (iter.next()) |entry| {
        infos[idx] = DatabaseInfo{
            .name = entry.key_ptr.*,
            .version = entry.value_ptr.version,
        };
        idx += 1;
    }

    return infos;
}

// ============================================================================
// Tests
// ============================================================================

test "DatabaseMetadata - init and deinit" {
    const allocator = std.testing.allocator;

    var metadata = try DatabaseMetadata.init(allocator, "testdb", 1);
    defer metadata.deinit(allocator);

    try std.testing.expectEqualStrings("testdb", metadata.name);
    try std.testing.expectEqual(@as(u64, 1), metadata.version);
    try std.testing.expectEqual(@as(usize, 0), metadata.connectionCount());
}

test "DatabaseMetadata - update version" {
    const allocator = std.testing.allocator;

    var metadata = try DatabaseMetadata.init(allocator, "testdb", 1);
    defer metadata.deinit(allocator);

    const old_modified = metadata.modified_at;
    std.Thread.sleep(1_000_000); // 1ms
    metadata.updateVersion(2);

    try std.testing.expectEqual(@as(u64, 2), metadata.version);
    try std.testing.expect(metadata.modified_at >= old_modified);
}

test "IDBStorageArea - basic operations" {
    const allocator = std.testing.allocator;

    // Create a mock bottle
    var bottle = standard.StorageBottle.init(allocator, null);
    defer bottle.deinit();

    var area = IDBStorageArea.init(allocator, &bottle);
    defer area.deinit();

    // Create database
    const metadata = try area.getOrCreateDatabase("db1", 1);
    try std.testing.expectEqualStrings("db1", metadata.name);
    try std.testing.expectEqual(@as(u64, 1), metadata.version);

    // Get existing database
    const same = try area.getOrCreateDatabase("db1", 1);
    try std.testing.expect(same == metadata);

    // Check existence
    try std.testing.expect(area.hasDatabase("db1"));
    try std.testing.expect(!area.hasDatabase("db2"));

    // Delete database
    try std.testing.expect(area.deleteDatabase("db1"));
    try std.testing.expect(!area.hasDatabase("db1"));
}

test "IDBStorageArea - list databases" {
    const allocator = std.testing.allocator;

    var bottle = standard.StorageBottle.init(allocator, null);
    defer bottle.deinit();

    var area = IDBStorageArea.init(allocator, &bottle);
    defer area.deinit();

    // Create some databases
    _ = try area.getOrCreateDatabase("alpha", 1);
    _ = try area.getOrCreateDatabase("beta", 2);
    _ = try area.getOrCreateDatabase("gamma", 3);

    try std.testing.expectEqual(@as(usize, 3), area.count());

    const names = try area.listDatabases(allocator);
    defer allocator.free(names);

    try std.testing.expectEqual(@as(usize, 3), names.len);
}

test "StorageIntegrationManager - init and deinit" {
    const allocator = std.testing.allocator;

    var mgr = StorageIntegrationManager.init(allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(usize, 0), mgr.storage_areas.count());
}

// test "StorageIntegrationManager - get storage area" - SKIPPED
// (requires proper global state management)

// Integration tests with global state - skipped due to test isolation issues
// These tests require careful management of global singletons between test runs
// TODO: Refactor to use test fixtures instead of globals

// test "integration - open database" - SKIPPED
// test "integration - delete database" - SKIPPED
// test "integration - list databases" - SKIPPED
