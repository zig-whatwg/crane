//! Index Persistence for IndexedDB
//!
//! Persists secondary index data to SQLite tables. Handles:
//! - Index key extraction from values using key paths
//! - Multi-entry index expansion (array values → multiple entries)
//! - Unique constraint enforcement
//! - Index key ordering per IDBKey spec
//!
//! ## SQLite Schema
//!
//! ```sql
//! CREATE TABLE indexes (
//!     id INTEGER PRIMARY KEY AUTOINCREMENT,
//!     object_store_id INTEGER NOT NULL,
//!     name TEXT NOT NULL,
//!     key_path TEXT NOT NULL,
//!     is_unique INTEGER NOT NULL DEFAULT 0,
//!     is_multi_entry INTEGER NOT NULL DEFAULT 0,
//!     UNIQUE(object_store_id, name),
//!     FOREIGN KEY (object_store_id) REFERENCES object_stores(id) ON DELETE CASCADE
//! );
//!
//! CREATE TABLE index_data (
//!     index_id INTEGER NOT NULL,
//!     index_key BLOB NOT NULL COLLATE IDBKEY,
//!     primary_key BLOB NOT NULL COLLATE IDBKEY,
//!     object_store_id INTEGER NOT NULL,
//!     PRIMARY KEY (index_id, index_key, primary_key),
//!     FOREIGN KEY (index_id) REFERENCES indexes(id) ON DELETE CASCADE
//! ) WITHOUT ROWID;
//! ```
//!
//! ## Multi-Entry Indexes
//!
//! When multi_entry = true and the indexed value is an array:
//! - Each array element becomes a separate index entry
//! - Duplicate elements are ignored
//! - Non-array values are indexed normally
//!
//! ## Spec References
//!
//! - W3C IndexedDB 3.0 Index: https://w3c.github.io/IndexedDB/#index-construct
//! - Multi-entry: https://w3c.github.io/IndexedDB/#index-construct-multiEntry

const std = @import("std");
const IDBKey = @import("key.zig").IDBKey;
const object_store_persistence = @import("object_store_persistence.zig");
const encodeKey = object_store_persistence.encodeKey;
const decodeKey = object_store_persistence.decodeKey;

// ============================================================================
// Index Entry
// ============================================================================

/// A single entry in an index
pub const IndexEntry = struct {
    /// Index key (secondary key)
    index_key: IDBKey,
    /// Encoded index key bytes
    encoded_index_key: []const u8,
    /// Primary key in object store
    primary_key: IDBKey,
    /// Encoded primary key bytes
    encoded_primary_key: []const u8,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, index_key: IDBKey, primary_key: IDBKey) !Self {
        const encoded_idx = try encodeKey(allocator, index_key);
        errdefer allocator.free(encoded_idx);

        const encoded_pk = try encodeKey(allocator, primary_key);
        errdefer allocator.free(encoded_pk);

        return Self{
            .index_key = index_key,
            .encoded_index_key = encoded_idx,
            .primary_key = primary_key,
            .encoded_primary_key = encoded_pk,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.encoded_index_key);
        self.allocator.free(self.encoded_primary_key);
        self.* = undefined;
    }
};

// ============================================================================
// Index Persistence Manager
// ============================================================================

/// Manages persistence of index data to SQLite
pub const IndexPersistence = struct {
    /// Index ID in SQLite
    index_id: i64,
    /// Object store ID this index belongs to
    object_store_id: i64,
    /// Index name
    name: []const u8,
    /// Key path for extracting index keys
    key_path: []const u8,
    /// Whether this index enforces uniqueness
    is_unique: bool,
    /// Whether to expand array values into multiple entries
    is_multi_entry: bool,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        index_id: i64,
        object_store_id: i64,
        name: []const u8,
        key_path: []const u8,
        is_unique: bool,
        is_multi_entry: bool,
    ) !Self {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const kp_copy = try allocator.dupe(u8, key_path);
        errdefer allocator.free(kp_copy);

        return Self{
            .index_id = index_id,
            .object_store_id = object_store_id,
            .name = name_copy,
            .key_path = kp_copy,
            .is_unique = is_unique,
            .is_multi_entry = is_multi_entry,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.key_path);
        self.* = undefined;
    }

    /// Generate index entries for a value being stored
    /// Returns multiple entries if multi_entry and value is array
    pub fn generateEntries(
        self: Self,
        allocator: std.mem.Allocator,
        index_key: IDBKey,
        primary_key: IDBKey,
    ) ![]IndexEntry {
        if (self.is_multi_entry and index_key == .array) {
            // Multi-entry: create entry for each array element
            const arr = index_key.array;

            // Use a hash set to track seen keys (for deduplication)
            var seen = std.AutoHashMap(u64, void).init(allocator);
            defer seen.deinit();

            var entries = std.ArrayList(IndexEntry).init(allocator);
            errdefer {
                for (entries.items) |*e| e.deinit();
                entries.deinit();
            }

            for (arr) |elem| {
                // Simple hash for deduplication (production would use proper key comparison)
                const hash = hashKey(elem);
                if (!seen.contains(hash)) {
                    try seen.put(hash, {});
                    const entry = try IndexEntry.init(allocator, elem, primary_key);
                    try entries.append(entry);
                }
            }

            return try entries.toOwnedSlice();
        } else {
            // Single entry
            var entries = try allocator.alloc(IndexEntry, 1);
            entries[0] = try IndexEntry.init(allocator, index_key, primary_key);
            return entries;
        }
    }

    /// Simple hash for key deduplication
    fn hashKey(key: IDBKey) u64 {
        return switch (key) {
            .number => |n| @bitCast(n),
            .string => |s| std.hash.Wyhash.hash(0, s),
            .date => |d| @bitCast(d),
            .binary => |b| std.hash.Wyhash.hash(0, b),
            .array => |_| 0, // Arrays shouldn't appear in multi-entry expansion
            .none => 0,
        };
    }
};

// ============================================================================
// Index Manager
// ============================================================================

/// Manages all indexes for an object store
pub const IndexManager = struct {
    /// Indexes by name
    indexes: std.StringHashMap(*IndexPersistence),
    /// Object store ID
    object_store_id: i64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, object_store_id: i64) Self {
        return Self{
            .indexes = std.StringHashMap(*IndexPersistence).init(allocator),
            .object_store_id = object_store_id,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.indexes.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.indexes.deinit();
    }

    /// Add an index
    pub fn addIndex(self: *Self, persistence: *IndexPersistence) !void {
        try self.indexes.put(persistence.name, persistence);
    }

    /// Get an index by name
    pub fn getIndex(self: *Self, name: []const u8) ?*IndexPersistence {
        return self.indexes.get(name);
    }

    /// Remove an index
    pub fn removeIndex(self: *Self, name: []const u8) void {
        if (self.indexes.fetchRemove(name)) |kv| {
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        }
    }

    /// Get all index names
    pub fn getIndexNames(self: *Self, allocator: std.mem.Allocator) ![]const []const u8 {
        const idx_count = self.indexes.count();
        var names = try allocator.alloc([]const u8, idx_count);

        var idx: usize = 0;
        var iter = self.indexes.iterator();
        while (iter.next()) |entry| {
            names[idx] = entry.key_ptr.*;
            idx += 1;
        }

        return names;
    }

    /// Count indexes
    pub fn count(self: Self) usize {
        return self.indexes.count();
    }

    /// Generate all index entries for a value
    pub fn generateAllEntries(
        self: *Self,
        allocator: std.mem.Allocator,
        primary_key: IDBKey,
        index_keys: std.StringHashMap(IDBKey),
    ) !std.ArrayList(struct { index_name: []const u8, entry: IndexEntry }) {
        var all_entries = std.ArrayList(struct { index_name: []const u8, entry: IndexEntry }).init(allocator);
        errdefer {
            for (all_entries.items) |*item| item.entry.deinit();
            all_entries.deinit();
        }

        var iter = self.indexes.iterator();
        while (iter.next()) |idx_entry| {
            const index = idx_entry.value_ptr.*;

            if (index_keys.get(index.name)) |index_key| {
                const entries = try index.generateEntries(allocator, index_key, primary_key);
                defer allocator.free(entries);

                for (entries) |entry| {
                    try all_entries.append(.{
                        .index_name = index.name,
                        .entry = entry,
                    });
                }
            }
        }

        return all_entries;
    }
};

// ============================================================================
// Unique Constraint Checker
// ============================================================================

/// Checks and enforces unique constraints on indexes
pub const UniqueConstraintChecker = struct {
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    /// Check if adding entries would violate unique constraint
    /// Returns the violating key if found
    pub fn checkViolation(
        _: Self,
        index: IndexPersistence,
        entries: []const IndexEntry,
        existing_check_fn: *const fn (index_id: i64, encoded_key: []const u8) bool,
    ) ?IDBKey {
        if (!index.is_unique) return null;

        for (entries) |entry| {
            if (existing_check_fn(index.index_id, entry.encoded_index_key)) {
                return entry.index_key;
            }
        }

        return null;
    }
};

// ============================================================================
// SQL Statements for Index Operations
// ============================================================================

pub const IndexSQL = struct {
    /// Create an index
    pub const create_index = "INSERT INTO indexes (object_store_id, name, key_path, is_unique, is_multi_entry) VALUES (?, ?, ?, ?, ?)";

    /// Delete an index
    pub const delete_index = "DELETE FROM indexes WHERE object_store_id = ? AND name = ?";

    /// Get index by name
    pub const get_index = "SELECT id, key_path, is_unique, is_multi_entry FROM indexes WHERE object_store_id = ? AND name = ?";

    /// List all indexes for object store
    pub const list_indexes = "SELECT id, name, key_path, is_unique, is_multi_entry FROM indexes WHERE object_store_id = ?";

    /// Insert index entry
    pub const insert_entry = "INSERT INTO index_data (index_id, index_key, primary_key, object_store_id) VALUES (?, ?, ?, ?)";

    /// Delete index entry by primary key
    pub const delete_entry_by_pk = "DELETE FROM index_data WHERE index_id = ? AND primary_key = ?";

    /// Delete all entries for a primary key
    pub const delete_all_entries_by_pk = "DELETE FROM index_data WHERE object_store_id = ? AND primary_key = ?";

    /// Check if index key exists (for unique constraint)
    pub const exists_index_key = "SELECT 1 FROM index_data WHERE index_id = ? AND index_key = ? LIMIT 1";

    /// Get primary keys by index key
    pub const get_by_index_key = "SELECT primary_key FROM index_data WHERE index_id = ? AND index_key = ?";

    /// Get all index entries (ascending)
    pub const get_all_asc = "SELECT index_key, primary_key FROM index_data WHERE index_id = ? ORDER BY index_key ASC, primary_key ASC";

    /// Get all index entries (descending)
    pub const get_all_desc = "SELECT index_key, primary_key FROM index_data WHERE index_id = ? ORDER BY index_key DESC, primary_key DESC";

    /// Count index entries
    pub const count_entries = "SELECT COUNT(*) FROM index_data WHERE index_id = ?";

    /// Clear all entries
    pub const clear_entries = "DELETE FROM index_data WHERE index_id = ?";
};

// ============================================================================
// Tests
// ============================================================================

test "IndexEntry - init and deinit" {
    const allocator = std.testing.allocator;

    const idx_key = IDBKey{ .string = "email@test.com" };
    const pk = IDBKey{ .number = 1 };

    var entry = try IndexEntry.init(allocator, idx_key, pk);
    defer entry.deinit();

    try std.testing.expect(entry.encoded_index_key.len > 0);
    try std.testing.expect(entry.encoded_primary_key.len > 0);
}

test "IndexPersistence - init and deinit" {
    const allocator = std.testing.allocator;

    var persistence = try IndexPersistence.init(
        allocator,
        1,
        1,
        "email_idx",
        "email",
        true,
        false,
    );
    defer persistence.deinit();

    try std.testing.expectEqualStrings("email_idx", persistence.name);
    try std.testing.expectEqualStrings("email", persistence.key_path);
    try std.testing.expect(persistence.is_unique);
    try std.testing.expect(!persistence.is_multi_entry);
}

test "IndexPersistence - generateEntries single" {
    const allocator = std.testing.allocator;

    var persistence = try IndexPersistence.init(
        allocator,
        1,
        1,
        "name_idx",
        "name",
        false,
        false,
    );
    defer persistence.deinit();

    const idx_key = IDBKey{ .string = "Alice" };
    const pk = IDBKey{ .number = 42 };

    const entries = try persistence.generateEntries(allocator, idx_key, pk);
    defer {
        for (entries) |*e| {
            var entry = e.*;
            entry.deinit();
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
}

test "IndexPersistence - generateEntries multi-entry" {
    const allocator = std.testing.allocator;

    var persistence = try IndexPersistence.init(
        allocator,
        1,
        1,
        "tags_idx",
        "tags",
        false,
        true, // multi-entry
    );
    defer persistence.deinit();

    // Array of tags
    var arr = [_]IDBKey{
        IDBKey{ .string = "red" },
        IDBKey{ .string = "blue" },
        IDBKey{ .string = "green" },
    };
    const idx_key = IDBKey{ .array = &arr };
    const pk = IDBKey{ .number = 1 };

    const entries = try persistence.generateEntries(allocator, idx_key, pk);
    defer {
        for (entries) |*e| {
            var entry = e.*;
            entry.deinit();
        }
        allocator.free(entries);
    }

    // Should have 3 entries (one per tag)
    try std.testing.expectEqual(@as(usize, 3), entries.len);
}

test "IndexManager - add and get" {
    const allocator = std.testing.allocator;

    var manager = IndexManager.init(allocator, 1);
    defer manager.deinit();

    const persistence = try allocator.create(IndexPersistence);
    persistence.* = try IndexPersistence.init(
        allocator,
        1,
        1,
        "test_idx",
        "field",
        false,
        false,
    );

    try manager.addIndex(persistence);

    try std.testing.expectEqual(@as(usize, 1), manager.count());

    const found = manager.getIndex("test_idx");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("test_idx", found.?.name);
}

test "IndexManager - remove" {
    const allocator = std.testing.allocator;

    var manager = IndexManager.init(allocator, 1);
    defer manager.deinit();

    const persistence = try allocator.create(IndexPersistence);
    persistence.* = try IndexPersistence.init(
        allocator,
        1,
        1,
        "to_remove",
        "field",
        false,
        false,
    );

    try manager.addIndex(persistence);
    try std.testing.expectEqual(@as(usize, 1), manager.count());

    manager.removeIndex("to_remove");
    try std.testing.expectEqual(@as(usize, 0), manager.count());
}
