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

/// Persistent index definition and records, shared by transaction handles.
pub const IndexData = struct {
    allocator: std.mem.Allocator,
    references: usize = 1,
    name: []u8,
    key_path: []u8,
    unique: bool,
    multi_entry: bool,
    entries: std.ArrayListUnmanaged(IndexEntry) = .empty,

    pub fn create(allocator: std.mem.Allocator, name: []const u8, path: []const u8, unique: bool, multi_entry: bool) std.mem.Allocator.Error!*IndexData {
        const data = try allocator.create(IndexData);
        errdefer allocator.destroy(data);
        const copied_name = try allocator.dupe(u8, name);
        errdefer allocator.free(copied_name);
        const copied_path = try allocator.dupe(u8, path);
        data.* = .{ .allocator = allocator, .name = copied_name, .key_path = copied_path, .unique = unique, .multi_entry = multi_entry };
        return data;
    }
    pub fn clone(self: *const IndexData) std.mem.Allocator.Error!*IndexData {
        const copy = try create(self.allocator, self.name, self.key_path, self.unique, self.multi_entry);
        errdefer copy.release();
        try copy.entries.ensureTotalCapacity(self.allocator, self.entries.items.len);
        for (self.entries.items) |entry| {
            var key = try entry.index_key.clone(self.allocator);
            errdefer key.deinit();
            const primary = try entry.primary_key.clone(self.allocator);
            copy.entries.appendAssumeCapacity(.{ .index_key = key, .primary_key = primary });
        }
        return copy;
    }
    pub fn retain(self: *IndexData) void {
        self.references += 1;
    }
    pub fn release(self: *IndexData) void {
        std.debug.assert(self.references > 0);
        self.references -= 1;
        if (self.references != 0) return;
        for (self.entries.items) |*entry| entry.deinit(self.allocator);
        self.entries.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.free(self.key_path);
        self.allocator.destroy(self);
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
    data: ?*IndexData = null,
    deleted: bool = false,

    /// Initialize a new index handle
    pub fn init(allocator: std.mem.Allocator, name: []const u8, object_store: *IDBObjectStore) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .object_store = object_store,
            .key_path = null,
            .unique = false,
            .multi_entry = false,
            .entries = .empty,
        };
    }

    pub fn attachData(self: *Self, data: *IndexData) void {
        std.debug.assert(self.data == null);
        data.retain();
        self.data = data;
        self.name = data.name;
        self.key_path = data.key_path;
        self.unique = data.unique;
        self.multi_entry = data.multi_entry;
    }
    pub fn entriesList(self: *const Self) *std.ArrayListUnmanaged(IndexEntry) {
        return if (self.data) |data| &data.entries else @constCast(&self.entries);
    }
    /// Clean up resources; the database retains the persistent definition.
    pub fn deinit(self: *Self) void {
        if (self.data) |data| data.release() else {
            for (self.entries.items) |*entry| entry.deinit(self.allocator);
            self.entries.deinit(self.allocator);
        }
    }

    /// Get a record by index key
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-get
    pub fn get(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find matching entry
        var found_primary_key: ?IDBKey = null;
        for (self.entriesList().items) |*entry| {
            if (query.includes(entry.index_key)) {
                found_primary_key = entry.primary_key;
                break;
            }
        }

        // If found, get the record from object store
        var found_value: ?[]const u8 = null;
        if (found_primary_key) |pk| {
            for (self.object_store.recordsList().items) |*record| {
                if (@import("key.zig").compare(record.key, pk) == 0) {
                    found_value = record.value;
                    break;
                }
            }
        }

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);

        if (found_value) |v| {
            request.completePrepared(.{ .value = v });
        } else {
            request.completePrepared(.{ .undefined = {} });
        }

        return request;
    }

    /// Get a primary key by index key
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-getkey
    pub fn getKey(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find matching entry
        var found_primary_key: ?IDBKey = null;
        for (self.entriesList().items) |*entry| {
            if (query.includes(entry.index_key)) {
                found_primary_key = entry.primary_key;
                break;
            }
        }

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);

        if (found_primary_key) |k| {
            request.completePrepared(.{ .key = k });
        } else {
            request.completePrepared(.{ .undefined = {} });
        }

        return request;
    }

    /// Count matching entries
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-count
    pub fn count(self: *Self, query: ?IDBKeyRange) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Count matching entries
        var cnt: u64 = 0;
        for (self.entriesList().items) |*entry| {
            if (query) |q| {
                if (q.includes(entry.index_key)) {
                    cnt += 1;
                }
            } else {
                cnt += 1;
            }
        }

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);
        request.completePrepared(.{ .count = cnt });

        return request;
    }

    /// Open a cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-opencursor
    pub fn openCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor
        const cursor = try self.allocator.create(IDBCursor);
        errdefer self.allocator.destroy(cursor);
        cursor.* = try IDBCursor.initForIndex(self.allocator, self, query, direction);
        errdefer cursor.deinit();

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);
        request.completePrepared(.{ .cursor = cursor });

        return request;
    }

    /// Open a key cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-openkeycursor
    pub fn openKeyCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor (key-only mode)
        const cursor = try self.allocator.create(IDBCursor);
        errdefer self.allocator.destroy(cursor);
        cursor.* = try IDBCursor.initForIndex(self.allocator, self, query, direction);
        errdefer cursor.deinit();
        cursor.key_only = true;

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);
        request.completePrepared(.{ .cursor = cursor });

        return request;
    }

    /// Native operation staging: no records are published before every
    /// constraint and allocation succeeds (IDB 2.7 request atomicity).
    pub const PreparedEntries = struct {
        allocator: std.mem.Allocator,
        entries: std.ArrayListUnmanaged(IndexEntry) = .empty,
        pub fn deinit(self: *PreparedEntries) void {
            for (self.entries.items) |*entry| entry.deinit(self.allocator);
            self.entries.deinit(self.allocator);
        }
        pub fn commit(self: *PreparedEntries, index: *Self) void {
            // IDB 6.1 steps 5.5-5.6: index key, then primary key, ascending.
            for (self.entries.items) |entry| {
                var insertion = index.entriesList().items.len;
                for (index.entriesList().items, 0..) |existing, i| {
                    const key_order = @import("key.zig").compare(entry.index_key, existing.index_key);
                    if (key_order < 0 or (key_order == 0 and @import("key.zig").compare(entry.primary_key, existing.primary_key) < 0)) {
                        insertion = i;
                        break;
                    }
                }
                index.entriesList().insertAssumeCapacity(insertion, entry);
            }
            self.entries.clearRetainingCapacity();
        }
    };
    pub fn prepareEntries(self: *Self, keys: []const IDBKey, primary_key: IDBKey) IDBError!PreparedEntries {
        // IDB 6.1 steps 5.3-5.4: validate ALL subkeys before inserting any.
        if (self.unique) for (keys, 0..) |key, i| {
            for (self.entriesList().items) |entry| {
                if (@import("key.zig").compare(entry.index_key, key) == 0) return IDBError.ConstraintError;
            }
            for (keys[0..i]) |previous| {
                if (@import("key.zig").compare(previous, key) == 0) return IDBError.ConstraintError;
            }
        };
        var prepared = PreparedEntries{ .allocator = self.allocator };
        errdefer prepared.deinit();
        try prepared.entries.ensureTotalCapacity(self.allocator, keys.len);
        for (keys) |key| {
            var copied_key = try key.clone(self.allocator);
            errdefer copied_key.deinit();
            const copied_primary = try primary_key.clone(self.allocator);
            prepared.entries.appendAssumeCapacity(.{ .index_key = copied_key, .primary_key = copied_primary });
        }
        try self.entriesList().ensureUnusedCapacity(self.allocator, keys.len);
        return prepared;
    }
    /// Add a single entry, retaining neither borrowed input key.
    pub fn addEntry(self: *Self, index_key: IDBKey, primary_key: IDBKey) IDBError!void {
        var prepared = try self.prepareEntries(&.{index_key}, primary_key);
        defer prepared.deinit();
        prepared.commit(self);
    }

    /// Add entries for a value, handling multiEntry indexes
    /// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
    ///
    /// For multiEntry indexes:
    /// - If the extracted value is an array, creates an index entry for each element
    /// - Duplicate keys within the array are skipped
    /// - Nested array subkeys remain keys; only the outer array is unpacked
    ///
    /// For regular indexes:
    /// - Creates a single index entry for the extracted key
    pub fn addEntriesForValue(
        self: *Self,
        allocator: std.mem.Allocator,
        value: @import("key_path.zig").ExtractedValue,
        primary_key: IDBKey,
    ) IDBError!void {
        const key_path_mod = @import("key_path.zig");

        // Get the key path
        const kp = self.key_path orelse return;

        // Extract key using the key path
        const result = try key_path_mod.extractKeyOwned(
            allocator,
            value,
            .{ .single = kp },
            self.multi_entry,
        );

        switch (result) {
            .failure, .invalid => {
                // Per spec step 5.2: If extraction fails or is invalid, skip this index
                return;
            },
            .key => |extracted_key| {
                defer {
                    var k = extracted_key;
                    k.deinit();
                }

                const keys: []const IDBKey = if (self.multi_entry and extracted_key.key_type == .array)
                    extracted_key.value.array
                else
                    &.{extracted_key};
                var prepared = try self.prepareEntries(keys, primary_key);
                defer prepared.deinit();
                prepared.commit(self);
            },
        }
    }

    /// Remove entries for a primary key (internal use)
    pub fn removeEntriesForPrimaryKey(self: *Self, primary_key: IDBKey) void {
        var i: usize = 0;
        while (i < self.entriesList().items.len) {
            const entry = &self.entriesList().items[i];
            if (@import("key.zig").compare(entry.primary_key, primary_key) == 0) {
                var removed = self.entriesList().orderedRemove(i);
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

test "IDBIndex - multiEntry creates multiple entries" {
    const allocator = std.testing.allocator;
    const key_path_mod = @import("key_path.zig");

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "tags_idx", &store);
    defer idx.deinit();
    idx.key_path = "tags";
    idx.multi_entry = true;

    // Create value with tags array
    const tags = [_]key_path_mod.ExtractedValue{
        .{ .string = "red" },
        .{ .string = "blue" },
        .{ .string = "green" },
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "id", .value = .{ .number = 1 } },
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    // Add entries for the value
    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // Should have 3 entries (one per tag)
    try std.testing.expectEqual(@as(usize, 3), idx.entries.items.len);

    // Verify index keys
    try std.testing.expectEqualStrings("blue", idx.entries.items[0].index_key.value.string);
    try std.testing.expectEqualStrings("green", idx.entries.items[1].index_key.value.string);
    try std.testing.expectEqualStrings("red", idx.entries.items[2].index_key.value.string);

    // All should point to same primary key
    try std.testing.expectEqual(@as(f64, 1), idx.entries.items[0].primary_key.value.number);
    try std.testing.expectEqual(@as(f64, 1), idx.entries.items[1].primary_key.value.number);
    try std.testing.expectEqual(@as(f64, 1), idx.entries.items[2].primary_key.value.number);
}

test "IDBIndex - multiEntry deduplicates array elements" {
    const allocator = std.testing.allocator;
    const key_path_mod = @import("key_path.zig");

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "tags_idx", &store);
    defer idx.deinit();
    idx.key_path = "tags";
    idx.multi_entry = true;

    // Create value with duplicate tags
    const tags = [_]key_path_mod.ExtractedValue{
        .{ .string = "red" },
        .{ .string = "blue" },
        .{ .string = "red" }, // duplicate
        .{ .string = "green" },
        .{ .string = "blue" }, // duplicate
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // Should have 3 entries (duplicates skipped)
    try std.testing.expectEqual(@as(usize, 3), idx.entries.items.len);
}

test "IDBIndex - multiEntry retains nested arrays" {
    const allocator = std.testing.allocator;
    const key_path_mod = @import("key_path.zig");

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "data_idx", &store);
    defer idx.deinit();
    idx.key_path = "data";
    idx.multi_entry = true;

    // Create value with mixed array (includes a valid nested array)
    const nested = [_]key_path_mod.ExtractedValue{
        .{ .number = 99 },
    };
    const data = [_]key_path_mod.ExtractedValue{
        .{ .string = "valid" },
        .{ .array = &nested }, // nested array - one valid array subkey
        .{ .number = 42 },
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "data", .value = .{ .array = &data } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // All three valid subkeys are included.
    try std.testing.expectEqual(@as(usize, 3), idx.entries.items.len);
}

test "IDBIndex - non-multiEntry with array creates single entry" {
    const allocator = std.testing.allocator;
    const key_path_mod = @import("key_path.zig");

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "tags_idx", &store);
    defer idx.deinit();
    idx.key_path = "tags";
    idx.multi_entry = false; // NOT multiEntry

    // Create value with tags array
    const tags = [_]key_path_mod.ExtractedValue{
        .{ .string = "red" },
        .{ .string = "blue" },
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // Should have 1 entry (the whole array as key)
    try std.testing.expectEqual(@as(usize, 1), idx.entries.items.len);
    try std.testing.expectEqual(@import("key.zig").IDBKeyType.array, idx.entries.items[0].index_key.key_type);
}
