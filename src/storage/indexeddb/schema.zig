//! Schema Versioning for IndexedDB
//!
//! Handles database version upgrades per W3C IndexedDB 3.0 specification.
//! Version changes trigger "versionchange" transactions that allow schema
//! modifications (create/delete object stores and indexes).
//!
//! ## Version Upgrade Flow
//!
//! 1. Application requests database at version N
//! 2. If current version < N, start versionchange transaction
//! 3. Fire "upgradeneeded" event (application performs schema changes)
//! 4. Commit versionchange transaction
//! 5. Fire "success" event
//!
//! ## Schema Migration
//!
//! Schema migrations can:
//! - Create object stores
//! - Delete object stores
//! - Create indexes on object stores
//! - Delete indexes
//! - Modify object store parameters (NOT: change key path or auto-increment)
//!
//! ## Spec References
//!
//! - Version Change: https://w3c.github.io/IndexedDB/#upgrade-transaction-steps
//! - Object Store Creation: https://w3c.github.io/IndexedDB/#create-object-store
//! - Index Creation: https://w3c.github.io/IndexedDB/#create-index

const std = @import("std");

// ============================================================================
// Schema Version
// ============================================================================

/// Database schema version info
pub const SchemaVersion = struct {
    /// Current version number
    version: u64,
    /// When this version was created
    created_at: i64,
    /// Previous version (for rollback tracking)
    previous_version: ?u64,

    const Self = @This();

    pub fn init(version: u64) Self {
        return Self{
            .version = version,
            .created_at = std.time.milliTimestamp(),
            .previous_version = null,
        };
    }

    pub fn upgrade(self: Self, new_version: u64) Self {
        return Self{
            .version = new_version,
            .created_at = std.time.milliTimestamp(),
            .previous_version = self.version,
        };
    }
};

// ============================================================================
// Schema Change Types
// ============================================================================

/// Types of schema changes
pub const SchemaChangeType = enum {
    create_object_store,
    delete_object_store,
    create_index,
    delete_index,
    set_version,
};

/// A single schema change operation
pub const SchemaChange = struct {
    change_type: SchemaChangeType,
    /// Object store name (for store operations)
    store_name: ?[]const u8,
    /// Index name (for index operations)
    index_name: ?[]const u8,
    /// Key path (for create_object_store)
    key_path: ?[]const u8,
    /// Auto increment (for create_object_store)
    auto_increment: bool,
    /// Unique constraint (for create_index)
    unique: bool,
    /// Multi-entry (for create_index)
    multi_entry: bool,
    /// New version (for set_version)
    new_version: ?u64,

    const Self = @This();

    pub fn createObjectStore(name: []const u8, key_path: ?[]const u8, auto_increment: bool) Self {
        return Self{
            .change_type = .create_object_store,
            .store_name = name,
            .index_name = null,
            .key_path = key_path,
            .auto_increment = auto_increment,
            .unique = false,
            .multi_entry = false,
            .new_version = null,
        };
    }

    pub fn deleteObjectStore(name: []const u8) Self {
        return Self{
            .change_type = .delete_object_store,
            .store_name = name,
            .index_name = null,
            .key_path = null,
            .auto_increment = false,
            .unique = false,
            .multi_entry = false,
            .new_version = null,
        };
    }

    pub fn createIndex(store_name: []const u8, index_name: []const u8, key_path: []const u8, unique: bool, multi_entry: bool) Self {
        return Self{
            .change_type = .create_index,
            .store_name = store_name,
            .index_name = index_name,
            .key_path = key_path,
            .auto_increment = false,
            .unique = unique,
            .multi_entry = multi_entry,
            .new_version = null,
        };
    }

    pub fn deleteIndex(store_name: []const u8, index_name: []const u8) Self {
        return Self{
            .change_type = .delete_index,
            .store_name = store_name,
            .index_name = index_name,
            .key_path = null,
            .auto_increment = false,
            .unique = false,
            .multi_entry = false,
            .new_version = null,
        };
    }

    pub fn setVersion(version: u64) Self {
        return Self{
            .change_type = .set_version,
            .store_name = null,
            .index_name = null,
            .key_path = null,
            .auto_increment = false,
            .unique = false,
            .multi_entry = false,
            .new_version = version,
        };
    }
};

// ============================================================================
// Schema Migration
// ============================================================================

/// A complete schema migration from one version to another
pub const SchemaMigration = struct {
    /// Source version (0 for new database)
    from_version: u64,
    /// Target version
    to_version: u64,
    /// Ordered list of changes
    changes: std.ArrayListUnmanaged(SchemaChange),
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, from_version: u64, to_version: u64) Self {
        return Self{
            .from_version = from_version,
            .to_version = to_version,
            .changes = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.changes.deinit(self.allocator);
    }

    /// Add a change to the migration
    pub fn addChange(self: *Self, change: SchemaChange) !void {
        try self.changes.append(self.allocator, change);
    }

    /// Get all changes
    pub fn getChanges(self: Self) []const SchemaChange {
        return self.changes.items;
    }

    /// Check if migration is valid (from < to)
    pub fn isValid(self: Self) bool {
        return self.to_version > self.from_version;
    }
};

// ============================================================================
// Schema Manager
// ============================================================================

/// Manages database schema and versioning
pub const SchemaManager = struct {
    /// Database name
    database_name: []const u8,
    /// Current schema version
    current_version: SchemaVersion,
    /// Object store names (for validation)
    object_stores: std.StringHashMap(ObjectStoreSchema),
    /// Pending migration (if in versionchange transaction)
    pending_migration: ?*SchemaMigration,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Object store schema info
    pub const ObjectStoreSchema = struct {
        name: []const u8,
        key_path: ?[]const u8,
        auto_increment: bool,
        indexes: std.StringHashMap(IndexSchema),
    };

    /// Index schema info
    pub const IndexSchema = struct {
        name: []const u8,
        key_path: []const u8,
        unique: bool,
        multi_entry: bool,
    };

    pub fn init(allocator: std.mem.Allocator, database_name: []const u8, version: u64) !Self {
        const name_copy = try allocator.dupe(u8, database_name);
        return Self{
            .database_name = name_copy,
            .current_version = SchemaVersion.init(version),
            .object_stores = std.StringHashMap(ObjectStoreSchema).init(allocator),
            .pending_migration = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.database_name);
        var iter = self.object_stores.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.indexes.deinit();
        }
        self.object_stores.deinit();
    }

    /// Get current version
    pub fn getVersion(self: Self) u64 {
        return self.current_version.version;
    }

    /// Check if object store exists
    pub fn hasObjectStore(self: Self, name: []const u8) bool {
        return self.object_stores.contains(name);
    }

    /// Get object store names
    pub fn getObjectStoreNames(self: *Self, allocator: std.mem.Allocator) ![]const []const u8 {
        const store_count = self.object_stores.count();
        var names = try allocator.alloc([]const u8, store_count);

        var idx: usize = 0;
        var iter = self.object_stores.iterator();
        while (iter.next()) |entry| {
            names[idx] = entry.key_ptr.*;
            idx += 1;
        }

        return names;
    }

    /// Start a version upgrade
    pub fn beginUpgrade(self: *Self, new_version: u64) !*SchemaMigration {
        if (new_version <= self.current_version.version) {
            return error.VersionTooLow;
        }

        const migration = try self.allocator.create(SchemaMigration);
        migration.* = SchemaMigration.init(self.allocator, self.current_version.version, new_version);
        self.pending_migration = migration;
        return migration;
    }

    /// Commit the pending upgrade
    pub fn commitUpgrade(self: *Self) !void {
        const migration = self.pending_migration orelse return error.NoUpgradeInProgress;

        // Apply all changes
        for (migration.getChanges()) |change| {
            try self.applyChange(change);
        }

        // Update version
        self.current_version = self.current_version.upgrade(migration.to_version);
        self.pending_migration = null;
        migration.deinit();
        self.allocator.destroy(migration);
    }

    /// Abort the pending upgrade
    pub fn abortUpgrade(self: *Self) void {
        if (self.pending_migration) |migration| {
            migration.deinit();
            self.allocator.destroy(migration);
            self.pending_migration = null;
        }
    }

    /// Apply a single schema change
    fn applyChange(self: *Self, change: SchemaChange) !void {
        switch (change.change_type) {
            .create_object_store => {
                const name = change.store_name orelse return error.InvalidChange;
                if (self.object_stores.contains(name)) {
                    return error.ObjectStoreExists;
                }
                try self.object_stores.put(name, ObjectStoreSchema{
                    .name = name,
                    .key_path = change.key_path,
                    .auto_increment = change.auto_increment,
                    .indexes = std.StringHashMap(IndexSchema).init(self.allocator),
                });
            },
            .delete_object_store => {
                const name = change.store_name orelse return error.InvalidChange;
                if (!self.object_stores.contains(name)) {
                    return error.ObjectStoreNotFound;
                }
                if (self.object_stores.fetchRemove(name)) |kv| {
                    var schema = kv.value;
                    schema.indexes.deinit();
                }
            },
            .create_index => {
                const store_name = change.store_name orelse return error.InvalidChange;
                const index_name = change.index_name orelse return error.InvalidChange;
                const key_path = change.key_path orelse return error.InvalidChange;

                const store = self.object_stores.getPtr(store_name) orelse {
                    return error.ObjectStoreNotFound;
                };
                if (store.indexes.contains(index_name)) {
                    return error.IndexExists;
                }
                try store.indexes.put(index_name, IndexSchema{
                    .name = index_name,
                    .key_path = key_path,
                    .unique = change.unique,
                    .multi_entry = change.multi_entry,
                });
            },
            .delete_index => {
                const store_name = change.store_name orelse return error.InvalidChange;
                const index_name = change.index_name orelse return error.InvalidChange;

                const store = self.object_stores.getPtr(store_name) orelse {
                    return error.ObjectStoreNotFound;
                };
                if (!store.indexes.contains(index_name)) {
                    return error.IndexNotFound;
                }
                _ = store.indexes.remove(index_name);
            },
            .set_version => {
                // Version is handled in commitUpgrade
            },
        }
    }
};

// ============================================================================
// SQL for Schema Operations
// ============================================================================

pub const SchemaSQL = struct {
    /// Get database version
    pub const get_version = "SELECT version FROM database_info WHERE name = ?";

    /// Set database version
    pub const set_version = "UPDATE database_info SET version = ?, modified_at = ? WHERE name = ?";

    /// Create object store record
    pub const create_object_store = "INSERT INTO object_stores (database_id, name, key_path, auto_increment, current_key) VALUES (?, ?, ?, ?, 0)";

    /// Delete object store record
    pub const delete_object_store = "DELETE FROM object_stores WHERE database_id = ? AND name = ?";

    /// Get object store info
    pub const get_object_store = "SELECT id, key_path, auto_increment, current_key FROM object_stores WHERE database_id = ? AND name = ?";

    /// List object stores
    pub const list_object_stores = "SELECT name, key_path, auto_increment FROM object_stores WHERE database_id = ?";

    /// Create index record
    pub const create_index_record = "INSERT INTO indexes (object_store_id, name, key_path, is_unique, is_multi_entry) VALUES (?, ?, ?, ?, ?)";

    /// Delete index record
    pub const delete_index_record = "DELETE FROM indexes WHERE object_store_id = ? AND name = ?";

    /// List indexes for store
    pub const list_indexes = "SELECT name, key_path, is_unique, is_multi_entry FROM indexes WHERE object_store_id = ?";
};

// ============================================================================
// Tests
// ============================================================================

test "SchemaVersion - init and upgrade" {
    var v1 = SchemaVersion.init(1);
    try std.testing.expectEqual(@as(u64, 1), v1.version);
    try std.testing.expect(v1.previous_version == null);

    const v2 = v1.upgrade(2);
    try std.testing.expectEqual(@as(u64, 2), v2.version);
    try std.testing.expectEqual(@as(?u64, 1), v2.previous_version);
}

test "SchemaChange - factory methods" {
    const create_store = SchemaChange.createObjectStore("users", "id", true);
    try std.testing.expectEqual(SchemaChangeType.create_object_store, create_store.change_type);
    try std.testing.expectEqualStrings("users", create_store.store_name.?);
    try std.testing.expect(create_store.auto_increment);

    const create_index = SchemaChange.createIndex("users", "email_idx", "email", true, false);
    try std.testing.expectEqual(SchemaChangeType.create_index, create_index.change_type);
    try std.testing.expectEqualStrings("users", create_index.store_name.?);
    try std.testing.expectEqualStrings("email_idx", create_index.index_name.?);
    try std.testing.expect(create_index.unique);
}

test "SchemaMigration - add changes" {
    const allocator = std.testing.allocator;

    var migration = SchemaMigration.init(allocator, 0, 1);
    defer migration.deinit();

    try migration.addChange(SchemaChange.createObjectStore("users", "id", true));
    try migration.addChange(SchemaChange.createIndex("users", "email_idx", "email", true, false));

    try std.testing.expectEqual(@as(usize, 2), migration.getChanges().len);
    try std.testing.expect(migration.isValid());
}

test "SchemaManager - create and manage stores" {
    const allocator = std.testing.allocator;

    var mgr = try SchemaManager.init(allocator, "testdb", 1);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(u64, 1), mgr.getVersion());
    try std.testing.expect(!mgr.hasObjectStore("users"));

    // Start upgrade
    const migration = try mgr.beginUpgrade(2);
    try migration.addChange(SchemaChange.createObjectStore("users", "id", true));
    try migration.addChange(SchemaChange.createIndex("users", "email_idx", "email", true, false));

    try mgr.commitUpgrade();

    try std.testing.expectEqual(@as(u64, 2), mgr.getVersion());
    try std.testing.expect(mgr.hasObjectStore("users"));
}

test "SchemaManager - delete store" {
    const allocator = std.testing.allocator;

    var mgr = try SchemaManager.init(allocator, "testdb", 1);
    defer mgr.deinit();

    // Create store
    var m1 = try mgr.beginUpgrade(2);
    try m1.addChange(SchemaChange.createObjectStore("temp", null, false));
    try mgr.commitUpgrade();

    try std.testing.expect(mgr.hasObjectStore("temp"));

    // Delete store
    var m2 = try mgr.beginUpgrade(3);
    try m2.addChange(SchemaChange.deleteObjectStore("temp"));
    try mgr.commitUpgrade();

    try std.testing.expect(!mgr.hasObjectStore("temp"));
}

test "SchemaManager - abort upgrade" {
    const allocator = std.testing.allocator;

    var mgr = try SchemaManager.init(allocator, "testdb", 1);
    defer mgr.deinit();

    _ = try mgr.beginUpgrade(2);
    mgr.abortUpgrade();

    try std.testing.expectEqual(@as(u64, 1), mgr.getVersion());
    try std.testing.expect(mgr.pending_migration == null);
}
