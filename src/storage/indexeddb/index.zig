//! IndexedDB Index Implementation
//!
//! Implements IDBIndex per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbindex
//!
//! ## Properties
//!
//! - `name` - Index name
//! - `objectStore` - Associated object store
//! - `keyPath` - Key path for index keys
//! - `multiEntry` - Whether multi-entry is enabled
//! - `unique` - Whether keys must be unique
//!
//! ## Methods
//!
//! - `get(query)` - Get a record by index key
//! - `getKey(query)` - Get a primary key by index key
//! - `getAll(query, count)` - Get all matching records
//! - `getAllKeys(query, count)` - Get all matching primary keys
//! - `count(query)` - Count records
//! - `openCursor(query, direction)` - Open a cursor
//! - `openKeyCursor(query, direction)` - Open a key cursor
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#idbindex

const std = @import("std");
const IDBObjectStore = @import("object_store.zig").IDBObjectStore;
const IDBRequest = @import("request.zig").IDBRequest;
const IDBCursor = @import("cursor.zig").IDBCursor;
const IDBCursorDirection = @import("cursor.zig").IDBCursorDirection;
const IDBKey = @import("key.zig").IDBKey;
const IDBKeyRange = @import("key_range.zig").IDBKeyRange;
const IDBError = @import("errors.zig").IDBError;

/// Index entry mapping index key to primary key
const IndexEntry = struct {
    index_key: IDBKey,
    primary_key: IDBKey,

    fn deinit(self: *IndexEntry, allocator: std.mem.Allocator) void {
        var ik = self.index_key;
        ik.deinit();
        var pk = self.primary_key;
        pk.deinit();
        _ = allocator;
    }
};

/// IDBIndex interface
/// https://w3c.github.io/IndexedDB/#idbindex
///
/// Represents a secondary index on an object store.
pub const IDBIndex = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Index name
    name: []const u8,

    /// Associated object store
    object_store: *IDBObjectStore,

    /// Key path for extracting index keys
    key_path: ?[]const u8,

    /// Whether keys must be unique
    unique: bool,

    /// Whether multi-entry is enabled
    /// (array values create multiple index entries)
    multi_entry: bool,

    /// Index entries (simplified in-memory storage)
    entries: std.ArrayListUnmanaged(IndexEntry),

    /// Initialize a new index handle
    pub fn init(allocator: std.mem.Allocator, name: []const u8, object_store: *IDBObjectStore) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .object_store = object_store,
            .key_path = null,
            .unique = false,
            .multi_entry = false,
            .entries = .{},
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        for (self.entries.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.entries.deinit(self.allocator);
    }

    /// Get a record by index key
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-get
    pub fn get(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find matching entry
        var found_primary_key: ?IDBKey = null;
        for (self.entries.items) |*entry| {
            if (query.includes(entry.index_key)) {
                found_primary_key = entry.primary_key;
                break;
            }
        }

        // If found, get the record from object store
        var found_value: ?[]const u8 = null;
        if (found_primary_key) |pk| {
            for (self.object_store.records.items) |*record| {
                if (@import("key.zig").compare(record.key, pk) == 0) {
                    found_value = record.value;
                    break;
                }
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .index;

        if (found_value) |v| {
            request.setResult(.{ .value = v });
        } else {
            request.setResult(.{ .undefined = {} });
        }

        try txn.addRequest(request);

        return request;
    }

    /// Get a primary key by index key
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-getkey
    pub fn getKey(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find matching entry
        var found_primary_key: ?IDBKey = null;
        for (self.entries.items) |*entry| {
            if (query.includes(entry.index_key)) {
                found_primary_key = entry.primary_key;
                break;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .index;

        if (found_primary_key) |k| {
            request.setResult(.{ .key = k });
        } else {
            request.setResult(.{ .undefined = {} });
        }

        try txn.addRequest(request);

        return request;
    }

    /// Count matching entries
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-count
    pub fn count(self: *Self, query: ?IDBKeyRange) IDBError!*IDBRequest {
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Count matching entries
        var cnt: u64 = 0;
        for (self.entries.items) |*entry| {
            if (query) |q| {
                if (q.includes(entry.index_key)) {
                    cnt += 1;
                }
            } else {
                cnt += 1;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .index;
        request.setResult(.{ .count = cnt });

        try txn.addRequest(request);

        return request;
    }

    /// Open a cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-opencursor
    pub fn openCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor
        const cursor = try self.allocator.create(IDBCursor);
        cursor.* = IDBCursor.initForIndex(self.allocator, self, query, direction);

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .index;
        request.setResult(.{ .cursor = cursor });

        try txn.addRequest(request);

        return request;
    }

    /// Open a key cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-openkeycursor
    pub fn openKeyCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor (key-only mode)
        const cursor = try self.allocator.create(IDBCursor);
        cursor.* = IDBCursor.initForIndex(self.allocator, self, query, direction);
        cursor.key_only = true;

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .index;
        request.setResult(.{ .cursor = cursor });

        try txn.addRequest(request);

        return request;
    }

    /// Add an entry to the index (internal use)
    pub fn addEntry(self: *Self, index_key: IDBKey, primary_key: IDBKey) IDBError!void {
        // Check uniqueness constraint
        if (self.unique) {
            for (self.entries.items) |*entry| {
                if (@import("key.zig").compare(entry.index_key, index_key) == 0) {
                    return IDBError.ConstraintError;
                }
            }
        }

        // Clone keys and add entry
        const ik = try index_key.clone(self.allocator);
        errdefer {
            var k = ik;
            k.deinit();
        }
        const pk = try primary_key.clone(self.allocator);
        errdefer {
            var k = pk;
            k.deinit();
        }

        try self.entries.append(self.allocator, IndexEntry{
            .index_key = ik,
            .primary_key = pk,
        });
    }

    /// Remove entries for a primary key (internal use)
    pub fn removeEntriesForPrimaryKey(self: *Self, primary_key: IDBKey) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const entry = &self.entries.items[i];
            if (@import("key.zig").compare(entry.primary_key, primary_key) == 0) {
                var removed = self.entries.orderedRemove(i);
                removed.deinit(self.allocator);
            } else {
                i += 1;
            }
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBIndex - init" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "idx1", &store);
    defer idx.deinit();

    try std.testing.expectEqualStrings("idx1", idx.name);
    try std.testing.expect(!idx.unique);
    try std.testing.expect(!idx.multi_entry);
}

test "IDBIndex - count empty" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "idx1", &store);
    defer idx.deinit();

    const request = try idx.count(null);
    defer allocator.destroy(request);

    try std.testing.expect(request.done_flag);
    try std.testing.expectEqual(@as(u64, 0), request.result.?.count);
}
