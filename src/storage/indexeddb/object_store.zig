//! IndexedDB Object Store Implementation
//!
//! Implements IDBObjectStore per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbobjectstore
//!
//! ## Properties
//!
//! - `name` - Object store name
//! - `keyPath` - Key path
//! - `indexNames` - Index names
//! - `transaction` - Associated transaction
//! - `autoIncrement` - Whether auto-increment is enabled
//!
//! ## Methods
//!
//! - `put(value, key)` - Add or update a record
//! - `add(value, key)` - Add a new record
//! - `delete(query)` - Delete records
//! - `clear()` - Clear all records
//! - `get(query)` - Get a record
//! - `getKey(query)` - Get a key
//! - `getAll(query, count)` - Get all matching records
//! - `getAllKeys(query, count)` - Get all matching keys
//! - `count(query)` - Count records
//! - `openCursor(query, direction)` - Open a cursor
//! - `openKeyCursor(query, direction)` - Open a key cursor
//! - `index(name)` - Access an index
//! - `createIndex(name, keyPath, options)` - Create an index
//! - `deleteIndex(name)` - Delete an index
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#idbobjectstore

const std = @import("std");
const IDBTransaction = @import("transaction.zig").IDBTransaction;
const IDBRequest = @import("request.zig").IDBRequest;
const IDBIndex = @import("index.zig").IDBIndex;
const IDBCursor = @import("cursor.zig").IDBCursor;
const IDBCursorDirection = @import("cursor.zig").IDBCursorDirection;
const IDBKey = @import("key.zig").IDBKey;
const IDBKeyRange = @import("key_range.zig").IDBKeyRange;
const IDBError = @import("errors.zig").IDBError;

/// Options for createIndex
pub const IDBIndexParameters = struct {
    /// Whether the index has unique keys
    unique: bool = false,
    /// Whether the index supports multiple keys per record
    multi_entry: bool = false,
};

/// Record in object store
pub const Record = struct {
    key: IDBKey,
    value: []const u8, // Serialized value

    fn deinit(self: *Record, allocator: std.mem.Allocator) void {
        var key_mut = self.key;
        key_mut.deinit();
        allocator.free(self.value);
    }
};

/// IDBObjectStore interface
/// https://w3c.github.io/IndexedDB/#idbobjectstore
///
/// Represents a named key-value store.
pub const IDBObjectStore = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Object store name
    name: []const u8,

    /// Associated transaction
    transaction: *IDBTransaction,

    /// Key path (null for out-of-line keys)
    key_path: ?[]const u8,

    /// Whether auto-increment is enabled
    auto_increment: bool,

    /// Index handles
    indexes: std.StringHashMap(*IDBIndex),

    /// Records (simplified in-memory storage)
    records: std.ArrayListUnmanaged(Record),

    /// Current auto-increment key value
    key_generator: u64,

    /// Initialize a new object store handle
    pub fn init(allocator: std.mem.Allocator, name: []const u8, transaction: *IDBTransaction) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .transaction = transaction,
            .key_path = null,
            .auto_increment = false,
            .indexes = std.StringHashMap(*IDBIndex).init(allocator),
            .records = .{},
            .key_generator = 1,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        var it = self.indexes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.indexes.deinit();

        for (self.records.items) |*record| {
            record.deinit(self.allocator);
        }
        self.records.deinit(self.allocator);
    }

    /// Get index names
    pub fn indexNames(self: *Self) ![][]const u8 {
        const names = try self.allocator.alloc([]const u8, self.indexes.count());
        errdefer self.allocator.free(names);

        var idx: usize = 0;
        var it = self.indexes.iterator();
        while (it.next()) |entry| {
            names[idx] = entry.key_ptr.*;
            idx += 1;
        }

        return names;
    }

    /// Add or update a record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-put
    pub fn put(self: *Self, value: []const u8, key: ?IDBKey) IDBError!*IDBRequest {
        return self.storeRecord(value, key, false);
    }

    /// Add a new record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-add
    pub fn add(self: *Self, value: []const u8, key: ?IDBKey) IDBError!*IDBRequest {
        return self.storeRecord(value, key, true);
    }

    /// Internal: Store a record
    fn storeRecord(self: *Self, value: []const u8, key: ?IDBKey, no_overwrite: bool) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // Get or generate key
        var record_key: IDBKey = undefined;
        if (key) |k| {
            record_key = try k.clone(self.allocator);
        } else if (self.auto_increment) {
            // Generate key
            if (self.key_generator > 9007199254740992) { // 2^53
                return IDBError.ConstraintError;
            }
            record_key = IDBKey.number(@floatFromInt(self.key_generator));
            self.key_generator += 1;
        } else {
            return IDBError.DataError;
        }
        errdefer {
            var k = record_key;
            k.deinit();
        }

        // Check for existing record
        if (no_overwrite) {
            for (self.records.items) |*record| {
                if (@import("key.zig").compare(record.key, record_key) == 0) {
                    var k = record_key;
                    k.deinit();
                    return IDBError.ConstraintError;
                }
            }
        }

        // Store value
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        // Find and update or insert
        var found = false;
        for (self.records.items) |*record| {
            if (@import("key.zig").compare(record.key, record_key) == 0) {
                self.allocator.free(record.value);
                record.value = value_copy;
                found = true;
                break;
            }
        }

        if (!found) {
            try self.records.append(self.allocator, Record{
                .key = record_key,
                .value = value_copy,
            });
        } else {
            var k = record_key;
            k.deinit();
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .key = record_key });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Delete records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-delete
    pub fn delete(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // Remove matching records
        var i: usize = 0;
        while (i < self.records.items.len) {
            const record = &self.records.items[i];
            if (query.includes(record.key)) {
                var removed = self.records.orderedRemove(i);
                removed.deinit(self.allocator);
            } else {
                i += 1;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .undefined = {} });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Clear all records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-clear
    pub fn clear(self: *Self) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // Remove all records
        for (self.records.items) |*record| {
            record.deinit(self.allocator);
        }
        self.records.clearRetainingCapacity();

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .undefined = {} });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Get a record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-get
    pub fn get(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find first matching record
        var found_value: ?[]const u8 = null;
        for (self.records.items) |*record| {
            if (query.includes(record.key)) {
                found_value = record.value;
                break;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;

        if (found_value) |v| {
            request.setResult(.{ .value = v });
        } else {
            request.setResult(.{ .undefined = {} });
        }

        try self.transaction.addRequest(request);

        return request;
    }

    /// Get a key
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-getkey
    pub fn getKey(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find first matching record
        var found_key: ?IDBKey = null;
        for (self.records.items) |*record| {
            if (query.includes(record.key)) {
                found_key = record.key;
                break;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;

        if (found_key) |k| {
            request.setResult(.{ .key = k });
        } else {
            request.setResult(.{ .undefined = {} });
        }

        try self.transaction.addRequest(request);

        return request;
    }

    /// Count records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-count
    pub fn count(self: *Self, query: ?IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Count matching records
        var cnt: u64 = 0;
        for (self.records.items) |*record| {
            if (query) |q| {
                if (q.includes(record.key)) {
                    cnt += 1;
                }
            } else {
                cnt += 1;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .count = cnt });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Open a cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-opencursor
    pub fn openCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor
        const cursor = try self.allocator.create(IDBCursor);
        cursor.* = IDBCursor.init(self.allocator, self, query, direction);

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .cursor = cursor });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Access an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-index
    pub fn index(self: *Self, name: []const u8) IDBError!*IDBIndex {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Check if we have a handle
        if (self.indexes.get(name)) |idx| {
            return idx;
        }

        // Index doesn't exist
        return IDBError.NotFoundError;
    }

    /// Create an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-createindex
    pub fn createIndex(
        self: *Self,
        name: []const u8,
        key_path: []const u8,
        options: IDBIndexParameters,
    ) IDBError!*IDBIndex {
        // Check for versionchange transaction
        if (self.transaction.mode != .versionchange) {
            return IDBError.InvalidStateError;
        }

        // Check transaction is active
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check name doesn't exist
        if (self.indexes.contains(name)) {
            return IDBError.ConstraintError;
        }

        // Create index
        const idx = try self.allocator.create(IDBIndex);
        errdefer self.allocator.destroy(idx);

        idx.* = IDBIndex.init(self.allocator, name, self);
        idx.key_path = key_path;
        idx.unique = options.unique;
        idx.multi_entry = options.multi_entry;

        try self.indexes.put(name, idx);

        return idx;
    }

    /// Delete an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-deleteindex
    pub fn deleteIndex(self: *Self, name: []const u8) IDBError!void {
        // Check for versionchange transaction
        if (self.transaction.mode != .versionchange) {
            return IDBError.InvalidStateError;
        }

        // Check transaction is active
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Remove index
        if (self.indexes.fetchRemove(name)) |kv| {
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        } else {
            return IDBError.NotFoundError;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBObjectStore - init" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    try std.testing.expectEqualStrings("store1", store.name);
}

test "IDBObjectStore - count empty" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    const request = try store.count(null);
    defer allocator.destroy(request);

    try std.testing.expect(request.done_flag);
    try std.testing.expectEqual(@as(u64, 0), request.result.?.count);
}
